import Domain
import Foundation
import Testing

@testable import ViewModels

@MainActor
struct NewApplicationViewModelTests {
    private struct SaveError: Error {}

    private struct FetchError: Error {}

    private func makeViewModel(
        save: @escaping (ApplicationDraft) throws -> Void = { _ in }
    ) -> NewApplicationViewModel {
        NewApplicationViewModel(
            draft: ApplicationDraft(today: Date(timeIntervalSince1970: 1_700_000_000)),
            fetchPosting: { _ in throw FetchError() },
            save: save
        )
    }

    @Test func startsUnableToAddAndNotDirty() {
        let viewModel = makeViewModel()
        #expect(viewModel.canAdd == false)
        #expect(viewModel.blocksInteractiveDismiss == false)
        #expect(viewModel.alert == nil)
        #expect(viewModel.shouldDismiss == false)
    }

    @Test func canAddOnceCompanyAndRoleAreFilled() {
        let viewModel = makeViewModel()
        viewModel.draft.company = "Stripe"
        #expect(viewModel.canAdd == false)

        viewModel.draft.role = "EM"
        #expect(viewModel.canAdd)
    }

    @Test func cancelOnACleanDraftDismisses() {
        let viewModel = makeViewModel()
        viewModel.cancel()
        #expect(viewModel.shouldDismiss)
        #expect(viewModel.alert == nil)
    }

    @Test func cancelOnADirtyDraftAsksToDiscard() {
        let viewModel = makeViewModel()
        viewModel.draft.company = "Stripe"
        viewModel.cancel()
        #expect(viewModel.shouldDismiss == false)
        #expect(viewModel.alert == .discard)
        #expect(viewModel.alertTitle == "Discard this application?")
    }

    @Test func confirmDiscardDismisses() {
        let viewModel = makeViewModel()
        viewModel.draft.company = "Stripe"
        viewModel.cancel()
        viewModel.confirmDiscard()
        #expect(viewModel.shouldDismiss)
        #expect(viewModel.alert == nil)
    }

    @Test func dismissingTheAlertKeepsTheDraft() {
        let viewModel = makeViewModel()
        viewModel.draft.company = "Stripe"
        viewModel.cancel()
        viewModel.isPresentingAlert = false
        #expect(viewModel.alert == nil)
        #expect(viewModel.shouldDismiss == false)
        #expect(viewModel.draft.company == "Stripe")
    }

    @Test func addDoesNothingWhileInvalid() {
        var didSave = false
        let viewModel = makeViewModel(save: { _ in didSave = true })
        viewModel.add()
        #expect(didSave == false)
        #expect(viewModel.shouldDismiss == false)
    }

    @Test func addSavesAndDismisses() throws {
        var saved: ApplicationDraft?
        let viewModel = makeViewModel(save: { saved = $0 })
        viewModel.draft.company = "Stripe"
        viewModel.draft.role = "EM, Mobile Platform"
        viewModel.draft.stage = .onsite
        viewModel.add()

        let draft = try #require(saved)
        #expect(draft.company == "Stripe")
        #expect(draft.role == "EM, Mobile Platform")
        #expect(draft.stage == .onsite)
        #expect(viewModel.shouldDismiss)
        #expect(viewModel.alert == nil)
    }

    @Test func addShowsAnAlertWhenSaveFails() {
        let viewModel = makeViewModel(save: { _ in throw SaveError() })
        viewModel.draft.company = "Stripe"
        viewModel.draft.role = "EM"
        viewModel.add()
        #expect(viewModel.shouldDismiss == false)
        #expect(viewModel.alert == .saveFailed)
        #expect(viewModel.alertTitle == "Can't Save Application")
    }
}
