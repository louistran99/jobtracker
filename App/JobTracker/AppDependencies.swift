import Foundation
import Persistence
import PostingService
import SwiftData
import ViewModels
import os

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
        do {
            try ApplicationRepository(context: modelContainer.mainContext).backfillNormalizedLinks()
        } catch {
            // Applications saved before links had keys just aren't recognized as already added. Not worth failing
            // the launch over.
            Logger.dependencies.error("Unable to backfill link keys: \(error, privacy: .public)")
        }
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

extension Logger {
    fileprivate static let dependencies = Logger(subsystem: "com.louistran.jobtracker", category: "dependencies")
}
