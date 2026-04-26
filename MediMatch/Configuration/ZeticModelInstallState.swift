import Foundation

/// Tracks whether each ZETIC model’s weights have been fully downloaded and cached
/// on device at least once, so a later `warmUp` can show "Loading" instead of
/// "Downloading" after the app was terminated (RAM empty, files still on disk).
public enum ZeticModelInstallState {
    private static let promptGuardKey = "MediMatch.zetic.weightsInstalled.promptGuard"
    /// Per-model key so switching `triageRecommender` in `AppConfig` does not
    /// reuse the wrong "already cached" flag for a different artifact.
    private static let triageKey = "MediMatch.zetic.weightsInstalled.triage.gemma-3n-E2B-it"

    public static func hasPromptGuardWeightsInstalled() -> Bool {
        UserDefaults.standard.bool(forKey: promptGuardKey)
    }

    public static func hasTriageWeightsInstalled() -> Bool {
        UserDefaults.standard.bool(forKey: triageKey)
    }

    public static func markPromptGuardWeightsInstalled() {
        UserDefaults.standard.set(true, forKey: promptGuardKey)
    }

    public static func markTriageWeightsInstalled() {
        UserDefaults.standard.set(true, forKey: triageKey)
    }

    public static func markPromptGuardWeightsCleared() {
        UserDefaults.standard.set(false, forKey: promptGuardKey)
    }

    public static func markTriageWeightsCleared() {
        UserDefaults.standard.set(false, forKey: triageKey)
    }
}
