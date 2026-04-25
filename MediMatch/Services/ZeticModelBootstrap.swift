import Foundation

/// Pre-warms only the **Prompt Guard** and **Triage** models at launch.
///
/// The **Medical** (MedGemma) model is not prefetched here: it is loaded on
/// demand at triage **enrichment**, after the orchestrator unloads the triage
/// LLM. `TriageLLMService` and `MedicalLLMService` use `ZeticModelPeers` and
/// `ZeticLLMInitGate` so the two never construct at once and the peer is always
/// evicted before the other downloads / loads, keeping a single large LLM in
/// RAM at a time (weights for both can live on device).
///
/// Warm-up here stays sequential (Prompt Guard then Triage) to avoid ZETIC init
/// races.
public enum ZeticModelBootstrap {

    /// Pre-warms Prompt Guard + Triage only. Medical LLM is loaded on demand
    /// during triage enrichment (see `TriageOrchestrator`).
    public static func prefetchAll(
        promptGuard: PromptGuardService,
        triage: TriageLLMService
    ) async {
        await promptGuard.warmUp()
        await triage.warmUp()
    }
}
