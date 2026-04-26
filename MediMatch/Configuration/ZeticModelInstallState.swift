import Foundation

/// Tracks whether each ZETIC model’s weights have been fully downloaded and cached
/// on device at least once, so a later `warmUp` can show "Loading" instead of
/// "Downloading" after the app was terminated (RAM empty, files still on disk).
public enum ZeticModelInstallState {
    private static let promptGuardKey = "MediMatch.zetic.weightsInstalled.promptGuard"
    /// Triage model ID changed (e.g. gemma-3n → gemma-3-4b): use a new key so
    /// "downloading" vs "loading" stays correct for the new artifact cache.
    private static let triageKey = "MediMatch.zetic.weightsInstalled.triage.gemma-3-4b-it"

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
