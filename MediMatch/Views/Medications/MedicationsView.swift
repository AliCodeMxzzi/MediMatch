import SwiftUI

struct MedicationsView: View {
    @StateObject private var viewModel: MedicationsViewModel
    @State private var showingForm = false
    @State private var editing: Medication?

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: MedicationsViewModel(
            persistence: container.persistence,
            notifications: container.notifications
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                permissionBanner
                if viewModel.medications.isEmpty {
                    EmptyStateView(
                        icon: "pills.circle",
                        title: NSLocalizedString("medications.empty.title",
                            value: "No medications yet", comment: ""),
                        message: NSLocalizedString("medications.empty.message",
                            value: "Add a medication to get private, on-device reminders.", comment: "")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.medications) { med in
                            MedicationCard(
                                medication: med,
                                onToggleActive: {
                                    Task { await viewModel.toggleActive(med) }
                                },
                                onEdit: {
                                    editing = med
                                    showingForm = true
                                }
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(med) }
                                } label: {
                                    Label(NSLocalizedString("common.delete",
                                        value: "Delete", comment: ""), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(NSLocalizedString("tab.meds", value: "Medications", comment: ""))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = nil
                        showingForm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(NSLocalizedString("medications.add",
                        value: "Add medication", comment: "")))
                }
            }
            .sheet(isPresented: $showingForm) {
                MedicationFormView(
                    medication: editing,
                    onSave: { med in
                        Task {
                            await viewModel.upsert(med)
                            showingForm = false
                        }
                    },
                    onCancel: {
                        showingForm = false
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !viewModel.notificationsAuthorized {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "bell.badge").foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("medications.notifications.title",
                        value: "Reminders are off", comment: ""))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Text(NSLocalizedString("medications.notifications.message",
                        value: "Allow notifications so MediMatch can remind you to take your medications.",
                        comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(NSLocalizedString("medications.notifications.enable",
                    value: "Enable", comment: "")) {
                    Task { await viewModel.requestNotificationPermission() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(Theme.spacingMD)
            .background(Color.orange.opacity(0.10))
        }
    }
}
