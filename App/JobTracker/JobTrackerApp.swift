import SwiftUI
import os

@main
struct JobTrackerApp: App {
    private let dependencies: AppDependencies?

    init() {
        do {
            dependencies = try AppDependencies()
        } catch {
            dependencies = nil
            Logger.app.error("Unable to open the application store: \(error, privacy: .public)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if let dependencies {
                ApplicationsView(fetchPosting: dependencies.fetchPosting)
                    .modelContainer(dependencies.modelContainer)
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
