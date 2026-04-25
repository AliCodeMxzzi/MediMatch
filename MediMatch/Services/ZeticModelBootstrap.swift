import Foundation

/// Pre-warms the **Prompt Guard** and **Triage** models at launch (or from Settings).
///
/// Warm-up runs sequentially (Prompt Guard then Triage) to avoid ZETIC init races.
public enum ZeticModelBootstrap {

    public static func prefetchAll(
        promptGuard: PromptGuardService,
        triage: TriageLLMService
    ) async {
        await promptGuard.warmUp()
        await triage.warmUp()
    }
}
