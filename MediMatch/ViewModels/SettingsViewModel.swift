import Foundation

@MainActor
public final class SettingsViewModel: ObservableObject {

    @Published public private(set) var storage: StorageReport = .init(medicationsBytes: 0, historyBytes: 0, preferencesBytes: 0)

    @Published public var promptGuardStatus: ModelStatus = .idle
    @Published public var triageStatus:      ModelStatus = .idle
    @Published public var medicalStatus:     ModelStatus = .idle

    @Published public var promptGuardTelemetry: InferenceTelemetry = .init()
    @Published public var triageTelemetry:      InferenceTelemetry = .init()
    @Published public var medicalTelemetry:     InferenceTelemetry = .init()

    private let persistence: PersistenceService
    private let promptGuard:  PromptGuardService
    private let triage:       TriageLLMService
    private let medical:      MedicalLLMService
    private let notifications: NotificationService

    private var pollTask: Task<Void, Never>?

    public init(
        persistence: PersistenceService,
        promptGuard: PromptGuardService,
        triage: TriageLLMService,
        medical: MedicalLLMService,
        notifications: NotificationService
    ) {
        self.persistence  = persistence
        self.promptGuard  = promptGuard
        self.triage       = triage
        self.medical      = medical
        self.notifications = notifications
        Task { [weak self] in await self?.refreshStorage() }
        pollTask = Task { [weak self] in await self?.pollStatuses() }
    }

    deinit {
        pollTask?.cancel()
    }

    public var redactedPersonalKey: String { AppConfig.redactedPersonalKey() }

    public func refreshStorage() async {
        self.storage = await persistence.storageReport()
    }

    public func wipeAllData() async {
        await persistence.wipeAllData()
        await notifications.cancelAllReminders()
        await refreshStorage()
    }

    public func warmUpAllModels() {
        Task { [promptGuard, triage] in
            await ZeticModelBootstrap.prefetchAll(
                promptGuard: promptGuard,
                triage: triage
            )
        }
    }

    private func pollStatuses() async {
        while !Task.isCancelled {
            self.promptGuardStatus = await promptGuard.status
            self.triageStatus      = await triage.status
            self.medicalStatus     = await medical.status
            self.promptGuardTelemetry = await promptGuard.telemetry
            self.triageTelemetry      = await triage.telemetry
            self.medicalTelemetry     = await medical.telemetry
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}
