import Foundation

/// What the app could read from a job posting.
///
/// Every field is optional because postings differ in what they publish. A posting that yields neither a role nor a
/// company is reported as unreadable instead of producing an empty value.
public struct PostingMetadata: Equatable, Sendable {
    public var role: String?
    public var company: String?
    /// Display names of the places the job is based, in the order the posting lists them.
    public var locations: [String]
    public var isRemote: Bool
    public var datePosted: Date?

    public init(
        role: String? = nil,
        company: String? = nil,
        locations: [String] = [],
        isRemote: Bool = false,
        datePosted: Date? = nil
    ) {
        self.role = role
        self.company = company
        self.locations = locations
        self.isRemote = isRemote
        self.datePosted = datePosted
    }

    /// One line describing where and when, such as "New York · Remote · Posted Jul 2".
    ///
    /// Missing parts are left out. Returns `nil` when the posting has none of them.
    public func summary(locale: Locale = .current, timeZone: TimeZone = .current) -> String? {
        var parts: [String] = []
        if let first = locations.first {
            parts.append(locations.count > 1 ? "\(first) +\(locations.count - 1)" : first)
        }
        if isRemote {
            parts.append("Remote")
        }
        if let datePosted {
            var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
            style.locale = locale
            style.timeZone = timeZone
            parts.append("Posted \(datePosted.formatted(style))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
