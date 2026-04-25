import Foundation

/// Triage severity buckets from the project spec:
/// "self-care, urgent care, or emergency room".
public enum Severity: String, Codable, CaseIterable, Sendable {
    case selfCare    = "self_care"
    case urgentCare  = "urgent_care"
    case emergency   = "emergency"
    case unknown     = "unknown"

    public var displayName: String {
        switch self {
        case .selfCare:   return NSLocalizedString("severity.selfCare", value: "Self-care", comment: "Severity label")
        case .urgentCare: return NSLocalizedString("severity.urgentCare", value: "Urgent care", comment: "Severity label")
        case .emergency:  return NSLocalizedString("severity.emergency", value: "Emergency", comment: "Severity label")
        case .unknown:    return NSLocalizedString("severity.unknown", value: "Unclear", comment: "Severity label")
        }
    }

    public var shortGuidance: String {
        switch self {
        case .selfCare:
            return NSLocalizedString("severity.selfCare.guidance",
                value: "You can likely manage this at home. Monitor your symptoms.",
                comment: "Severity guidance")
        case .urgentCare:
            return NSLocalizedString("severity.urgentCare.guidance",
                value: "Consider seeing a clinician within the next 24 hours.",
                comment: "Severity guidance")
        case .emergency:
            return NSLocalizedString("severity.emergency.guidance",
                value: "Seek emergency care immediately or call your local emergency number.",
                comment: "Severity guidance")
        case .unknown:
            return NSLocalizedString("severity.unknown.guidance",
                value: "We could not determine severity. When in doubt, contact a clinician.",
                comment: "Severity guidance")
        }
    }
}
