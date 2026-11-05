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
    /// The value the posting wrote into each field, so a later fetch can tell its own values from typed ones.
    private var autofilledCompany: String?
    private var autofilledRole: String?

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

    /// The URL to fetch for `link`, or `nil` when the text is not a web address.
    ///
    /// A missing scheme becomes `https`, and `http` is upgraded to `https` because App Transport Security blocks
    /// plain HTTP. The host must contain a dot, so partial input such as "https://str" is not fetched.
    public var postingURL: URL? {
        guard let text = trimmedLink else { return nil }
        let withScheme = text.contains("://") ? text : "https://\(text)"
        guard var components = URLComponents(string: withScheme) else { return nil }
        switch components.scheme?.lowercased() {
        case "https", "http": components.scheme = "https"
        default: return nil
        }
        guard components.user == nil, components.password == nil,
            let host = components.host, host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".")
        else { return nil }
        return components.url
    }
    public var trimmedCompany: String { Self.trimmed(company) }
    public var trimmedRole: String { Self.trimmed(role) }
    public var trimmedNotes: String { Self.trimmed(notes) }

    /// The next step to save. It is `nil` while the toggle is off, whatever the next-step fields hold.
    public var nextStep: NextStep? {
        guard hasNextStep else { return nil }
        return NextStep(title: Self.nonBlank(nextStepTitle), date: nextStepDate)
    }

    /// Fields that still hold the value a posting filled in. Editing a field removes it from this set.
    public var autofilledFields: AutofilledFields {
        var fields: AutofilledFields = []
        if let autofilledCompany, company == autofilledCompany { fields.insert(.company) }
        if let autofilledRole, role == autofilledRole { fields.insert(.role) }
        return fields
    }

    /// Fills company and role from a fetched posting.
    ///
    /// A field is written only while it is blank or still holds an earlier posting's value, so text the person typed
    /// is never overwritten. A field still holding an earlier posting's value is cleared when this posting lacks it.
    public mutating func autofill(from metadata: PostingMetadata) {
        Self.autofill(&company, provenance: &autofilledCompany, with: metadata.company)
        Self.autofill(&role, provenance: &autofilledRole, with: metadata.role)
    }

    /// Clears fields that still hold a posting's values, for when the link they came from is gone or unreadable.
    /// Text the person typed stays.
    public mutating func clearAutofill() {
        Self.autofill(&company, provenance: &autofilledCompany, with: nil)
        Self.autofill(&role, provenance: &autofilledRole, with: nil)
    }

    private static func autofill(_ field: inout String, provenance: inout String?, with fetched: String?) {
        let holdsAutofill = provenance == field
        guard holdsAutofill || trimmed(field).isEmpty else {
            // The person typed this value, so it is theirs from now on.
            provenance = nil
            return
        }
        if let value = fetched.flatMap(nonBlank) {
            field = value
            provenance = value
        } else if holdsAutofill {
            field = ""
            provenance = nil
        }
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

/// Draft fields that can be filled in from a posting.
public struct AutofilledFields: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let company = AutofilledFields(rawValue: 1 << 0)
    public static let role = AutofilledFields(rawValue: 1 << 1)
}
