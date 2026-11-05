import Foundation

/// The parts of an HTML page that describe it: JSON-LD blocks, `<meta>` tags, and the title.
///
/// Extraction is pattern-based rather than a full HTML parse. Pages only need to be read, never rendered, and the
/// patterns tolerate attribute order, either quote style, and letter case.
struct HTMLDocument {
    let html: String

    /// The bodies of every `<script type="application/ld+json">` block, in document order.
    var jsonLDBlocks: [String] {
        let scripts = /<script\b([^>]*)>(.*?)<\/script\s*>/.ignoresCase().dotMatchesNewlines()
        return html.matches(of: scripts).compactMap { match in
            guard match.1.localizedCaseInsensitiveContains("application/ld+json") else { return nil }
            let body = match.2
                .replacing("<!--", with: "")
                .replacing("-->", with: "")
                .replacing("<![CDATA[", with: "")
                .replacing("]]>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return body.isEmpty ? nil : body
        }
    }

    /// The `content` of each `<meta>` tag, keyed by its lowercased `property` or `name`. The first tag wins.
    var metaContent: [String: String] {
        var content: [String: String] = [:]
        for tag in html.matches(of: /<meta\b[^>]*>/.ignoresCase()) {
            let attributes = Self.attributes(of: String(tag.output))
            guard let key = (attributes["property"] ?? attributes["name"])?.lowercased(),
                let value = attributes["content"].flatMap(HTMLText.clean),
                content[key] == nil
            else { continue }
            content[key] = value
        }
        return content
    }

    /// The text of the first `<title>` element.
    var title: String? {
        let title = /<title\b[^>]*>(.*?)<\/title\s*>/.ignoresCase().dotMatchesNewlines()
        return html.firstMatch(of: title).flatMap { HTMLText.clean(String($0.1)) }
    }

    var hasPasswordField: Bool {
        html.contains(/<input\b[^>]*\btype\s*=\s*["']?password\b/.ignoresCase())
    }

    /// The attributes of one tag, keyed by lowercased name, with values unquoted but not entity-decoded.
    private static func attributes(of tag: String) -> [String: String] {
        let attribute = /([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+))/
        var attributes: [String: String] = [:]
        for match in tag.matches(of: attribute) {
            let value = match.2 ?? match.3 ?? match.4 ?? ""
            attributes[match.1.lowercased()] = String(value)
        }
        return attributes
    }
}

/// Cleans text taken from HTML or JSON-LD for display.
enum HTMLText {
    /// Decodes entities, collapses runs of whitespace, and trims. Returns `nil` when nothing is left.
    static func clean(_ text: String) -> String? {
        let cleaned = decodeEntities(text)
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Decodes numeric character references and the named entities that appear in page titles.
    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        return text.replacing(/&(#[0-9]{1,7}|#[xX][0-9A-Fa-f]{1,6}|[A-Za-z]{2,8});/) { match in
            decode(entity: match.1) ?? String(match.0)
        }
    }

    private static let namedEntities: [Substring: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "ndash": "–", "mdash": "—", "hellip": "…", "middot": "·", "bull": "•",
        "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
        "copy": "©", "reg": "®", "trade": "™",
    ]

    private static func decode(entity: Substring) -> String? {
        guard entity.hasPrefix("#") else { return namedEntities[entity] }
        let digits = entity.dropFirst()
        let codePoint =
            digits.first == "x" || digits.first == "X"
            ? UInt32(digits.dropFirst(), radix: 16)
            : UInt32(digits, radix: 10)
        return codePoint.flatMap { Unicode.Scalar($0) }.map { String(Character($0)) }
    }
}
