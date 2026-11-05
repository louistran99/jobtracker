import Foundation
import Persistence
import PostingService
import SwiftData
import ViewModels

/// Composition root. Feature services are added here as their tickets land.
@MainActor
struct AppDependencies {
    let modelContainer: ModelContainer
    let fetchPosting: NewApplicationViewModel.FetchPosting

    /// UI tests pass `-ui-testing`, so every launch starts with an empty in-memory store. In Debug builds they also
    /// pick a canned posting result with the `POSTING_STUB` environment variable, so they never touch the network.
    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws {
        let isUITesting = arguments.contains("-ui-testing")
        modelContainer = try PersistenceController.makeContainer(inMemory: isUITesting)
        #if DEBUG
            if isUITesting {
                fetchPosting = PostingStub(environment: environment).fetchPosting
                return
            }
        #endif
        let service = PostingMetadataService()
        fetchPosting = { try await service.metadata(for: $0) }
    }
}
