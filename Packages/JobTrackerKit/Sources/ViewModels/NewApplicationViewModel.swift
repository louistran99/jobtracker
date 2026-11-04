import Domain
import Foundation
import Observation
import os

/// Drives the New Application sheet.
///
/// The view binds to `draft`. Saving is injected so this type does not import SwiftData.
@Observable
@MainActor
public final class NewApplicationViewModel: Identifiable {
    public let id = UUID()
    public enum Alert: Equatable, Sendable {
        case discard
        case saveFailed
    }

    public var draft: ApplicationDraft
    public var alert: Alert?
    public private(set) var shouldDismiss = false

    public var canAdd: Bool { draft.isValid }
    public var blocksInteractiveDismiss: Bool { draft.isDirty }

    public var alertTitle: String {
        switch alert {
        case .discard: "Discard this application?"
        case .saveFailed: "Can't Save Application"
        case nil: ""
        }
    }

    public var isPresentingAlert: Bool {
        get { alert != nil }
        set { if !newValue { alert = nil } }
    }

    private let save: (ApplicationDraft) throws -> Void

    public init(
        draft: ApplicationDraft = ApplicationDraft(),
        save: @escaping (ApplicationDraft) throws -> Void
    ) {
        self.draft = draft
        self.save = save
    }

    public func cancel() {
        if draft.isDirty {
            alert = .discard
        } else {
            shouldDismiss = true
        }
    }

    public func confirmDiscard() {
        alert = nil
        shouldDismiss = true
    }

    public func add() {
        guard canAdd else { return }
        do {
            try save(draft)
            shouldDismiss = true
        } catch {
            Logger.viewModel.error("Unable to save the application: \(error, privacy: .public)")
            alert = .saveFailed
        }
    }
}

extension Logger {
    fileprivate static let viewModel = Logger(subsystem: "com.louistran.jobtracker", category: "new-application")
}
