import Foundation

/// Builds prompts for the on-device LLMs. Kept separate from the services so
/// we can iterate on prompt copy without touching inference code.
public enum PromptTemplates {

    /// Triage prompt for `google/gemma-3n-E2B-it`.
    ///
    /// We force JSON output so the parser is deterministic. The locale tag
    /// matches the user's preferred language (best effort) so the model
    /// answers in their language when possible.
    public static func triagePrompt(symptoms: String, locale: Locale, baseSeverityHint: Severity) -> String {
        let lang = locale.language.languageCode?.identifier ?? "en"
        let hint = baseSeverityHint == .unknown ? "none" : baseSeverityHint.rawValue
        return """
        You are MediMatch, an offline triage assistant running on the user's phone.
        Goal: classify the urgency of the user's described symptoms into exactly one of:
          - "self_care"   (manageable at home)
          - "urgent_care" (see a clinician within ~24 hours)
          - "emergency"   (call emergency services / go to an ER now)

        Constraints:
        - You are NOT a doctor; never claim to diagnose.
        - Always include a short summary, 3-5 recommended actions, and any red flags.
        - List up to 4 candidate conditions with confidence in [0,1].
        - Output STRICT JSON ONLY, no prose, no markdown fences. Use this schema:

        {
          "severity": "self_care" | "urgent_care" | "emergency",
          "severity_confidence": number,
          "summary": string,
          "recommended_actions": [string],
          "red_flags": [string],
          "candidates": [
            { "name": string, "confidence": number, "rationale": string }
          ]
        }

        Output language: "\(lang)".
        Conservative-severity hint from the on-device catalog: "\(hint)".
        Symptoms reported by the user:
        ---
        \(symptoms.trimmed(maxChars: 1200))
        ---
        Respond with JSON only.
        """
    }
}

private extension String {
    func trimmed(maxChars: Int) -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxChars else { return trimmed }
        return String(trimmed.prefix(maxChars)) + "…"
    }
}
