import Foundation

/// A single canonical symptom available from the on-device catalog.
public struct Symptom: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let synonyms: [String]
    public let baseSeverity: Severity
    public let body: BodySystem

    public init(
        id: String,
        displayName: String,
        synonyms: [String],
        baseSeverity: Severity,
        body: BodySystem
    ) {
        self.id = id
        self.displayName = displayName
        self.synonyms = synonyms
        self.baseSeverity = baseSeverity
        self.body = body
    }

    public enum BodySystem: String, Codable, CaseIterable, Sendable {
        case general
        case head
        case respiratory
        case cardiovascular
        case gastrointestinal
        case musculoskeletal
        case skin
        case neurological
        case mentalHealth

        public var displayName: String {
            switch self {
            case .general:          return NSLocalizedString("body.general",          value: "General",          comment: "")
            case .head:             return NSLocalizedString("body.head",             value: "Head & ENT",       comment: "")
            case .respiratory:      return NSLocalizedString("body.respiratory",      value: "Respiratory",      comment: "")
            case .cardiovascular:   return NSLocalizedString("body.cardiovascular",   value: "Heart",            comment: "")
            case .gastrointestinal: return NSLocalizedString("body.gastrointestinal", value: "Stomach & gut",    comment: "")
            case .musculoskeletal:  return NSLocalizedString("body.musculoskeletal",  value: "Muscles & joints", comment: "")
            case .skin:             return NSLocalizedString("body.skin",             value: "Skin",             comment: "")
            case .neurological:     return NSLocalizedString("body.neurological",     value: "Neurological",     comment: "")
            case .mentalHealth:     return NSLocalizedString("body.mentalHealth",     value: "Mental health",    comment: "")
            }
        }
    }
}
