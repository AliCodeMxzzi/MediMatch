import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    @EnvironmentObject private var settings: AccessibilitySettings

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(persistence: container.persistence))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.entries.isEmpty {
                    EmptyStateView(
                        icon: "clock",
                        title: NSLocalizedString("history.empty.title",
                            value: "No history yet", comment: ""),
                        message: NSLocalizedString("history.empty.message",
                            value: "Past triage sessions will appear here. They never leave your device.",
                            comment: "")
                    )
                } else {
                    List {
                        ForEach(viewModel.entries) { entry in
                            NavigationLink {
                                HistoryDetailView(entry: entry,
                                                  highContrast: settings.highContrast)
                            } label: {
                                HistoryRow(entry: entry)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(NSLocalizedString("tab.history", value: "History", comment: ""))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.entries.isEmpty {
                        Button(role: .destructive) {
                            Task { await viewModel.clear() }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel(Text(NSLocalizedString("history.clear",
                            value: "Clear history", comment: "")))
                    }
                }
            }
            .task {
                await viewModel.refresh()
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                SeverityBadge(severity: entry.result.severity, confidence: nil, highContrast: false)
                    .scaleEffect(0.85, anchor: .trailing)
            }
            Text(entry.result.summary)
                .font(.system(.body, design: .rounded))
                .lineLimit(2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct HistoryDetailView: View {
    let entry: HistoryEntry
    let highContrast: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Text(entry.date.formatted(date: .complete, time: .shortened))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.result.inputSymptoms.contains("Assistant:")
                         ? NSLocalizedString("history.detail.conversation",
                            value: "Your conversation", comment: "")
                         : NSLocalizedString("history.detail.input",
                            value: "What you reported", comment: ""))
                        .font(.system(.headline, design: .rounded))
                    Text(entry.result.inputSymptoms)
                        .font(.system(.body, design: .rounded))
                        .padding(Theme.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                }

                TriageResultView(result: entry.result, highContrast: highContrast)
            }
            .padding(Theme.spacingMD)
        }
        .navigationTitle(entry.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}
