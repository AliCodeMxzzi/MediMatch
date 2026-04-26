import Foundation

/// Centralized, read-only configuration for ZETIC Melange and app metadata.
///
/// The personal key is intentionally surfaced through a single accessor so the
/// rest of the app never references it directly. We never log or print this
/// value (see `description`) and it is not persisted to disk.
public enum AppConfig {

    // MARK: - ZETIC Melange

    /// Personal key provisioned for this MediMatch project.
    ///
    /// Treat this value like a credential: never log, print, or surface it in
    /// the UI. The Settings screen exposes a redacted display only.
    fileprivate static let zeticPersonalKey: String = "dev_4c0af5ee7f3f43c8af9990d72f71a7d6"

    /// Returns the personal key for SDK use only.
    /// Restricted helper so call sites are auditable in code review.
    static func personalKeyForSDK() -> String { zeticPersonalKey }

    /// Redacted form for display in the Privacy dashboard.
    static func redactedPersonalKey() -> String {
        let key = zeticPersonalKey
        guard key.count > 8 else { return "••••" }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }

    // MARK: - Model identifiers (resolved from the prompt's catalog)

    public enum ModelID {
        /// Llama Prompt Guard — classifies user/system text for prompt
        /// injection or off-topic content. Used for both
        /// `symptom_input_processing` and `condition_mapping` checkpoints.
        public static let promptGuard = "jathin-zetic/llama_prompt_guard"

        /// Gemma 3 4B Instruct — primary triage recommender LLM.
        /// Used for `recommendation_system`.
        public static let triageRecommender = "google/gemma-3-4b-it"
    }

    // MARK: - Inference modes

    /// Triage ZETIC LLM context (smaller = less RAM on device).
    public static let triageLLMContextTokens = 4096

    /// Mapping requested by the prompt: `auto → RUN_AUTO`.
    public static let inferenceModeName = "RUN_AUTO"

    // MARK: - App metadata

    public static let appName = "MediMatch"
    public static let appTagline = "On-device healthcare triage. Private by design."

    /// The medical disclaimer shown wherever triage results are surfaced.
    public static let medicalDisclaimer =
        "MediMatch provides general guidance and is not a substitute for professional medical advice, diagnosis, or treatment. " +
        "Always seek the advice of a qualified health provider with any questions you may have regarding a medical condition. " +
        "If you think you may have a medical emergency, call your local emergency number immediately."
}
