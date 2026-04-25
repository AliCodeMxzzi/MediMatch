import Foundation
import SwiftUI
import Combine

/// In-memory mirror of `AppPreferences` that SwiftUI can observe.
/// Loads on init; saves on every update.
@MainActor
public final class AccessibilitySettings: ObservableObject {

    @Published public var preferredLanguage: String {
        didSet { persist() }
    }
    @Published public var highContrast: Bool {
        didSet { persist() }
    }
    @Published public var largerText: Bool {
        didSet { persist() }
    }
    @Published public var voiceInputEnabled: Bool {
        didSet { persist() }
    }
    @Published public var notificationsEnabled: Bool {
        didSet { persist() }
    }

    private let persistence: PersistenceService
    private var saveTask: Task<Void, Never>?

    public init(persistence: PersistenceService, initial: AppPreferences) {
        self.persistence          = persistence
        self.preferredLanguage    = initial.preferredLanguage
        self.highContrast         = initial.highContrast
        self.largerText           = initial.largerText
        self.voiceInputEnabled    = initial.voiceInputEnabled
        self.notificationsEnabled = initial.notificationsEnabled
    }

    public var preferredLocale: Locale {
        Locale(identifier: preferredLanguage)
    }

    public var dynamicTypeBoost: DynamicTypeSize {
        largerText ? .accessibility2 : .large
    }

    private func persist() {
        let snapshot = AppPreferences(
            preferredLanguage:    preferredLanguage,
            highContrast:         highContrast,
            largerText:           largerText,
            voiceInputEnabled:    voiceInputEnabled,
            notificationsEnabled: notificationsEnabled
        )
        saveTask?.cancel()
        saveTask = Task { [persistence] in
            await persistence.savePreferences(snapshot)
        }
    }
}
