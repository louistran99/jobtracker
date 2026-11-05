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
            normalizedLink: draft.normalizedLink,
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

    /// When the posting with this key was last added, or `nil` if it never was.
    ///
    /// - Parameter normalizedLink: A key from `PostingLink.normalized(_:)`, such as `ApplicationDraft.normalizedLink`.
    public func dateAdded(forNormalizedLink normalizedLink: String) throws -> Date? {
        var descriptor = FetchDescriptor<Application>(
            predicate: #Predicate { $0.normalizedLink == normalizedLink },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.createdAt
    }

    /// Sets `normalizedLink` on applications saved before it existed, so `dateAdded(forNormalizedLink:)` finds them.
    ///
    /// Safe to call on every launch: once each link has its key, it fetches nothing and saves nothing.
    public func backfillNormalizedLinks() throws {
        let descriptor = FetchDescriptor<Application>(
            predicate: #Predicate { $0.link != nil && $0.normalizedLink == nil }
        )
        var changed = false
        for application in try context.fetch(descriptor) {
            guard let link = application.link, let url = PostingLink.url(from: link) else { continue }
            application.normalizedLink = PostingLink.normalized(url)
            changed = true
        }
        guard changed else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
