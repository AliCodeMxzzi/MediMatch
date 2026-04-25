import SwiftUI

struct AccessibilitySettingsView: View {
    @EnvironmentObject private var settings: AccessibilitySettings

    private static let supportedLanguages: [(code: String, name: String)] = [
        ("en", NSLocalizedString("language.en", value: "English", comment: "")),
        ("es", NSLocalizedString("language.es", value: "Español", comment: "")),
        ("fr", NSLocalizedString("language.fr", value: "Français", comment: "")),
    ]

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("a11y.section.display",
                value: "Display", comment: ""))) {
                Toggle(NSLocalizedString("a11y.largerText",
                    value: "Larger text", comment: ""),
                       isOn: $settings.largerText)
                Toggle(NSLocalizedString("a11y.highContrast",
                    value: "High contrast severity colors", comment: ""),
                       isOn: $settings.highContrast)
            }

            Section(header: Text(NSLocalizedString("a11y.section.input",
                value: "Input", comment: ""))) {
                Toggle(NSLocalizedString("a11y.voiceInput",
                    value: "Voice symptom input", comment: ""),
                       isOn: $settings.voiceInputEnabled)
                Text(NSLocalizedString("a11y.voiceInput.note",
                    value: "Uses Apple's on-device speech recognizer. Audio never leaves your phone.",
                    comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text(NSLocalizedString("a11y.section.notifications",
                value: "Notifications", comment: ""))) {
                Toggle(NSLocalizedString("a11y.notifications",
                    value: "Medication reminders", comment: ""),
                       isOn: $settings.notificationsEnabled)
                if !settings.notificationsEnabled {
                    Text(NSLocalizedString("a11y.notifications.disabled",
                        value: "Reminder notifications will not be scheduled while this is off.",
                        comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text(NSLocalizedString("a11y.section.language",
                value: "Language", comment: ""))) {
                Picker(NSLocalizedString("a11y.language",
                    value: "App language", comment: ""),
                       selection: $settings.preferredLanguage) {
                    ForEach(Self.supportedLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                Text(NSLocalizedString("a11y.language.note",
                    value: "Triage prompts are sent to the on-device LLM in the chosen language.",
                    comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text(NSLocalizedString("a11y.section.screenreader",
                value: "Screen reader", comment: ""))) {
                Label(NSLocalizedString("a11y.vo.note",
                    value: "MediMatch supports VoiceOver, Dynamic Type, and Smart Invert.",
                    comment: ""),
                      systemImage: "rectangle.and.text.magnifyingglass")
                    .font(.subheadline)
            }
        }
        .navigationTitle(NSLocalizedString("settings.accessibility",
            value: "Accessibility", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}
