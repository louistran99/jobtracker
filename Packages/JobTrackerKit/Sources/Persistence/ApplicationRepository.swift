import Domain
import Foundation
import SwiftData

public enum ApplicationRepositoryError: Error, Equatable {
    /// The draft is missing a company or a role.
    case invalidDraft
}

/// Saves applications. Nothing reaches the context until `add(_:)` is called.
@MainActor
public struct ApplicationRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Inserts one application built from `draft` and saves the context.
    ///
    /// If the save fails the insert is rolled back, so a retry cannot create a duplicate.
    @discardableResult
    public func add(_ draft: ApplicationDraft, createdAt: Date = .now) throws -> Application {
        guard draft.isValid else { throw ApplicationRepositoryError.invalidDraft }

        let application = Application(
            company: draft.trimmedCompany,
            role: draft.trimmedRole,
            stage: draft.stage,
            appliedOn: draft.appliedOn,
            link: draft.trimmedLink,
            notes: draft.trimmedNotes,
            nextStep: draft.nextStep,
            createdAt: createdAt
        )
        context.insert(application)
        do {
            try context.save()
        } catch {
            context.delete(application)
            throw error
        }
        return application
    }
}
