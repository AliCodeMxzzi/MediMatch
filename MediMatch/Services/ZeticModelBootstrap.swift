import Foundation

/// Pre-warms only the **Prompt Guard** and **Triage** models at launch.
///
/// The **Medical** (MedGemma) model is **not** prefetched: even after unloading
/// Triage, initializing that 4B-class model on top of the prompt-guard graph
/// still jetsams many iPhones. MedGemma is downloaded and loaded **only** when
/// a triage run reaches the enrichment step, after we release the triage LLM
/// from RAM (`TriageOrchestrator`).
///
/// Sequential warm-up avoids concurrent ZETIC init races; see earlier crash
/// reports from parallel `ZeticMLange*Model` constructors.
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
