import Foundation

/// Sequences ZETIC model fetch so the device does not load **two large LLMs**
/// (Gemma 3n + MedGemma) in RAM at the same time, which can crash the app
/// with a jetsam / OOM exit on a physical iPhone.
///
/// Order:
/// 1. Prompt guard (small)
/// 2. Triage LLM (large) — then **release** to free memory
/// 3. Medical LLM (large) — **release**; keeps `.onDevice` (cached weights)
/// 4. Triage again — re-loads from on-disk cache; typical triage path is ready
///
/// Subsequent app launches: each `warmUp()` hits the local cache, so
/// the sequence completes quickly and does not re-download.
public enum ZeticModelBootstrap {

    public static func prefetchAll(
        promptGuard: PromptGuardService,
        triage: TriageLLMService,
        medical: MedicalLLMService
    ) async {
        await promptGuard.warmUp()

        await triage.warmUp()
        await triage.releaseFromMemory()
        // Let the OS reclaim RAM before the next large `ZeticMLangeLLMModel` init.
        try? await Task.sleep(nanoseconds: 300_000_000)

        await medical.warmUp()
        await medical.releaseFromMemory()
        try? await Task.sleep(nanoseconds: 200_000_000)

        await triage.warmUp()
    }
}
