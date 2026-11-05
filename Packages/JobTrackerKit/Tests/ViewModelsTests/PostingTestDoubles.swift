import Domain
import Foundation

/// A posting fetch the test finishes by hand, so it can inspect the view model while the fetch is in flight.
actor FetchGate {
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
actor FetchResults {
    private var results: [Result<PostingMetadata, any Error>]

    init(_ results: [Result<PostingMetadata, any Error>]) {
        self.results = results
    }

    func next() throws -> PostingMetadata {
        try results.removeFirst().get()
    }
}
