import Domain
import Foundation
import Testing

@testable import ViewModels

/// The link field when the pasted link was added before.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct NewApplicationViewModelDuplicateTests {
    private struct LookupError: Error {}

    nonisolated private static let ashbyLink =
        "https://jobs.ashbyhq.com/grow-therapy/eb6b5a30-a02d-47b7-83ac-51839574d2d2"
    nonisolated private static let growTherapy = PostingMetadata(
        role: "Engineering Manager, Momentum",
        company: "Grow Therapy"
    )
    nonisolated private static let addedOn = Date(timeIntervalSince1970: 1_699_000_000)

    private func makeViewModel(
        link: String = ashbyLink,
        debounce: Duration = .zero,
        fetchPosting: @escaping NewApplicationViewModel.FetchPosting,
        dateAdded: @escaping NewApplicationViewModel.DateAdded,
        save: @escaping (ApplicationDraft) throws -> Void = { _ in }
    ) -> NewApplicationViewModel {
        var draft = ApplicationDraft(today: Date(timeIntervalSince1970: 1_700_000_000))
        draft.link = link
        return NewApplicationViewModel(
            draft: draft,
            fetchPosting: fetchPosting,
            dateAdded: dateAdded,
            debounce: debounce,
            save: save
        )
    }

    @Test func aLinkThatWasAlreadyAddedIsNotFetched() async {
        let gate = FetchGate()
        var lookedUp: [String] = []
        let viewModel = makeViewModel(
            link: "\(Self.ashbyLink)?departmentId=8f5e4c2a",
            fetchPosting: { try await gate.fetch($0) },
            dateAdded: { key in
                lookedUp.append(key)
                return key == Self.ashbyLink ? Self.addedOn : nil
            }
        )
        await viewModel.loadPosting()

        #expect(lookedUp == [Self.ashbyLink], "The lookup uses the normalized link")
        #expect(viewModel.linkState == .duplicate(addedOn: Self.addedOn))
        #expect(await gate.requestedURLs.isEmpty, "A link that was already added is never fetched")
    }

    @Test func anAlreadyAddedLinkShowsWhenItWasAddedAndBlocksAdd() async {
        let viewModel = makeViewModel(fetchPosting: { _ in Self.growTherapy }, dateAdded: { _ in Self.addedOn })
        await viewModel.loadPosting()
        viewModel.draft.company = "Grow Therapy"
        viewModel.draft.role = "Engineering Manager"

        let date = NewApplicationViewModel.formattedDateAdded(Self.addedOn)
        #expect(viewModel.duplicateNote == "You added this on \(date)")
        #expect(viewModel.linkStateAnnouncement == "You already added this job on \(date).")
        #expect(viewModel.linkFooter == nil)
        #expect(viewModel.detailsFooter == nil)
        #expect(viewModel.draft.isValid)
        #expect(!viewModel.canAdd, "Add stays off for a link that was already added")

        var saved = false
        let blocked = makeViewModel(
            fetchPosting: { _ in Self.growTherapy },
            dateAdded: { _ in Self.addedOn },
            save: { _ in saved = true }
        )
        await blocked.loadPosting()
        blocked.draft.company = "Grow Therapy"
        blocked.draft.role = "Engineering Manager"
        blocked.add()
        #expect(!saved)
        #expect(!blocked.shouldDismiss)
    }

    @Test func replacingAnAlreadyAddedLinkEnablesAddAgain() async {
        let viewModel = makeViewModel(
            fetchPosting: { _ in Self.growTherapy },
            dateAdded: { $0 == Self.ashbyLink ? Self.addedOn : nil }
        )
        await viewModel.loadPosting()
        #expect(viewModel.linkState == .duplicate(addedOn: Self.addedOn))

        viewModel.draft.link = "https://jobs.ashbyhq.com/grow-therapy/another-posting"
        await viewModel.loadPosting()

        #expect(viewModel.linkState == .found(Self.growTherapy))
        #expect(viewModel.duplicateNote == nil)
        #expect(viewModel.canAdd)
    }

    @Test func anAlreadyAddedReplacementLinkClearsTheEarlierPostingsValues() async {
        let stripeLink = "https://stripe.com/jobs/listing/6519024"
        let viewModel = makeViewModel(
            link: stripeLink,
            fetchPosting: { _ in Self.growTherapy },
            dateAdded: { $0 == Self.ashbyLink ? Self.addedOn : nil }
        )
        await viewModel.loadPosting()
        viewModel.draft.role = "Engineering Manager"

        viewModel.draft.link = Self.ashbyLink
        await viewModel.loadPosting()

        #expect(viewModel.linkState == .duplicate(addedOn: Self.addedOn))
        #expect(viewModel.draft.company.isEmpty, "The earlier posting's company no longer describes the link")
        #expect(viewModel.draft.role == "Engineering Manager", "Typed text stays")
    }

    @Test func aFailedLookupStillFetchesThePosting() async {
        let viewModel = makeViewModel(fetchPosting: { _ in Self.growTherapy }, dateAdded: { _ in throw LookupError() })
        await viewModel.loadPosting()
        #expect(viewModel.linkState == .found(Self.growTherapy))
    }

    @Test func doesNotLookUpALinkReplacedDuringTheDebounce() async {
        var lookedUp = false
        let viewModel = makeViewModel(
            debounce: .seconds(60),
            fetchPosting: { _ in Self.growTherapy },
            dateAdded: { _ in
                lookedUp = true
                return Self.addedOn
            }
        )
        let load = Task { await viewModel.loadPosting() }
        await Task.yield()
        load.cancel()
        await load.value

        #expect(viewModel.linkState == .idle)
        #expect(!lookedUp)
    }

    @Test func theDateAddedShowsTheYearOnlyWhenItIsNotThisYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let locale = Locale(identifier: "en_US")
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 9)))
        let thisYear = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 23)))
        let lastYear = try #require(calendar.date(from: DateComponents(year: 2025, month: 12, day: 30)))

        let format = { (date: Date) in
            NewApplicationViewModel.formattedDateAdded(date, now: now, calendar: calendar, locale: locale)
        }
        #expect(format(thisYear) == "Oct 12")
        #expect(format(lastYear) == "Dec 30, 2025")
    }
}
