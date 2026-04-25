import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            persistence:   container.persistence,
            promptGuard:   container.promptGuard,
            triage:        container.triage,
            notifications: container.notifications
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PrivacyDashboardView(viewModel: viewModel)
                    } label: {
                        Label(NSLocalizedString("settings.privacy",
                            value: "Privacy dashboard", comment: ""),
                              systemImage: "shield.lefthalf.filled")
                    }
                    NavigationLink {
                        AccessibilitySettingsView()
                    } label: {
                        Label(NSLocalizedString("settings.accessibility",
                            value: "Accessibility", comment: ""),
                              systemImage: "figure.roll")
                    }
                    NavigationLink {
                        ModelStatusView(viewModel: viewModel)
                    } label: {
                        Label(NSLocalizedString("settings.models",
                            value: "On-device models", comment: ""),
                              systemImage: "cpu")
                    }
                }

                Section(header: Text(NSLocalizedString("settings.about",
                    value: "About", comment: ""))) {
                    HStack {
                        Image(systemName: "app.badge.checkmark")
                        Text(AppConfig.appName)
                        Spacer()
                        Text("v1.0").foregroundStyle(.secondary)
                    }
                    Text(AppConfig.appTagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text(NSLocalizedString("settings.disclaimer",
                    value: "Medical disclaimer", comment: ""))) {
                    Text(AppConfig.medicalDisclaimer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(NSLocalizedString("tab.settings", value: "Settings", comment: ""))
        }
    }
}
