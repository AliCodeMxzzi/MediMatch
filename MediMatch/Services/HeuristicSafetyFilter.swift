import Foundation

/// Fast, regex-based pre-check that runs before any model inference.
///
/// This is the always-on first layer of the `symptom_input_processing` task.
/// It catches obvious prompt-injection / jailbreak attempts and blocks empty
/// or extremely off-topic queries without spinning up the LLM.
public struct HeuristicSafetyFilter: Sendable {

    public enum Decision: Equatable, Sendable {
        case allow
        case block(reason: String)
        case warn(reason: String)
    }

    /// Patterns that strongly suggest prompt injection or attempts to
    /// override the system instructions. We match on lowercased input.
    private static let injectionPatterns: [String] = [
        #"ignore (the )?(previous|above|prior) (instructions|prompt|rules)"#,
        #"disregard (the )?(previous|above|prior) (instructions|prompt|rules)"#,
        #"forget (everything|the prompt|the system|the instructions)"#,
        #"you are now (a|an) [^.\n]{0,40}(?:hacker|jailbreak|dan|developer mode)"#,
        #"act as (a|an) [^.\n]{0,40}(?:without (any )?(restrictions|safety|limits))"#,
        #"reveal (the )?(system )?prompt"#,
        #"print (the )?(system )?prompt"#,
        #"(do anything now|jailbreak|developer mode)"#,
    ]

    /// Cues that the input is unsafe in a non-medical sense and should be
    /// refused. We do not exhaustively block; we just stop the most obvious
    /// off-task requests so we don't waste tokens on them.
    private static let abusivePatterns: [String] = [
        #"how (do|can) i (make|build) (a )?(bomb|explosive|weapon)"#,
        #"(generate|write) (a )?(virus|malware|exploit)"#,
    ]

    public init() {}

    public func evaluate(_ rawInput: String) -> Decision {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .block(reason: NSLocalizedString("guard.empty",
                value: "Please describe your symptoms.", comment: ""))
        }
        if trimmed.count > 4_000 {
            return .block(reason: NSLocalizedString("guard.tooLong",
                value: "That message is too long. Try summarizing your symptoms in under 500 words.", comment: ""))
        }
        let lower = trimmed.lowercased()

        for pattern in Self.injectionPatterns {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                return .block(reason: NSLocalizedString("guard.injection",
                    value: "MediMatch only handles medical triage. It cannot follow instructions that change its safety rules.",
                    comment: ""))
            }
        }
        for pattern in Self.abusivePatterns {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                return .block(reason: NSLocalizedString("guard.abusive",
                    value: "This app only helps with medical triage. Please rephrase your question about your symptoms.",
                    comment: ""))
            }
        }

        // Soft "non-medical" warning: if the input contains zero medical
        // vocabulary and zero symptom-catalog terms, warn the user but still
        // allow the model to handle it.
        let hasMedicalCue = lower.range(of: Self.medicalCuesRegex, options: .regularExpression) != nil
        let hasCatalogCue = SymptomCatalog.all.contains { symptom in
            let needles = [symptom.displayName.lowercased()] + symptom.synonyms.map { $0.lowercased() }
            return needles.contains { lower.contains($0) }
        }
        if !hasMedicalCue && !hasCatalogCue {
            return .warn(reason: NSLocalizedString("guard.nonMedical",
                value: "Your message doesn't look medical. Continuing, but results may be unhelpful.",
                comment: ""))
        }

        return .allow
    }

    /// Common medical-context cues. Conservative; misses are fine because
    /// catalog-term matching covers the rest.
    private static let medicalCuesRegex: String =
        #"\b(pain|hurt|ache|fever|cough|breath|chest|stomach|head|throat|nausea|vomit|dizz|tired|fatigue|rash|bleed|injur|bruise|swell|sore|sick|ill|symptom|medic|prescrib|doctor|hospital|clinic|infect|allerg|migraine|asthma|diabet|pressure|covid|flu|cold|burn|cut|wound)"#
}
