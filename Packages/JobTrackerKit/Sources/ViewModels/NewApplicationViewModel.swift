import Domain
import Foundation
import Observation
import os

/// Drives the New Application sheet.
///
/// The view binds to `draft`. Saving and fetching postings are injected, so this type imports neither SwiftData nor
/// the networking module.
@Observable
@MainActor
public final class NewApplicationViewModel: Identifiable {
    public let id = UUID()
    public enum Alert: Equatable, Sendable {
        case discard
        case saveFailed
    }

    /// Reads the posting at a URL. Throws when the posting can't be read.
    public typealias FetchPosting = @Sendable (URL) async throws -> PostingMetadata

    public var draft: ApplicationDraft
    public var alert: Alert?
    public private(set) var shouldDismiss = false
    public private(set) var linkState: LinkState = .idle

    /// Add depends only on the draft. A fetch in flight or a failed fetch never blocks it.
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

    private let fetchPosting: FetchPosting
    private let debounce: Duration
    private let save: (ApplicationDraft) throws -> Void

    /// - Parameters:
    ///   - fetchPosting: Reads a posting. The app passes `PostingMetadataService`; tests pass a stub.
    ///   - debounce: How long the link must stay unchanged before it is fetched.
    public init(
        draft: ApplicationDraft = ApplicationDraft(),
        fetchPosting: @escaping FetchPosting,
        debounce: Duration = .milliseconds(300),
        save: @escaping (ApplicationDraft) throws -> Void
    ) {
        self.draft = draft
        self.fetchPosting = fetchPosting
        self.debounce = debounce
        self.save = save
    }

    // MARK: Posting

    /// The URL to fetch for the link field. The sheet restarts `loadPosting()` whenever it changes.
    public var postingURL: URL? { draft.postingURL }

    /// Fetches the posting at `postingURL` and fills blank fields from it.
    ///
    /// Call it from `.task(id: postingURL)`. SwiftUI cancels the task when the URL changes or the sheet closes, which
    /// both debounces typing and drops a result for a link that is no longer in the field.
    ///
    /// Filled-in values belong to the link they came from. When the link is removed or the new one can't be read,
    /// those values are cleared so they can't be saved against the wrong posting. Typed text always stays.
    public func loadPosting() async {
        linkState = .idle
        guard let url = postingURL else {
            draft.clearAutofill()
            return
        }
        do {
            try await Task.sleep(for: debounce)
        } catch {
            return
        }

        linkState = .fetching
        do {
            let metadata = try await fetchPosting(url)
            guard !Task.isCancelled else { return }
            draft.autofill(from: metadata)
            linkState = .found(metadata)
        } catch {
            guard !Task.isCancelled else { return }
            draft.clearAutofill()
            linkState = .couldNotRead
        }
    }

    /// The footer under the link field.
    public var linkFooter: String? {
        switch linkState {
        case .idle: "The company and role are filled in from the posting."
        case .fetching: "Fetching details. You can keep filling in the form."
        case .found: nil
        case .couldNotRead:
            "This posting couldn't be read. Fill in the company and role below. The link is still saved."
        }
    }

    /// The footer under Details. It names only fields that still hold the posting's values.
    public var detailsFooter: String? {
        guard case .found = linkState else { return nil }
        let fields = draft.autofilledFields
        return switch (fields.contains(.company), fields.contains(.role)) {
        case (true, true): "Company and role were filled in from the posting. Edit them if they're wrong."
        case (true, false): "Company was filled in from the posting. Edit it if it's wrong."
        case (false, true): "Role was filled in from the posting. Edit it if it's wrong."
        case (false, false): nil
        }
    }

    /// What VoiceOver announces for the current `linkState`, or `nil` when there is nothing to announce.
    public var linkStateAnnouncement: String? {
        switch linkState {
        case .idle:
            return nil
        case .fetching:
            return "Fetching job details."
        case .found:
            let fields = draft.autofilledFields
            return switch (fields.contains(.company), fields.contains(.role)) {
            case (true, true): "Found the posting. Filled in company and role."
            case (true, false): "Found the posting. Filled in company."
            case (false, true): "Found the posting. Filled in role."
            case (false, false): "Found the posting."
            }
        case .couldNotRead:
            return "Couldn't read this posting. Fill in the company and role."
        }
    }

    // MARK: Actions

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
