import Foundation
import Testing

@testable import Domain

struct ApplicationDraftTests {
    private static let today = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeDraft() -> ApplicationDraft {
        ApplicationDraft(today: Self.today)
    }

    // MARK: Defaults

    @Test func startsAtAppliedOnTodayWithNoNextStep() {
        let draft = makeDraft()
        #expect(draft.stage == .applied)
        #expect(draft.appliedOn == Self.today)
        #expect(draft.hasNextStep == false)
        #expect(draft.nextStep == nil)
    }

    // MARK: Validation

    @Test func emptyDraftIsInvalid() {
        #expect(makeDraft().isValid == false)
    }

    @Test func needsBothCompanyAndRole() {
        var draft = makeDraft()
        draft.company = "Stripe"
        #expect(draft.isValid == false)

        draft.company = ""
        draft.role = "Engineering Manager"
        #expect(draft.isValid == false)

        draft.company = "Stripe"
        #expect(draft.isValid)
    }

    @Test func whitespaceOnlyCompanyOrRoleIsInvalid() {
        var draft = makeDraft()
        draft.company = "  \n\t "
        draft.role = "Engineering Manager"
        #expect(draft.isValid == false)

        draft.company = "Stripe"
        draft.role = "   "
        #expect(draft.isValid == false)
    }

    @Test func trimsCompanyAndRole() {
        var draft = makeDraft()
        draft.company = "  Stripe \n"
        draft.role = "\tEM, Mobile  "
        #expect(draft.isValid)
        #expect(draft.trimmedCompany == "Stripe")
        #expect(draft.trimmedRole == "EM, Mobile")
    }

    // MARK: Dirty tracking

    @Test func freshDraftIsClean() {
        #expect(makeDraft().isDirty == false)
    }

    @Test func anyEditMakesTheDraftDirty() {
        let edits: [(String, (inout ApplicationDraft) -> Void)] = [
            ("link", { $0.link = "https://example.com/job" }),
            ("company", { $0.company = "S" }),
            ("role", { $0.role = "E" }),
            ("stage", { $0.stage = .screening }),
            ("appliedOn", { $0.appliedOn = Self.today.addingTimeInterval(86_400) }),
            ("notes", { $0.notes = "Referral" }),
            ("hasNextStep", { $0.hasNextStep = true }),
            ("nextStepTitle", { $0.nextStepTitle = "Phone screen" }),
            ("nextStepDate", { $0.nextStepDate = Self.today.addingTimeInterval(86_400) }),
            ("whitespace", { $0.company = " " }),
        ]

        for (name, edit) in edits {
            var draft = makeDraft()
            edit(&draft)
            #expect(draft.isDirty, "editing \(name) should make the draft dirty")
        }
    }

    @Test func revertingAnEditMakesTheDraftCleanAgain() {
        var draft = makeDraft()
        draft.company = "Stripe"
        draft.stage = .offer
        draft.appliedOn = Self.today.addingTimeInterval(86_400)
        #expect(draft.isDirty)

        draft.company = ""
        draft.stage = .applied
        draft.appliedOn = Self.today
        #expect(draft.isDirty == false)
    }

    // MARK: Saved values

    @Test func nextStepIsNilWhileTheToggleIsOff() {
        var draft = makeDraft()
        draft.nextStepTitle = "Onsite loop"
        draft.nextStepDate = Self.today.addingTimeInterval(86_400)
        #expect(draft.nextStep == nil)
    }

    @Test func nextStepCarriesTitleAndDateWhileTheToggleIsOn() {
        var draft = makeDraft()
        let date = Self.today.addingTimeInterval(86_400)
        draft.hasNextStep = true
        draft.nextStepTitle = "  Onsite loop "
        draft.nextStepDate = date
        #expect(draft.nextStep == NextStep(title: "Onsite loop", date: date))
    }

    @Test func blankNextStepTitleIsNil() {
        var draft = makeDraft()
        draft.hasNextStep = true
        draft.nextStepTitle = "   "
        #expect(draft.nextStep?.title == nil)
    }

    @Test func blankLinkIsNilAndTheLinkIsTrimmed() {
        var draft = makeDraft()
        draft.link = "   "
        #expect(draft.trimmedLink == nil)

        draft.link = " https://stripe.com/jobs/1 \n"
        #expect(draft.trimmedLink == "https://stripe.com/jobs/1")
    }
}
