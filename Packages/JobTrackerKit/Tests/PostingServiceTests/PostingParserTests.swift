import Domain
import Foundation
import Testing

@testable import PostingService

struct PostingParserTests {
    static let timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private func parse(
        _ body: String,
        contentType: String? = "text/html; charset=utf-8",
        finalURL: String = "https://example.com/jobs/1"
    ) throws(PostingFetchError) -> PostingMetadata {
        try PostingParser.parse(
            body: Data(body.utf8),
            contentType: contentType,
            textEncodingName: nil,
            finalURL: URL(string: finalURL),
            timeZone: Self.timeZone
        )
    }

    private func page(head: String) -> String {
        "<!DOCTYPE html><html><head>\(head)</head><body><div id=\"root\"></div></body></html>"
    }

    // MARK: Saved Ashby posting

    @Test func readsTheSavedAshbyPosting() throws {
        let metadata = try PostingParser.parse(
            body: try Fixture.ashbyPage(),
            contentType: "text/html; charset=utf-8",
            textEncodingName: "utf-8",
            finalURL: URL(string: Fixture.ashbyLink),
            timeZone: Self.timeZone
        )
        #expect(metadata.role == "Engineering Manager, Momentum")
        #expect(metadata.company == "Grow Therapy")
        #expect(metadata.locations == ["New York"])
        #expect(metadata.isRemote)
        #expect(metadata.datePosted == Self.day(2026, 7, 2))
    }

    // MARK: 1. JSON body

    @Test func decodesAJSONBodyAsAJobPosting() throws {
        let json = """
            {"@context": "https://schema.org", "@type": "JobPosting", "title": "iOS Engineer",
             "hiringOrganization": {"@type": "Organization", "name": "Stripe"},
             "jobLocation": {"@type": "Place", "address": {"addressLocality": "Seattle"}}}
            """
        let metadata = try parse(json, contentType: "application/json")
        #expect(metadata == PostingMetadata(role: "iOS Engineer", company: "Stripe", locations: ["Seattle"]))
    }

    @Test func recognizesJSONWithoutAContentType() throws {
        let json = #"[{"@type": "Organization", "name": "Ramp"}, {"@type": ["JobPosting"], "title": "EM, Mobile"}]"#
        let metadata = try parse(json, contentType: nil)
        #expect(metadata.role == "EM, Mobile")
    }

    @Test func jsonWithoutAJobPostingIsNothingUsable() {
        #expect(throws: PostingFetchError.nothingUsable) {
            try parse(#"{"jobs": [{"name": "iOS Engineer"}]}"#, contentType: "application/json")
        }
    }

    // MARK: 2. JSON-LD in HTML

    @Test func readsAnArrayOfPlaces() throws {
        let metadata = try parse(
            page(
                head: """
                    <script type="application/ld+json">
                    {"@type": "JobPosting", "title": "Staff Engineer", "hiringOrganization": "Linear",
                     "jobLocation": [
                       {"@type": "Place", "address": {"addressLocality": "San Francisco", "addressCountry": "US"}},
                       {"@type": "Place", "address": {"addressRegion": "New York"}},
                       {"@type": "Place", "address": {"addressLocality": "San Francisco"}},
                       {"@type": "Place", "address": {"addressCountry": {"@type": "Country", "name": "Canada"}}}
                     ],
                     "datePosted": "2026-10-12T09:30:00-07:00"}
                    </script>
                    """))
        #expect(metadata.role == "Staff Engineer")
        #expect(metadata.company == "Linear")
        #expect(metadata.locations == ["San Francisco", "New York", "Canada"])
        #expect(metadata.isRemote == false)
        #expect(metadata.datePosted == ISO8601DateFormatter().date(from: "2026-10-12T16:30:00Z"))
    }

    @Test func findsTheJobPostingInAGraph() throws {
        let metadata = try parse(
            page(
                head: """
                    <script type='application/ld+json'>{"@context": "https://schema.org", "@graph": [
                      {"@type": "WebPage", "name": "Careers"},
                      {"@type": "JobPosting", "title": "Product Designer", "hiringOrganization": {"name": "Duolingo"},
                       "jobLocationType": ["TELECOMMUTE"]}
                    ]}</script>
                    """))
        #expect(metadata.role == "Product Designer")
        #expect(metadata.company == "Duolingo")
        #expect(metadata.isRemote)
    }

    @Test func skipsAMalformedBlock() throws {
        let metadata = try parse(
            page(
                head: """
                    <script type="application/ld+json">{"@type": "BreadcrumbList",</script>
                    <script type="application/ld+json"><!--
                    {"@type": "JobPosting", "title": "EM, Guest Apps", "hiringOrganization": {"name": "Airbnb"}}
                    --></script>
                    """))
        #expect(metadata.role == "EM, Guest Apps")
        #expect(metadata.company == "Airbnb")
    }

    @Test func fillsWhatTheJobPostingLacksFromTheTitle() throws {
        let metadata = try parse(
            page(
                head: """
                    <title>Head of Mobile @ Linear</title>
                    <script type="application/ld+json">{"@type": "JobPosting", "title": "Head of Mobile"}</script>
                    """))
        #expect(metadata.role == "Head of Mobile")
        #expect(metadata.company == "Linear")
    }

    @Test func aJobPostingWinsOverASignInLookingURL() throws {
        let metadata = try parse(
            page(head: #"<script type="application/ld+json">{"@type": "JobPosting", "title": "EM"}</script>"#),
            finalURL: "https://example.com/login?next=/jobs/1"
        )
        #expect(metadata.role == "EM")
    }

    // MARK: 3. Open Graph, then the title

    @Test func readsOpenGraphTags() throws {
        let metadata = try parse(
            page(
                head: """
                    <meta content="Senior iOS Engineer" property="og:title">
                    <meta property='og:site_name' content='Ramp'>
                    """))
        #expect(metadata == PostingMetadata(role: "Senior iOS Engineer", company: "Ramp"))
    }

    @Test func ignoresAJobBoardAsTheCompany() throws {
        let metadata = try parse(
            page(
                head: """
                    <title>Senior iOS Engineer - Spotify</title>
                    <meta property="og:title" content="Senior iOS Engineer">
                    <meta property="og:site_name" content="Lever">
                    """))
        #expect(metadata.company == "Spotify")
    }

    @Test(arguments: [
        ("Engineering Manager, Momentum @ Grow Therapy", "Engineering Manager, Momentum", "Grow Therapy"),
        ("Job Application for Staff Engineer at Ramp", "Staff Engineer", "Ramp"),
        ("Product Designer | Duolingo | Careers", "Product Designer", "Duolingo"),
        ("EM, iOS – Spotify", "EM, iOS", "Spotify"),
    ])
    func splitsTheTitle(title: String, role: String, company: String) throws {
        let metadata = try parse(page(head: "<title>\n  \(title)\n</title>"))
        #expect(metadata.role == role)
        #expect(metadata.company == company)
    }

    @Test func aTitleWithoutACompanyStillGivesTheRole() throws {
        let metadata = try parse(page(head: "<title>Front-end Engineer</title>"))
        #expect(metadata == PostingMetadata(role: "Front-end Engineer"))
    }

    @Test func decodesEntities() throws {
        let metadata = try parse(
            page(
                head: """
                    <meta property="og:title" content="R&amp;D Engineer &#8211; Payments&nbsp;&#x2F; Risk">
                    <meta property="og:site_name" content="Ben &amp; Jerry&#39;s">
                    """))
        #expect(metadata.role == "R&D Engineer – Payments / Risk")
        #expect(metadata.company == "Ben & Jerry's")
    }

    @Test func decodesTheDeclaredCharset() throws {
        let body = try #require("<title>Ingénieur iOS @ Société Générale</title>".data(using: .isoLatin1))
        let metadata = try PostingParser.parse(
            body: body,
            contentType: "text/html; charset=iso-8859-1",
            textEncodingName: "iso-8859-1",
            finalURL: nil,
            timeZone: Self.timeZone
        )
        #expect(metadata.role == "Ingénieur iOS")
        #expect(metadata.company == "Société Générale")
    }

    // MARK: 4. Couldn't read

    @Test(arguments: [
        "https://www.linkedin.com/authwall?trk=gf&sessionRedirect=https%3A%2F%2Fwww.linkedin.com%2Fjobs%2Fview%2F1",
        "https://example.com/users/sign_in",
        "https://example.com/account/login",
    ])
    func aSignInURLIsALoginWall(finalURL: String) {
        #expect(throws: PostingFetchError.loginWall) {
            try parse(page(head: "<title>Staff Engineer @ Example</title>"), finalURL: finalURL)
        }
    }

    @Test(arguments: ["Sign Up | LinkedIn", "LinkedIn Login, Sign in | LinkedIn", "Log in - Workday"])
    func aSignInTitleIsALoginWall(title: String) {
        #expect(throws: PostingFetchError.loginWall) {
            try parse(page(head: "<title>\(title)</title>"))
        }
    }

    @Test func aPasswordFieldWithoutAPostingIsALoginWall() {
        let html = "<html><head><title>Careers</title></head><body><input type=password name=pw></body></html>"
        #expect(throws: PostingFetchError.loginWall) {
            try parse(html)
        }
    }

    @Test func aRoleAboutSignInIsNotALoginWall() throws {
        let metadata = try parse(page(head: "<title>Sign-in Experience Engineer @ Okta</title>"))
        #expect(metadata.role == "Sign-in Experience Engineer")
        #expect(metadata.company == "Okta")
    }

    @Test func aPageWithNothingUsableIsUnreadable() {
        #expect(throws: PostingFetchError.nothingUsable) {
            try parse("<html><head><meta charset=\"utf-8\"></head><body>Loading…</body></html>")
        }
    }
}

struct PostingDateTests {
    private let timeZone = PostingParserTests.timeZone

    @Test func aDateWithoutATimeIsThatDayInTheTimeZone() {
        #expect(PostingDate.parse("2026-07-02", timeZone: timeZone) == PostingParserTests.day(2026, 7, 2))
    }

    @Test func aDateTimeIsThatInstant() {
        let expected = ISO8601DateFormatter().date(from: "2026-07-02T17:00:00Z")
        #expect(PostingDate.parse("2026-07-02T10:00:00-07:00", timeZone: timeZone) == expected)
        #expect(PostingDate.parse("2026-07-02T17:00:00.000Z", timeZone: timeZone) == expected)
    }

    @Test func aDateTimeWithoutAnOffsetIsReadAsItsDay() {
        #expect(PostingDate.parse("2026-07-02T10:00:00", timeZone: timeZone) == PostingParserTests.day(2026, 7, 2))
    }

    @Test(arguments: ["", "July 2, 2026", "2026-02-30"])
    func rejectsInvalidDates(_ text: String) {
        #expect(PostingDate.parse(text, timeZone: timeZone) == nil)
    }
}
