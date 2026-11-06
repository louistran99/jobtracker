import Foundation

/// Turns the text in the link field into a URL to fetch, and a URL into the key that identifies its posting.
public enum PostingLink {
    /// The URL to fetch for `text`, or `nil` when the text is not a web address.
    ///
    /// Surrounding whitespace is ignored. A missing scheme becomes `https`, and `http` is upgraded to `https` because
    /// App Transport Security blocks plain HTTP. The host must contain a dot, so partial input such as "https://str"
    /// is not fetched. The query is kept, since some sites need it to find the posting.
    public static func url(from text: String) -> URL? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let withScheme = text.contains("://") ? text : "https://\(text)"
        guard var components = URLComponents(string: withScheme) else { return nil }
        switch components.scheme?.lowercased() {
        case "https", "http": components.scheme = "https"
        default: return nil
        }
        guard components.user == nil, components.password == nil,
            let host = components.host, host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".")
        else { return nil }
        return components.url
    }

    /// The key that identifies the posting at `url`. Two links to the same posting get the same key.
    ///
    /// The key uses `https`, a lowercase host without `www.`, no fragment, no trailing slash, and no default port.
    /// Tracking parameters are removed and the remaining query items are sorted, so links shared from different
    /// places still match. Paths and the values of other query items keep their case, because sites may treat them
    /// as case-sensitive.
    public static func normalized(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.scheme = "https"
        if let host = components.host?.lowercased() {
            components.host = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
        if components.port == 443 {
            components.port = nil
        }
        components.fragment = nil
        while components.percentEncodedPath.hasSuffix("/") {
            components.percentEncodedPath.removeLast()
        }
        let items = (components.percentEncodedQueryItems ?? [])
            .filter { !isTracking($0.name) }
            .sorted { ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "") }
        components.percentEncodedQueryItems = items.isEmpty ? nil : items
        return components.string ?? url.absoluteString
    }

    /// Query parameters that record where a link was shared from, not which posting it is. Compared in lowercase.
    ///
    /// `departmentId` is Ashby's filter for the job board page the posting was opened from.
    private static let trackingParameters: Set<String> = [
        "_hsenc", "_hsmi", "departmentid", "fbclid", "gbraid", "gclid", "gh_src", "lever-origin", "lever-source",
        "mc_cid", "mc_eid", "msclkid", "ref", "refid", "source", "src", "trackingid", "trk", "wbraid",
    ]

    private static func isTracking(_ name: String) -> Bool {
        let name = name.lowercased()
        return name.hasPrefix("utm_") || trackingParameters.contains(name)
    }
}
