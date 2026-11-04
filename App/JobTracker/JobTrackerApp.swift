import SwiftData
import SwiftUI
import os

@main
struct JobTrackerApp: App {
    private let modelContainer: ModelContainer?

    init() {
        do {
            // UI tests pass `-ui-testing` so every launch starts with an empty in-memory store.
            let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
            modelContainer = try AppDependencies(inMemory: isUITesting).modelContainer
        } catch {
            modelContainer = nil
            Logger.app.error("Unable to open the application store: \(error, privacy: .public)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ApplicationsView()
                    .modelContainer(modelContainer)
            } else {
                ContentUnavailableView(
                    "Can't Open Applications",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The application store could not be opened.")
                )
            }
        }
    }
}

extension Logger {
    fileprivate static let app = Logger(subsystem: "com.louistran.jobtracker", category: "app")
}
