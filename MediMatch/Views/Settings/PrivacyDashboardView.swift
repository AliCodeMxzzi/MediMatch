import SwiftUI

struct PrivacyDashboardView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showWipeConfirm = false

    var body: some View {
        List {
            Section {
                privacyHeader
            }

            Section(header: Text(NSLocalizedString("privacy.dataLocal.title",
                value: "Data stored on this device", comment: ""))) {
                row(label: NSLocalizedString("privacy.medications",
                        value: "Medications", comment: ""),
                    value: format(bytes: viewModel.storage.medicationsBytes))
                row(label: NSLocalizedString("privacy.history",
                        value: "Triage history", comment: ""),
                    value: format(bytes: viewModel.storage.historyBytes))
                row(label: NSLocalizedString("privacy.preferences",
                        value: "Preferences", comment: ""),
                    value: format(bytes: viewModel.storage.preferencesBytes))
                row(label: NSLocalizedString("privacy.total",
                        value: "Total", comment: ""),
                    value: format(bytes: viewModel.storage.totalBytes), bold: true)
            }

            Section(header: Text(NSLocalizedString("privacy.network.title",
                value: "Network usage", comment: ""))) {
                Label(NSLocalizedString("privacy.network.models",
                        value: "Model artifacts download once on first use, then run offline.",
                        comment: ""),
                      systemImage: "icloud.and.arrow.down")
                    .font(.subheadline)
                Label(NSLocalizedString("privacy.network.search",
                        value: "Map search uses Apple's MapKit local search. Your symptoms are not sent.",
                        comment: ""),
                      systemImage: "map")
                    .font(.subheadline)
                Label(NSLocalizedString("privacy.network.audio",
                        value: "Voice input uses on-device speech recognition only.",
                        comment: ""),
                      systemImage: "mic.fill")
                    .font(.subheadline)
            }

            Section(header: Text(NSLocalizedString("privacy.zetic.title",
                value: "ZETIC Melange credentials", comment: ""))) {
                row(label: NSLocalizedString("privacy.zetic.key",
                        value: "Personal key", comment: ""),
                    value: viewModel.redactedPersonalKey, monospaced: true)
                Text(NSLocalizedString("privacy.zetic.note",
                    value: "The key authenticates with the ZETIC catalog so this device can fetch your selected models. It is never logged in plain text.",
                    comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    showWipeConfirm = true
                } label: {
                    Label(NSLocalizedString("privacy.wipe",
                        value: "Erase all on-device data", comment: ""),
                          systemImage: "trash")
                }
            }
        }
        .navigationTitle(NSLocalizedString("settings.privacy",
            value: "Privacy dashboard", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refreshStorage() }
        .confirmationDialog(
            NSLocalizedString("privacy.wipe.confirm.title",
                value: "Erase all data?", comment: ""),
            isPresented: $showWipeConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task { await viewModel.wipeAllData() }
            } label: {
                Text(NSLocalizedString("privacy.wipe.confirm.action",
                    value: "Erase everything", comment: ""))
            }
            Button(NSLocalizedString("common.cancel",
                value: "Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("privacy.wipe.confirm.message",
                value: "Medications, reminders, history, and preferences will be deleted from this device.",
                comment: ""))
        }
    }

    private var privacyHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                Text(NSLocalizedString("privacy.header.title",
                    value: "Private by design", comment: ""))
                    .font(.system(.headline, design: .rounded))
            }
            Text(NSLocalizedString("privacy.header.body",
                value: "MediMatch runs all symptom analysis on your phone. No symptoms, locations, medications, or history ever leave your device.",
                comment: ""))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func row(label: String, value: String, monospaced: Bool = false, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value)
                .font(.system(.subheadline,
                              design: monospaced ? .monospaced : .default,
                              weight: bold ? .semibold : .regular))
                .foregroundStyle(.secondary)
        }
    }

    private func format(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
