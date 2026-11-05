import Domain
import Foundation
import Testing

@testable import ViewModels

/// A posting fetch the test finishes by hand, so it can inspect the view model while the fetch is in flight.
private actor FetchGate {
    private(set) var requestedURLs: [URL] = []
    private var pending: CheckedContinuation<PostingMetadata, any Error>?
    private var requestWaiters: [CheckedContinuation<Void, Never>] = []

    func fetch(_ url: URL) async throws -> PostingMetadata {
        requestedURLs.append(url)
        for waiter in requestWaiters {
            waiter.resume()
        }
        requestWaiters.removeAll()
        return try await withCheckedThrowingContinuation { pending = $0 }
    }

    /// Returns once a fetch has started.
    func waitForRequest() async {
        guard requestedURLs.isEmpty else { return }
        await withCheckedContinuation { requestWaiters.append($0) }
    }

    func finish(with result: Result<PostingMetadata, any Error>) {
        pending?.resume(with: result)
        pending = nil
    }
}

/// Returns queued results, one per fetch.
private actor FetchResults {
    private var results: [Result<PostingMetadata, any Error>]

    init(_ results: [Result<PostingMetadata, any Error>]) {
        self.results = results
    }

    func next() throws -> PostingMetadata {
        try results.removeFirst().get()
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct NewApplicationViewModelPostingTests {
    private struct FetchError: Error {}

    nonisolated private static let ashbyLink =
        "https://jobs.ashbyhq.com/grow-therapy/eb6b5a30-a02d-47b7-83ac-51839574d2d2"
    nonisolated private static let growTherapy = PostingMetadata(
        role: "Engineering Manager, Momentum",
        company: "Grow Therapy",
        locations: ["New York"],
        isRemote: true
    )

    private func makeViewModel(
        link: String = ashbyLink,
        debounce: Duration = .zero,
        fetchPosting: @escaping NewApplicationViewModel.FetchPosting,
        save: @escaping (ApplicationDraft) throws -> Void = { _ in }
    ) -> NewApplicationViewModel {
        var draft = ApplicationDraft(today: Date(timeIntervalSince1970: 1_700_000_000))
        draft.link = link
        return NewApplicationViewModel(draft: draft, fetchPosting: fetchPosting, debounce: debounce, save: save)
    }

    private func makeViewModel(link: String = ashbyLink, gate: FetchGate) -> NewApplicationViewModel {
        makeViewModel(link: link, fetchPosting: { try await gate.fetch($0) })
    }

    // MARK: Idle

    @Test func startsIdle() {
        let viewModel = makeViewModel(link: "", fetchPosting: { _ in Self.growTherapy })
        #expect(viewModel.linkState == .idle)
        #expect(viewModel.linkFooter == "The company and role are filled in from the posting.")
        #expect(viewModel.detailsFooter == nil)
        #expect(viewModel.linkStateAnnouncement == nil)
    }

    @Test func doesNotFetchTextThatIsNotALink() async {
        let gate = FetchGate()
        let viewModel = makeViewModel(link: "stripe", gate: gate)
        await viewModel.loadPosting()
        #expect(viewModel.linkState == .idle)
        #expect(await gate.requestedURLs.isEmpty)
    }

    @Test func fetchesTheNormalizedURL() async throws {
        let gate = FetchGate()
        let viewModel = makeViewModel(link: " stripe.com/jobs/listing/6519024 ", gate: gate)
        let load = Task { await viewModel.loadPosting() }
        await gate.waitForRequest()
        await gate.finish(with: .success(Self.growTherapy))
        await load.value
        #expect(await gate.requestedURLs == [try #require(URL(string: "https://stripe.com/jobs/listing/6519024"))])
    }

    // MARK: Fetching

    @Test func showsFetchingWhileTheRequestIsInFlight() async {
        let gate = FetchGate()
        let viewModel = makeViewModel(gate: gate)
        let load = Task { await viewModel.loadPosting() }
        await gate.waitForRequest()

        #expect(viewModel.linkState == .fetching)
        #expect(viewModel.linkFooter == "Fetching details. You can keep filling in the form.")
        #expect(viewModel.linkStateAnnouncement == "Fetching job details.")

        viewModel.draft.company = "Grow"
        viewModel.draft.role = "EM"
        #expect(viewModel.canAdd, "A fetch in flight never blocks Add")

        await gate.finish(with: .success(Self.growTherapy))
        await load.value
        #expect(viewModel.linkState == .found(Self.growTherapy))
    }

    @Test func keepsWhatThePersonTypesDuringTheFetch() async {
        let gate = FetchGate()
        let viewModel = makeViewModel(gate: gate)
        let load = Task { await viewModel.loadPosting() }
        await gate.waitForRequest()

        viewModel.draft.company = "Grow"
        await gate.finish(with: .success(Self.growTherapy))
        await load.value

        #expect(viewModel.draft.company == "Grow")
        #expect(viewModel.draft.role == "Engineering Manager, Momentum")
    }

    @Test func waitsOutTheDebounceBeforeFetching() async {
        let gate = FetchGate()
        let viewModel = makeViewModel(debounce: .seconds(60), fetchPosting: { try await gate.fetch($0) })
        let load = Task { await viewModel.loadPosting() }
        await Task.yield()
        load.cancel()
        await load.value

        #expect(viewModel.linkState == .idle)
        #expect(await gate.requestedURLs.isEmpty, "A link replaced during the debounce is never fetched")
    }

    @Test func ignoresAResultForALinkThatWasReplaced() async {
        let gate = FetchGate()
        let viewModel = makeViewModel(gate: gate)
        let load = Task { await viewModel.loadPosting() }
        await gate.waitForRequest()

        load.cancel()
        await gate.finish(with: .success(Self.growTherapy))
        await load.value

        #expect(viewModel.draft.company.isEmpty)
        #expect(viewModel.draft.role.isEmpty)
        #expect(viewModel.linkState != .found(Self.growTherapy))
    }

    // MARK: Found

    @Test func fillsCompanyAndRoleWhenFound() async {
        let viewModel = makeViewModel(fetchPosting: { _ in Self.growTherapy })
        await viewModel.loadPosting()

        #expect(viewModel.linkState == .found(Self.growTherapy))
        #expect(viewModel.draft.company == "Grow Therapy")
        #expect(viewModel.draft.role == "Engineering Manager, Momentum")
        #expect(viewModel.canAdd)
        #expect(viewModel.linkFooter == nil)
        #expect(
            viewModel.detailsFooter == "Company and role were filled in from the posting. Edit them if they're wrong.")
        #expect(viewModel.linkStateAnnouncement == "Found the posting. Filled in company and role.")
    }

    @Test func neverOverwritesATypedField() async {
        let viewModel = makeViewModel(fetchPosting: { _ in Self.growTherapy })
        viewModel.draft.company = "Grow"
        await viewModel.loadPosting()

        #expect(viewModel.draft.company == "Grow")
        #expect(viewModel.draft.role == "Engineering Manager, Momentum")
        #expect(viewModel.detailsFooter == "Role was filled in from the posting. Edit it if it's wrong.")
        #expect(viewModel.linkStateAnnouncement == "Found the posting. Filled in role.")
    }

    @Test func theDetailsFooterDropsFieldsThePersonEdits() async {
        let viewModel = makeViewModel(fetchPosting: { _ in Self.growTherapy })
        await viewModel.loadPosting()

        viewModel.draft.role = "Engineering Manager"
        #expect(viewModel.detailsFooter == "Company was filled in from the posting. Edit it if it's wrong.")

        viewModel.draft.company = "Grow"
        #expect(viewModel.detailsFooter == nil)
    }

    @Test func announcesAFoundPostingThatFilledNothing() async {
        let viewModel = makeViewModel(fetchPosting: { _ in Self.growTherapy })
        viewModel.draft.company = "Grow"
        viewModel.draft.role = "EM"
        await viewModel.loadPosting()
        #expect(viewModel.linkStateAnnouncement == "Found the posting.")
        #expect(viewModel.detailsFooter == nil)
    }

    @Test func clearingTheLinkClearsWhatItFilledIn() async {
        let viewModel = makeViewModel(fetchPosting: { _ in Self.growTherapy })
        await viewModel.loadPosting()
        viewModel.draft.role = "Engineering Manager"

        viewModel.draft.link = ""
        await viewModel.loadPosting()

        #expect(viewModel.linkState == .idle)
        #expect(viewModel.detailsFooter == nil)
        #expect(viewModel.draft.company.isEmpty, "The removed link's company is cleared")
        #expect(viewModel.draft.role == "Engineering Manager", "Typed text stays")
    }

    @Test func anUnreadableReplacementLinkClearsTheEarlierPostingsValues() async {
        let fetches = FetchResults([.success(Self.growTherapy), .failure(FetchError())])
        let viewModel = makeViewModel(fetchPosting: { _ in try await fetches.next() })
        await viewModel.loadPosting()
        viewModel.draft.company = "Grow"

        viewModel.draft.link = "https://www.linkedin.com/jobs/view/4021187733"
        await viewModel.loadPosting()

        #expect(viewModel.linkState == .couldNotRead)
        #expect(viewModel.draft.company == "Grow", "Typed text stays")
        #expect(viewModel.draft.role.isEmpty, "The earlier posting's role no longer describes the link")
    }

    // MARK: Couldn't read

    @Test func aFailedFetchShowsCouldNotRead() async {
        let viewModel = makeViewModel(fetchPosting: { _ in throw FetchError() })
        await viewModel.loadPosting()

        #expect(viewModel.linkState == .couldNotRead)
        #expect(
            viewModel.linkFooter
                == "This posting couldn't be read. Fill in the company and role below. The link is still saved.")
        #expect(viewModel.linkStateAnnouncement == "Couldn't read this posting. Fill in the company and role.")
        #expect(viewModel.detailsFooter == nil)
    }

    @Test func aFailedFetchDoesNotBlockAdd() async throws {
        var saved: ApplicationDraft?
        let viewModel = makeViewModel(fetchPosting: { _ in throw FetchError() }, save: { saved = $0 })
        await viewModel.loadPosting()

        viewModel.draft.company = "Grow Therapy"
        viewModel.draft.role = "Engineering Manager"
        #expect(viewModel.canAdd)
        viewModel.add()

        let draft = try #require(saved)
        #expect(draft.trimmedLink == Self.ashbyLink, "The link is still saved")
        #expect(viewModel.shouldDismiss)
    }
}
