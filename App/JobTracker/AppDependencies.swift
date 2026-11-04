import Persistence
import SwiftData

/// Composition root. Feature services are added here as their tickets land.
@MainActor
struct AppDependencies {
    let modelContainer: ModelContainer

    init(inMemory: Bool = false) throws {
        modelContainer = try PersistenceController.makeContainer(inMemory: inMemory)
    }
}
