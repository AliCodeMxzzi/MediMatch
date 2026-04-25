import Foundation

/// A possible condition surfaced by the triage LLM with a confidence score in [0, 1].
public struct CandidateCondition: Codable, Hashable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let confidence: Double
    public let rationale: String
}

/// The structured output we expect from the triage LLM.
public struct TriageResult: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let inputSymptoms: String
    public let severity: Severity
    public let severityConfidence: Double
    public let summary: String
    public let recommendedActions: [String]
    public let redFlags: [String]
    public let candidates: [CandidateCondition]
    public let medicalEnrichment: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = .init(),
        inputSymptoms: String,
        severity: Severity,
        severityConfidence: Double,
        summary: String,
        recommendedActions: [String],
        redFlags: [String],
        candidates: [CandidateCondition],
        medicalEnrichment: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.inputSymptoms = inputSymptoms
        self.severity = severity
        self.severityConfidence = severityConfidence
        self.summary = summary
        self.recommendedActions = recommendedActions
        self.redFlags = redFlags
        self.candidates = candidates
        self.medicalEnrichment = medicalEnrichment
    }
}

public extension TriageResult {
    /// Fallback used when guardrail blocks the input or model output is unparseable.
    static func unparseable(input: String, message: String) -> TriageResult {
        TriageResult(
            inputSymptoms: input,
            severity: .unknown,
            severityConfidence: 0,
            summary: message,
            recommendedActions: [
                NSLocalizedString("triage.fallback.action.consult",
                    value: "Consult a licensed clinician.",
                    comment: ""),
                NSLocalizedString("triage.fallback.action.emergency",
                    value: "If this is an emergency, call your local emergency number now.",
                    comment: "")
            ],
            redFlags: [],
            candidates: []
        )
    }
}
