import Foundation
import SwiftData

public enum PersistenceController {
    /// Creates the app's SwiftData store.
    ///
    /// CloudKit stays off until a ticket asks for sync. Tests pass `inMemory`
    /// so they never touch the on-disk store.
    @MainActor
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Application.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
