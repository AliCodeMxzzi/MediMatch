import Foundation

/// Holds references to the two large on-device ZETIC LLMs so each can free the
/// other before it allocates / downloads, keeping at most one of them in RAM.
///
/// Register once from `AppContainer.boot()` before any `warmUp` runs.
public enum ZeticModelPeers: Sendable {

    private static let lock = NSLock()
    private static var triage: TriageLLMService?
    private static var medical: MedicalLLMService?

    /// Wires the pair. Safe to call once at launch (mirrors the AppContainer’s ownership).
    public static func register(triage: TriageLLMService, medical: MedicalLLMService) {
        lock.lock()
        self.triage = triage
        self.medical = medical
        lock.unlock()
    }

    public static func releaseTriageForMedicalLoad() async {
        let t: TriageLLMService?
        lock.lock()
        t = triage
        lock.unlock()
        await t?.releaseFromMemory()
    }

    public static func releaseMedicalForTriageLoad() async {
        let m: MedicalLLMService?
        lock.lock()
        m = medical
        lock.unlock()
        await m?.releaseFromMemory()
    }
}
