import Foundation
import Combine

@MainActor
public final class MedicationsViewModel: ObservableObject {

    @Published public private(set) var medications: [Medication] = []
    @Published public var notificationsAuthorized: Bool = false
    @Published public var lastError: String?

    private let persistence: PersistenceService
    private let notifications: NotificationService

    public init(persistence: PersistenceService, notifications: NotificationService) {
        self.persistence = persistence
        self.notifications = notifications
        Task { [weak self] in await self?.load() }
        Task { [weak self] in await self?.refreshAuthorization() }
    }

    public func load() async {
        let meds = await persistence.loadMedications()
        self.medications = meds.sorted { $0.startDate > $1.startDate }
    }

    public func upsert(_ medication: Medication) async {
        await persistence.upsertMedication(medication)
        await load()
        await notifications.scheduleReminders(for: medication)
    }

    public func delete(_ medication: Medication) async {
        await persistence.deleteMedication(id: medication.id)
        await notifications.cancelReminders(for: medication.id)
        await load()
    }

    public func toggleActive(_ medication: Medication) async {
        var updated = medication
        updated.isActive.toggle()
        if updated.isActive {
            await notifications.scheduleReminders(for: updated)
        } else {
            await notifications.cancelReminders(for: updated.id)
        }
        await persistence.upsertMedication(updated)
        await load()
    }

    public func requestNotificationPermission() async {
        let ok = await notifications.requestAuthorization()
        notificationsAuthorized = ok
        if !ok {
            lastError = NSLocalizedString("medications.error.notifications",
                value: "Notifications were denied. Reminders will not fire until you enable them in Settings.",
                comment: "")
        }
    }

    public func refreshAuthorization() async {
        let status = await notifications.currentAuthorization()
        notificationsAuthorized = status == .authorized || status == .provisional
    }
}
