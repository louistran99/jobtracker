import Foundation
import Testing

@testable import Domain

struct PostingURLTests {
    private func postingURL(for link: String) -> String? {
        var draft = ApplicationDraft()
        draft.link = link
        return draft.postingURL?.absoluteString
    }

    @Test func blankLinkHasNoURL() {
        #expect(postingURL(for: "") == nil)
        #expect(postingURL(for: "   \n") == nil)
    }

    @Test func addsHTTPSWhenTheSchemeIsMissing() {
        #expect(postingURL(for: " stripe.com/jobs/listing/6519024 ") == "https://stripe.com/jobs/listing/6519024")
    }

    @Test func upgradesHTTPToHTTPS() {
        #expect(postingURL(for: "http://stripe.com/jobs") == "https://stripe.com/jobs")
        #expect(postingURL(for: "HTTPS://stripe.com/jobs") == "https://stripe.com/jobs")
    }

    @Test func keepsTheQuery() {
        let link = "https://jobs.ashbyhq.com/grow-therapy/eb6b5a30?departmentId=1"
        #expect(postingURL(for: link) == link)
    }

    @Test(arguments: [
        "https://str",  // still typing the host
        "localhost:8080/jobs",  // no dot in the host
        "not a link",
        "ftp://example.com/job",
        "mailto:jobs@example.com",
        "https://user:secret@example.com/job",
        "https://.com",
    ])
    func rejectsTextThatIsNotAWebAddress(_ link: String) {
        #expect(postingURL(for: link) == nil)
    }
}

struct PostingAutofillTests {
    private static let growTherapy = PostingMetadata(role: "Engineering Manager, Momentum", company: "Grow Therapy")
    private static let stripe = PostingMetadata(role: "EM, Mobile Platform", company: "Stripe")

    @Test func fillsBlankFields() {
        var draft = ApplicationDraft()
        draft.autofill(from: Self.growTherapy)
        #expect(draft.company == "Grow Therapy")
        #expect(draft.role == "Engineering Manager, Momentum")
        #expect(draft.autofilledFields == [.company, .role])
        #expect(draft.isValid)
    }

    @Test func treatsWhitespaceAsBlank() {
        var draft = ApplicationDraft()
        draft.company = "  "
        draft.autofill(from: Self.growTherapy)
        #expect(draft.company == "Grow Therapy")
    }

    @Test func neverOverwritesTypedText() {
        var draft = ApplicationDraft()
        draft.company = "Grow"
        draft.autofill(from: Self.growTherapy)
        #expect(draft.company == "Grow")
        #expect(draft.role == "Engineering Manager, Momentum")
        #expect(draft.autofilledFields == [.role])
    }

    @Test func typedTextMatchingThePostingIsStillTheirs() {
        var draft = ApplicationDraft()
        draft.company = "Grow Therapy"
        draft.autofill(from: Self.growTherapy)
        #expect(draft.autofilledFields == [.role])
    }

    @Test func replacesItsOwnValuesForANewPosting() {
        var draft = ApplicationDraft()
        draft.autofill(from: Self.growTherapy)
        draft.autofill(from: Self.stripe)
        #expect(draft.company == "Stripe")
        #expect(draft.role == "EM, Mobile Platform")
        #expect(draft.autofilledFields == [.company, .role])
    }

    @Test func editedFieldsStayEditedAcrossPostings() {
        var draft = ApplicationDraft()
        draft.autofill(from: Self.growTherapy)
        draft.role = "Engineering Manager"
        #expect(draft.autofilledFields == [.company])

        draft.autofill(from: Self.stripe)
        #expect(draft.company == "Stripe")
        #expect(draft.role == "Engineering Manager")
        #expect(draft.autofilledFields == [.company])
    }

    @Test func clearsAnEarlierPostingsValueTheNewPostingLacks() {
        var draft = ApplicationDraft()
        draft.autofill(from: Self.growTherapy)
        draft.autofill(from: PostingMetadata(role: "Staff Engineer"))
        #expect(draft.company.isEmpty)
        #expect(draft.role == "Staff Engineer")
        #expect(draft.autofilledFields == [.role])
    }

    @Test func clearAutofillRemovesOnlyThePostingsValues() {
        var draft = ApplicationDraft()
        draft.autofill(from: Self.growTherapy)
        draft.role = "Engineering Manager"

        draft.clearAutofill()

        #expect(draft.company.isEmpty)
        #expect(draft.role == "Engineering Manager")
        #expect(draft.autofilledFields.isEmpty)
    }

    @Test func leavesBlankFieldsBlankWhenThePostingLacksThem() {
        var draft = ApplicationDraft()
        draft.autofill(from: PostingMetadata(company: "Grow Therapy"))
        #expect(draft.role.isEmpty)
        #expect(draft.autofilledFields == [.company])
    }
}

struct PostingMetadataSummaryTests {
    private static let locale = Locale(identifier: "en_US")
    private static let timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private func summary(_ metadata: PostingMetadata) -> String? {
        metadata.summary(locale: Self.locale, timeZone: Self.timeZone)
    }

    @Test func joinsPlaceWorkplaceAndDate() {
        let metadata = PostingMetadata(locations: ["New York"], isRemote: true, datePosted: Self.date(2026, 7, 2))
        #expect(summary(metadata) == "New York · Remote · Posted Jul 2")
    }

    @Test func countsExtraLocations() {
        let metadata = PostingMetadata(locations: ["San Francisco", "New York", "Seattle"])
        #expect(summary(metadata) == "San Francisco +2")
    }

    @Test func leavesOutMissingParts() {
        #expect(summary(PostingMetadata(datePosted: Self.date(2026, 10, 12))) == "Posted Oct 12")
        #expect(summary(PostingMetadata(role: "EM", company: "Stripe")) == nil)
    }
}
