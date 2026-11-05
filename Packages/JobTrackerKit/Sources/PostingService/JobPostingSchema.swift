import Domain
import Foundation

/// A JSON-LD value that may be a single `Element` or an array of them.
///
/// Array elements that fail to decode are skipped, so one malformed entry does not hide the rest.
struct OneOrMany<Element: Decodable>: Decodable {
    let values: [Element]

    init(from decoder: any Decoder) throws {
        guard var array = try? decoder.unkeyedContainer() else {
            values = [try decoder.singleValueContainer().decode(Element.self)]
            return
        }
        var values: [Element] = []
        while !array.isAtEnd {
            if let value = try? array.decode(Element.self) {
                values.append(value)
            } else if (try? array.decode(Skipped.self)) == nil {
                break
            }
        }
        self.values = values
    }

    /// Consumes one array element without reading it.
    private struct Skipped: Decodable {
        init(from decoder: any Decoder) throws {}
    }
}

/// A schema.org thing written either as plain text or as an object with a `name`, such as `hiringOrganization` or
/// `addressCountry`.
struct NamedThing: Decodable {
    let name: String?

    private enum CodingKeys: String, CodingKey {
        case name
    }

    init(from decoder: any Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            name = text
        } else {
            name = try? decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(String.self, forKey: .name)
        }
    }
}

/// A schema.org `PostalAddress`, or an address written as plain text.
struct PostalAddress: Decodable {
    let locality: String?
    let region: String?
    let country: String?

    private enum CodingKeys: String, CodingKey {
        case locality = "addressLocality"
        case region = "addressRegion"
        case country = "addressCountry"
    }

    init(from decoder: any Decoder) throws {
        if let text = try? decoder.singleValueContainer().decode(String.self) {
            locality = text
            region = nil
            country = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        locality = try? container.decodeIfPresent(String.self, forKey: .locality)
        region = try? container.decodeIfPresent(String.self, forKey: .region)
        country = (try? container.decodeIfPresent(NamedThing.self, forKey: .country))?.name
    }
}

/// A schema.org `Place`, as used by `JobPosting.jobLocation`.
struct Place: Decodable {
    let name: String?
    let address: PostalAddress?

    private enum CodingKeys: String, CodingKey {
        case name
        case address
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        address = try? container.decodeIfPresent(PostalAddress.self, forKey: .address)
    }

    /// The most specific name for the place: the city, else the region, country, or place name.
    var displayName: String? {
        [address?.locality, address?.region, address?.country, name]
            .lazy
            .compactMap { $0.flatMap(HTMLText.clean) }
            .first
    }
}

/// One node of a JSON-LD document, with the `JobPosting` properties the app reads.
///
/// Every property decodes leniently, so a node with one malformed property still yields the others.
struct JSONLDNode: Decodable {
    let types: [String]
    let graph: [JSONLDNode]
    let title: String?
    let hiringOrganization: [NamedThing]
    let jobLocation: [Place]
    let jobLocationType: [String]
    let datePosted: String?

    private enum CodingKeys: String, CodingKey {
        case types = "@type"
        case graph = "@graph"
        case title
        case hiringOrganization
        case jobLocation
        case jobLocationType
        case datePosted
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func many<T: Decodable>(_ key: CodingKeys, as type: T.Type) -> [T] {
            (try? container.decodeIfPresent(OneOrMany<T>.self, forKey: key))?.values ?? []
        }
        types = many(.types, as: String.self)
        graph = many(.graph, as: JSONLDNode.self)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        hiringOrganization = many(.hiringOrganization, as: NamedThing.self)
        jobLocation = many(.jobLocation, as: Place.self)
        jobLocationType = many(.jobLocationType, as: String.self)
        datePosted = try? container.decodeIfPresent(String.self, forKey: .datePosted)
    }

    var isJobPosting: Bool {
        types.contains { type in
            type == "JobPosting" || type.hasSuffix("/JobPosting") || type.hasSuffix(":JobPosting")
        }
    }

    /// The first `JobPosting` among `nodes`, searching each node's `@graph` too.
    static func firstJobPosting(in nodes: [JSONLDNode]) -> JSONLDNode? {
        for node in nodes {
            if node.isJobPosting { return node }
            if let posting = firstJobPosting(in: node.graph) { return posting }
        }
        return nil
    }

    func metadata(timeZone: TimeZone) -> PostingMetadata {
        var locations: [String] = []
        for name in jobLocation.compactMap(\.displayName) where !locations.contains(name) {
            locations.append(name)
        }
        return PostingMetadata(
            role: title.flatMap(HTMLText.clean),
            company: hiringOrganization.lazy.compactMap { $0.name.flatMap(HTMLText.clean) }.first,
            locations: locations,
            isRemote: jobLocationType.contains { $0.caseInsensitiveCompare("TELECOMMUTE") == .orderedSame },
            datePosted: datePosted.flatMap { PostingDate.parse($0, timeZone: timeZone) }
        )
    }
}

/// Parses schema.org dates.
enum PostingDate {
    /// Parses an ISO 8601 date or date-time.
    ///
    /// A date without a time, such as "2026-07-02", is that calendar day in `timeZone`. Reading it as midnight UTC
    /// would show the previous day west of Greenwich.
    static func parse(_ text: String, timeZone: TimeZone) -> Date? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > 10 {
            if let date = try? Date(text, strategy: .iso8601) { return date }
            let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            if let date = try? Date(text, strategy: fractional) { return date }
        }
        guard let match = text.prefixMatch(of: /(\d{4})-(\d{2})-(\d{2})/),
            let year = Int(match.1), let month = Int(match.2), let day = Int(match.3)
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar) else { return nil }
        return calendar.date(from: components)
    }
}
