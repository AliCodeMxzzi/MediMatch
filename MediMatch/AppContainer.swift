import Foundation
import SwiftUI

/// Single source of truth for app-wide services.
///
/// Constructed once at launch in `MediMatchApp` and exposed via
/// `@EnvironmentObject`. Holds all actor-isolated services and the
/// orchestrator that wires them together.
@MainActor
public final class AppContainer: ObservableObject {

    public let persistence:  PersistenceService
    public let promptGuard:  PromptGuardService
    public let triage:       TriageLLMService
    public let medical:      MedicalLLMService
    public let orchestrator: TriageOrchestrator

    public let location:     LocationService
    public let clinicFinder: ClinicFinder
    public let notifications: NotificationService
    public let speech:       SpeechRecognitionService
    public let settings:     AccessibilitySettings

    private init(
        persistence:   PersistenceService,
        promptGuard:   PromptGuardService,
        triage:        TriageLLMService,
        medical:       MedicalLLMService,
        orchestrator:  TriageOrchestrator,
        location:      LocationService,
        clinicFinder:  ClinicFinder,
        notifications: NotificationService,
        speech:        SpeechRecognitionService,
        settings:      AccessibilitySettings
    ) {
        self.persistence   = persistence
        self.promptGuard   = promptGuard
        self.triage        = triage
        self.medical       = medical
        self.orchestrator  = orchestrator
        self.location      = location
        self.clinicFinder  = clinicFinder
        self.notifications = notifications
        self.speech        = speech
        self.settings      = settings
    }

    @MainActor
    public static func boot() -> AppContainer {
        let persistence: PersistenceService
        do {
            persistence = try PersistenceService()
        } catch {
            // On iOS the app sandbox should always allow Application Support
            // creation. Crash fast so we don't silently lose user data.
            preconditionFailure("Failed to initialize persistence: \(error)")
        }

        let promptGuard = PromptGuardService()
        let triage      = TriageLLMService()
        let medical     = MedicalLLMService()
        let orchestrator = TriageOrchestrator(
            promptGuard: promptGuard,
            triageLLM:   triage,
            medicalLLM:  medical,
            persistence: persistence
        )

        let settings = AccessibilitySettings(persistence: persistence, initial: .default)

        let container = AppContainer(
            persistence:   persistence,
            promptGuard:   promptGuard,
            triage:        triage,
            medical:       medical,
            orchestrator:  orchestrator,
            location:      LocationService(),
            clinicFinder:  ClinicFinder(),
            notifications: NotificationService(),
            speech:        SpeechRecognitionService(),
            settings:      settings
        )

        // Asynchronously hydrate user preferences (post-launch).
        Task { @MainActor [persistence, settings] in
            let stored = await persistence.loadPreferences()
            settings.preferredLanguage    = stored.preferredLanguage
            settings.highContrast         = stored.highContrast
            settings.largerText           = stored.largerText
            settings.voiceInputEnabled    = stored.voiceInputEnabled
            settings.notificationsEnabled = stored.notificationsEnabled
        }

        return container
    }

    /// Warm up all three on-device models. Network is only used to fetch the
    /// model artifacts the first time; afterwards everything runs offline.
    ///
    /// Important: warm-ups run **sequentially**. The ZETIC SDK statically
    /// links a C++ inference engine (`ggml`) whose model registry, file-handle
    /// pool, and downloader state are not safe to mutate from multiple Swift
    /// tasks at once. Three concurrent `ZeticMLangeModel(...)` constructors
    /// produced a SIGSEGV at first launch (see crash report dated 2026-04-25
    /// where two cooperative-pool tasks raced through `fread` / ggml init and
    /// dereferenced a pointer whose bytes were ASCII string data). Doing one
    /// at a time costs us a few seconds of background work but eliminates the
    /// race entirely.
    public func warmUpModelsInBackground() {
        let pg = promptGuard
        let tr = triage
        let md = medical
        Task.detached(priority: .utility) {
            // Give SwiftUI a moment to draw the first frame before we start
            // hammering the SDK. Not strictly necessary, but it keeps the UI
            // smooth on cold launch.
            try? await Task.sleep(nanoseconds: 250_000_000)

            await pg.warmUp()
            await tr.warmUp()
            await md.warmUp()
        }
    }
}

