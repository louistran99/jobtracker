import Domain
import Foundation

/// Why a posting could not be read.
public enum PostingFetchError: Error, Equatable, Sendable {
    /// The server answered with a status other than 2xx, such as 403 or LinkedIn's 999.
    case httpStatus(Int)
    /// The response is not HTML or JSON, such as a PDF or an image.
    case unsupportedContentType(String)
    /// The response is larger than the service reads.
    case tooLarge
    /// The page asks the person to sign in instead of showing the posting.
    case loginWall
    /// The page has no role or company to read.
    case nothingUsable
}

/// Reads a role and company from a fetched posting.
///
/// The sources are tried in order:
/// 1. A JSON body, decoded as a schema.org `JobPosting`.
/// 2. The HTML page's JSON-LD `JobPosting` block.
/// 3. The Open Graph tags, then the page title. A sign-in page is rejected before this step.
enum PostingParser {
    static func parse(
        body: Data,
        contentType: String?,
        textEncodingName: String?,
        finalURL: URL?,
        timeZone: TimeZone
    ) throws(PostingFetchError) -> PostingMetadata {
        let text = decodeText(body, textEncodingName: textEncodingName)
        if isJSON(text, contentType: contentType) {
            return try parseJSON(text, timeZone: timeZone)
        }
        return try parseHTML(HTMLDocument(html: text), finalURL: finalURL, timeZone: timeZone)
    }

    private static func parseJSON(_ text: String, timeZone: TimeZone) throws(PostingFetchError) -> PostingMetadata {
        guard let posting = jobPosting(inJSON: text) else { throw .nothingUsable }
        let metadata = posting.metadata(timeZone: timeZone)
        guard metadata.role != nil || metadata.company != nil else { throw .nothingUsable }
        return metadata
    }

    private static func parseHTML(
        _ document: HTMLDocument,
        finalURL: URL?,
        timeZone: TimeZone
    ) throws(PostingFetchError) -> PostingMetadata {
        let posting = document.jsonLDBlocks.lazy.compactMap(jobPosting(inJSON:)).first
        if posting == nil, LoginWall.matches(document, finalURL: finalURL) {
            throw .loginWall
        }
        var metadata = posting?.metadata(timeZone: timeZone) ?? PostingMetadata()
        if metadata.role == nil || metadata.company == nil {
            let fallback = PageTitleReader.read(document)
            metadata.role = metadata.role ?? fallback.role
            metadata.company = metadata.company ?? fallback.company
        }
        guard metadata.role != nil || metadata.company != nil else { throw .nothingUsable }
        return metadata
    }

    private static func jobPosting(inJSON text: String) -> JSONLDNode? {
        guard let document = try? JSONDecoder().decode(OneOrMany<JSONLDNode>.self, from: Data(text.utf8)) else {
            return nil
        }
        return JSONLDNode.firstJobPosting(in: document.values)
    }

    private static func isJSON(_ text: String, contentType: String?) -> Bool {
        if let contentType, contentType.localizedCaseInsensitiveContains("json") { return true }
        let first = text.first { !$0.isWhitespace && $0 != "\u{FEFF}" }
        return first == "{" || first == "["
    }

    /// Decodes the body with the charset the server declared, falling back to UTF-8 and then Latin-1, which accepts
    /// any bytes.
    private static func decodeText(_ body: Data, textEncodingName: String?) -> String {
        if let textEncodingName {
            let declared = CFStringConvertIANACharSetNameToEncoding(textEncodingName as CFString)
            if declared != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(declared))
                if let text = String(data: body, encoding: encoding) { return text }
            }
        }
        return String(bytes: body, encoding: .utf8) ?? String(bytes: body, encoding: .isoLatin1) ?? ""
    }
}

/// Recognizes a sign-in page served in place of a posting.
enum LoginWall {
    private static let signInPathComponents: Set<String> = [
        "authwall", "auth", "login", "log-in", "signin", "sign-in", "sign_in", "sso", "uas",
    ]

    static func matches(_ document: HTMLDocument, finalURL: URL?) -> Bool {
        if let finalURL, finalURL.pathComponents.contains(where: { signInPathComponents.contains($0.lowercased()) }) {
            return true
        }
        if let title = document.title, isSignInTitle(title) {
            return true
        }
        // A password field alone could be a sign-in box on a real posting, so it counts only without a page title.
        return document.hasPasswordField && document.metaContent["og:title"] == nil
    }

    /// True for titles such as "Sign Up | LinkedIn" or "LinkedIn Login, Sign in | LinkedIn", where a whole segment is
    /// a sign-in phrase. A role such as "Sign-in Experience Engineer" does not match.
    private static func isSignInTitle(_ title: String) -> Bool {
        let phrase = /(?:\w+\s)?(?:sign[\s-]?in|sign[\s-]?up|log[\s-]?in|login)/.ignoresCase()
        return title.split(separator: /\s*[|,:–—]\s*|\s+-\s+/).contains { segment in
            segment.trimmingCharacters(in: .whitespaces).wholeMatch(of: phrase) != nil
        }
    }
}

/// Reads a role and company from Open Graph tags and the page title.
enum PageTitleReader {
    /// Sites that host postings for other companies. Their name is never the hiring company.
    private static let jobBoards: Set<String> = [
        "ashby", "bamboohr", "built in", "glassdoor", "greenhouse", "icims", "indeed", "jobvite", "lever",
        "linkedin", "smartrecruiters", "wellfound", "workable", "workday", "ziprecruiter",
    ]

    struct Parts: Equatable {
        var role: String?
        var company: String?
    }

    static func read(_ document: HTMLDocument) -> Parts {
        let meta = document.metaContent
        let siteName = meta["og:site_name"].flatMap { isJobBoard($0) ? nil : $0 }
        // A site name already names the company, so the Open Graph title is then split only at "@" or "at". A role
        // such as "Engineer – Payments" stays whole.
        let openGraph = meta["og:title"].map { siteName == nil ? split($0) : splitAtCompany($0) } ?? Parts()
        let title = document.title.map(split) ?? Parts()
        let company = [openGraph.company, siteName, title.company]
            .lazy
            .compactMap { $0 }
            .first { !isJobBoard($0) }
        return Parts(role: openGraph.role ?? title.role, company: company)
    }

    /// Splits titles such as "Role @ Company", "Role at Company", "Role | Company | Site", or "Role - Company".
    static func split(_ title: String) -> Parts {
        let segments = title.split(separator: /\s+[|–—-]\s+/).compactMap { HTMLText.clean(String($0)) }
        guard let first = segments.first else { return Parts() }
        let parts = splitAtCompany(first)
        return parts.company == nil ? Parts(role: parts.role, company: segments.dropFirst().first) : parts
    }

    /// Splits "Role @ Company" or "Role at Company" at the last "@" or "at", dropping a "Job Application for" prefix.
    static func splitAtCompany(_ title: String) -> Parts {
        var title = title
        if let prefix = title.firstMatch(of: /^\s*job application for\s+/.ignoresCase()) {
            title.removeSubrange(prefix.range)
        }
        guard let separator = title.ranges(of: /\s+(?:@|at)\s+/).last else {
            return Parts(role: HTMLText.clean(title))
        }
        return Parts(
            role: HTMLText.clean(String(title[..<separator.lowerBound])),
            company: HTMLText.clean(String(title[separator.upperBound...]))
        )
    }

    private static func isJobBoard(_ name: String) -> Bool {
        jobBoards.contains(name.lowercased())
    }
}
