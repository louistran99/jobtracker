import Foundation
import SwiftData

/// A saved job application.
///
/// Fields beyond the creation date arrive with the manual-entry ticket. The
/// model exists now so the app has a real SwiftData schema to open.
@Model
public final class Application {
    public var createdAt: Date

    public init(createdAt: Date = .now) {
        self.createdAt = createdAt
    }
}
