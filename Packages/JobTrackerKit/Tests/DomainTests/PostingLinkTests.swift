import Foundation
import Testing

@testable import Domain

struct PostingLinkTests {
    private static let ashbyLink = "https://jobs.ashbyhq.com/grow-therapy/eb6b5a30-a02d-47b7-83ac-51839574d2d2"

    private func normalized(_ link: String) -> String? {
        var draft = ApplicationDraft()
        draft.link = link
        return draft.normalizedLink
    }

    @Test func anAshbyLinkWithAndWithoutTheDepartmentIsTheSamePosting() throws {
        let plain = try #require(normalized(Self.ashbyLink))
        #expect(normalized("\(Self.ashbyLink)?departmentId=8f5e4c2a-3b1d-4e6f-9a7b-2c8d0e1f3a5b") == plain)
        #expect(plain == Self.ashbyLink)
    }

    @Test(arguments: [
        // A missing scheme, or http, becomes https.
        ("stripe.com/jobs/listing/6519024", "https://stripe.com/jobs/listing/6519024"),
        ("http://stripe.com/jobs/listing/6519024", "https://stripe.com/jobs/listing/6519024"),
        // The host is lowercased and loses www. The path keeps its case.
        ("https://WWW.Stripe.COM/jobs/Listing/6519024", "https://stripe.com/jobs/Listing/6519024"),
        // The default port, the fragment and trailing slashes are dropped.
        ("https://stripe.com:443/jobs/listing/6519024/#apply", "https://stripe.com/jobs/listing/6519024"),
        ("https://stripe.com//", "https://stripe.com"),
        // Tracking parameters are removed, whatever their case. A query left empty leaves no "?".
        (
            "https://stripe.com/jobs/listing/6519024?utm_source=linkedin&UTM_Medium=social&gclid=abc&ref=hn",
            "https://stripe.com/jobs/listing/6519024"
        ),
        (
            "https://boards.greenhouse.io/acme/jobs/123?gh_src=x1&source=LinkedIn&trk=feed",
            "https://boards.greenhouse.io/acme/jobs/123"
        ),
        // The query items that name the posting stay, sorted.
        (
            "https://job-boards.greenhouse.io/acme?gh_jid=42&b=2&a=1&utm_campaign=fall",
            "https://job-boards.greenhouse.io/acme?a=1&b=2&gh_jid=42"
        ),
        ("https://example.com/jobs?id=2&id=1", "https://example.com/jobs?id=1&id=2"),
        // A non-default port stays.
        ("https://example.com:8443/jobs/1", "https://example.com:8443/jobs/1"),
    ])
    func normalizes(_ link: String, to expected: String) {
        #expect(normalized(link) == expected)
    }

    @Test func linksThatDifferOnlyByTrackingAreTheSamePosting() {
        let shared = "http://www.stripe.com/jobs/listing/6519024/?utm_source=x&gclid=y#apply"
        #expect(normalized(shared) == normalized("stripe.com/jobs/listing/6519024"))
    }

    @Test func differentPostingsStayDifferent() {
        #expect(normalized("stripe.com/jobs/listing/6519024") != normalized("stripe.com/jobs/listing/6519025"))
        #expect(normalized("example.com/jobs?id=1") != normalized("example.com/jobs?id=2"))
    }

    @Test(arguments: ["", "  ", "https://str", "not a link", "ftp://example.com/job"])
    func textThatIsNotAWebAddressHasNoKey(_ link: String) {
        #expect(normalized(link) == nil)
    }
}
