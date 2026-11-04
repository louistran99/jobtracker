import Domain
import Foundation
import SwiftData
import Testing

@testable import Persistence

@MainActor
struct ApplicationRepositoryTests {
    private static let today = Date(timeIntervalSince1970: 1_700_000_000)

    // The container owns its contexts, so each test keeps it alive for as long as it uses the context.
    private let container: ModelContainer

    init() throws {
        container = try PersistenceController.makeContainer(inMemory: true)
    }

    private var context: ModelContext { container.mainContext }

    private func makeDraft() -> ApplicationDraft {
        var draft = ApplicationDraft(today: Self.today)
        draft.company = "  Stripe "
        draft.role = "EM, Mobile Platform\n"
        return draft
    }

    @Test func addSavesOneApplicationWithTheDraftValues() throws {
        var draft = makeDraft()
        draft.stage = .onsite
        draft.link = " https://stripe.com/jobs/6519024 "
        draft.notes = "Referral from Sam"
        draft.hasNextStep = true
        draft.nextStepTitle = "Onsite loop"
        draft.nextStepDate = Self.today.addingTimeInterval(86_400)

        try ApplicationRepository(context: context).add(draft)

        let stored = try context.fetch(FetchDescriptor<Application>())
        let application = try #require(stored.first)
        #expect(stored.count == 1)
        #expect(application.company == "Stripe")
        #expect(application.role == "EM, Mobile Platform")
        #expect(application.stage == .onsite)
        #expect(application.appliedOn == Self.today)
        #expect(application.link == "https://stripe.com/jobs/6519024")
        #expect(application.notes == "Referral from Sam")
        #expect(application.nextStepTitle == "Onsite loop")
        #expect(application.nextStepDate == Self.today.addingTimeInterval(86_400))
    }

    @Test func addUsesTheDefaultsForAnUntouchedForm() throws {
        try ApplicationRepository(context: context).add(makeDraft())

        let application = try #require(context.fetch(FetchDescriptor<Application>()).first)
        #expect(application.stage == .applied)
        #expect(application.appliedOn == Self.today)
        #expect(application.link == nil)
        #expect(application.notes.isEmpty)
        #expect(application.nextStepTitle == nil)
        #expect(application.nextStepDate == nil)
    }

    @Test func addDropsNextStepFieldsWhileTheToggleIsOff() throws {
        var draft = makeDraft()
        draft.nextStepTitle = "Phone screen"
        draft.nextStepDate = Self.today.addingTimeInterval(86_400)

        try ApplicationRepository(context: context).add(draft)

        let application = try #require(context.fetch(FetchDescriptor<Application>()).first)
        #expect(application.nextStepTitle == nil)
        #expect(application.nextStepDate == nil)
    }

    @Test func addRejectsAnInvalidDraftAndWritesNothing() throws {
        var draft = ApplicationDraft(today: Self.today)
        draft.company = "Stripe"
        draft.role = "   "

        #expect(throws: ApplicationRepositoryError.invalidDraft) {
            try ApplicationRepository(context: context).add(draft)
        }

        #expect(try context.fetch(FetchDescriptor<Application>()).isEmpty)
        #expect(context.hasChanges == false)
    }

    @Test func unknownStoredStageFallsBackToApplied() {
        let application = Application(company: "Stripe", role: "EM")
        application.stageRawValue = "archived"
        #expect(application.stage == .applied)
    }
}
