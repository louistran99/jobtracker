import Foundation

/// Where an application stands in the hiring pipeline.
///
/// Declaration order is the order the stage picker shows.
public enum Stage: String, CaseIterable, Codable, Identifiable, Sendable {
    case applied
    case screening
    case onsite
    case offer
    case rejected

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .applied: "Applied"
        case .screening: "Screening"
        case .onsite: "Onsite"
        case .offer: "Offer"
        case .rejected: "Rejected"
        }
    }
}
