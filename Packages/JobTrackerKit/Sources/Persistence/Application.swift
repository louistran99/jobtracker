import Domain
import Foundation
import SwiftData

/// A saved job application.
///
/// Every stored property has a default so an existing store opens with a lightweight migration.
@Model
public final class Application {
    #Index<Application>([\.normalizedLink])

    public var company: String = ""
    public var role: String = ""
    /// The raw value of a `Stage`. Read and write it through `stage`.
    public var stageRawValue: String = Stage.applied.rawValue
    public var appliedOn: Date = Date.now
    /// The link as the person entered it, trimmed.
    public var link: String?
    /// The key that identifies the posting `link` points to, from `PostingLink.normalized(_:)`. Used to find a
    /// posting that was already added.
    public var normalizedLink: String?
    public var notes: String = ""
    public var nextStepTitle: String?
    public var nextStepDate: Date?
    public var createdAt: Date = Date.now

    public var stage: Stage {
        get { Stage(rawValue: stageRawValue) ?? .applied }
        set { stageRawValue = newValue.rawValue }
    }

    public init(
        company: String = "",
        role: String = "",
        stage: Stage = .applied,
        appliedOn: Date = .now,
        link: String? = nil,
        normalizedLink: String? = nil,
        notes: String = "",
        nextStep: NextStep? = nil,
        createdAt: Date = .now
    ) {
        self.company = company
        self.role = role
        self.stageRawValue = stage.rawValue
        self.appliedOn = appliedOn
        self.link = link
        self.normalizedLink = normalizedLink
        self.notes = notes
        self.nextStepTitle = nextStep?.title
        self.nextStepDate = nextStep?.date
        self.createdAt = createdAt
    }
}
