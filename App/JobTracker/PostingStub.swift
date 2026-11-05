#if DEBUG
    import Domain
    import Foundation
    import ViewModels

    /// Canned posting results for UI tests and previews, so neither touches the network.
    enum PostingStub: String {
        /// Returns `PostingStub.metadata`.
        case found
        /// Never finishes, so the sheet stays in the fetching state until the fetch is cancelled.
        case fetching
        /// Fails, as a sign-in page or a timeout would.
        case couldNotRead

        /// The Ashby posting the unit tests read from a saved copy.
        static let metadata = PostingMetadata(
            role: "Engineering Manager, Momentum",
            company: "Grow Therapy",
            locations: ["New York"],
            isRemote: true,
            datePosted: DateComponents(calendar: .current, year: 2026, month: 7, day: 2).date
        )

        private struct Unreadable: Error {}

        /// The stub named by the `POSTING_STUB` environment variable, or `couldNotRead` when it names none.
        init(environment: [String: String]) {
            self = environment["POSTING_STUB"].flatMap(Self.init(rawValue:)) ?? .couldNotRead
        }

        var fetchPosting: NewApplicationViewModel.FetchPosting {
            switch self {
            case .found:
                return { _ in Self.metadata }
            case .fetching:
                return { _ in
                    try await Task.sleep(for: .seconds(24 * 60 * 60))
                    throw Unreadable()
                }
            case .couldNotRead:
                return { _ in throw Unreadable() }
            }
        }
    }
#endif
