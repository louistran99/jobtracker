import Foundation
import SwiftData
import Testing
@testable import Persistence

@MainActor
struct PersistenceControllerTests {
    @Test func inMemoryContainerPersistsAnApplication() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(Application(createdAt: createdAt))
        try context.save()

        let stored = try context.fetch(FetchDescriptor<Application>())
        #expect(stored.count == 1)
        #expect(stored.first?.createdAt == createdAt)
    }
}
