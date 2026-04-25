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

    /// Medical enrichment prompt for `Steve/Medgemma-1.5-4b-it`.
    ///
    /// Used to summarize the user's local data (active medications, recent
    /// triage history) in plain language and to flag potential drug-symptom
    /// interactions. Output is plain text shown to the user.
    public static func medicalEnrichmentPrompt(
        symptoms: String,
        triageSummary: String,
        activeMedications: [Medication],
        locale: Locale
    ) -> String {
        let lang = locale.language.languageCode?.identifier ?? "en"
        let medsBlock: String
        if activeMedications.isEmpty {
            medsBlock = "(none recorded)"
        } else {
            medsBlock = activeMedications
                .map { "- \($0.name) \($0.dosage), \($0.schedule.cadence.displayName)" }
                .joined(separator: "\n")
        }

        return """
        You are a medical-domain assistant running on the user's phone.
        The user has just received a triage assessment. Your job is to:

        1. Summarize, in 2-3 sentences, anything the user should be careful about
           given their currently active medications.
        2. Mention any plausible interactions or contraindications between the
           reported symptoms and these medications.
        3. Be cautious. Never recommend stopping a medication. Always defer to
           a licensed clinician.

        Output: 2-4 short paragraphs, plain text, no markdown, no JSON.
        Output language: "\(lang)".

        Reported symptoms:
        \(symptoms.trimmed(maxChars: 600))

        Triage summary:
        \(triageSummary.trimmed(maxChars: 600))

        Active medications:
        \(medsBlock)
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
