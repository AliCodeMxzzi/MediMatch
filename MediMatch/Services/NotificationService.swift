import Foundation
import UserNotifications

/// Schedules local-only medication reminders. No data leaves the device.
public final class NotificationService: @unchecked Sendable {

    public init() {}

    public func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public func currentAuthorization() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Cancels any prior reminders for this medication and re-schedules
    /// based on the medication's effective hours.
    public func scheduleReminders(for medication: Medication) async {
        await cancelReminders(for: medication.id)
        guard medication.isActive else { return }

        let center = UNUserNotificationCenter.current()
        let hours = medication.schedule.effectiveHours
        for hour in hours {
            let content = UNMutableNotificationContent()
            content.title = String(
                format: NSLocalizedString("notification.title",
                    value: "Time to take %@", comment: "Medication reminder title"),
                medication.name
            )
            content.body = String(
                format: NSLocalizedString("notification.body",
                    value: "Dosage: %@", comment: "Medication reminder body"),
                medication.dosage.isEmpty ? "—" : medication.dosage
            )
            content.sound = .default
            content.threadIdentifier = "medimatch.medication.\(medication.id.uuidString)"

            var components = DateComponents()
            components.hour = hour
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = Self.identifier(for: medication.id, hour: hour)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                // Swallow scheduling errors; UI surface displays auth state separately.
            }
        }
    }

    public func cancelReminders(for medicationId: UUID) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let prefix  = "medimatch.medication.\(medicationId.uuidString)"
        let toCancel = pending
            .filter { $0.identifier.hasPrefix(prefix) }
            .map { $0.identifier }
        center.removePendingNotificationRequests(withIdentifiers: toCancel)
    }

    public func cancelAllReminders() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private static func identifier(for id: UUID, hour: Int) -> String {
        "medimatch.medication.\(id.uuidString).\(hour)"
    }
}
