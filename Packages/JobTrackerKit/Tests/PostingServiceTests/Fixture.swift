import Foundation
import Testing

/// Saved copies of real postings in `Fixtures/`.
enum Fixture {
    static let ashbyLink = "https://jobs.ashbyhq.com/grow-therapy/eb6b5a30-a02d-47b7-83ac-51839574d2d2"

    /// The Ashby posting for "Engineering Manager, Momentum" at Grow Therapy, saved from `ashbyLink`.
    static func ashbyPage() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "ashby-grow-therapy", withExtension: "html", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }
}
