import Foundation

/// The values a person has typed into the New Application sheet.
///
/// A draft is plain data. A SwiftData model is created from it only when the person taps Add, so
/// cancelling the sheet has nothing to roll back.
public struct ApplicationDraft: Equatable, Sendable {
    public var link = ""
    public var company = ""
    public var role = ""
    public var stage: Stage = .applied
    public var appliedOn: Date
    public var notes = ""
    public var hasNextStep = false
    public var nextStepTitle = ""
    public var nextStepDate: Date

    private let initialAppliedOn: Date
    private let initialNextStepDate: Date

    /// Creates an empty draft whose dates default to `today`.
    public init(today: Date = .now) {
        appliedOn = today
        nextStepDate = today
        initialAppliedOn = today
        initialNextStepDate = today
    }

    /// Company and role are required. Whitespace alone does not count.
    public var isValid: Bool {
        !trimmedCompany.isEmpty && !trimmedRole.isEmpty
    }

    /// True once any field differs from a freshly opened sheet.
    public var isDirty: Bool {
        !link.isEmpty
            || !company.isEmpty
            || !role.isEmpty
            || stage != .applied
            || appliedOn != initialAppliedOn
            || !notes.isEmpty
            || hasNextStep
            || !nextStepTitle.isEmpty
            || nextStepDate != initialNextStepDate
    }

    public var trimmedLink: String? { Self.nonBlank(link) }
    public var trimmedCompany: String { Self.trimmed(company) }
    public var trimmedRole: String { Self.trimmed(role) }
    public var trimmedNotes: String { Self.trimmed(notes) }

    /// The next step to save. It is `nil` while the toggle is off, whatever the next-step fields hold.
    public var nextStep: NextStep? {
        guard hasNextStep else { return nil }
        return NextStep(title: Self.nonBlank(nextStepTitle), date: nextStepDate)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nonBlank(_ text: String) -> String? {
        let value = trimmed(text)
        return value.isEmpty ? nil : value
    }
}

/// The follow-up a person plans after applying.
public struct NextStep: Equatable, Sendable {
    public let title: String?
    public let date: Date

    public init(title: String?, date: Date) {
        self.title = title
        self.date = date
    }
}
