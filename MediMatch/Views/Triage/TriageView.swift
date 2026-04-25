import SwiftUI

struct TriageView: View {
    @EnvironmentObject private var settings: AccessibilitySettings
    @StateObject private var viewModel: TriageViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: TriageViewModel(
            orchestrator: container.orchestrator,
            promptGuard:  container.promptGuard,
            triage:       container.triage,
            medical:      container.medical,
            settings:     container.settings
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    headerCard
                    if let warning = viewModel.inlineWarning {
                        warningCard(warning)
                    }
                    SymptomInputView(viewModel: viewModel)
                    actionsRow
                    progressSection
                    streamingSection
                    if case .finished(let result) = viewModel.phase {
                        TriageResultView(result: result, highContrast: settings.highContrast)
                    }
                    if case .failed(let message) = viewModel.phase {
                        failureCard(message)
                    }
                    Spacer(minLength: 32)
                }
                .padding(Theme.spacingMD)
            }
            .background(Color(.systemBackground))
            .navigationTitle(NSLocalizedString("tab.triage", value: "Triage", comment: ""))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppConfig.appName)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(AppConfig.appTagline)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled")
                Text(NSLocalizedString("triage.privacy.note",
                    value: "All inference runs on your device. No symptoms leave your phone.",
                    comment: ""))
                    .font(.caption)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.top, 4)
        }
    }

    private func warningCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.orange)
            Text(message).font(.system(.subheadline, design: .rounded))
            Spacer(minLength: 0)
        }
        .padding(Theme.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private func failureCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                Text(NSLocalizedString("triage.failure.title",
                    value: "Triage paused", comment: ""))
                    .font(.system(.headline, design: .rounded))
            }
            Text(message)
                .font(.system(.body, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton(NSLocalizedString("triage.failure.tryAgain",
                value: "Try again", comment: "")) {
                viewModel.reset()
            }
        }
        .padding(Theme.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
    }

    private var actionsRow: some View {
        HStack(spacing: Theme.spacingMD) {
            if viewModel.isRunning {
                SecondaryButton(NSLocalizedString("triage.cancel",
                    value: "Cancel", comment: ""), systemImage: "stop.circle") {
                    viewModel.cancel()
                }
                PrimaryButton(NSLocalizedString("triage.thinking",
                    value: "Working…", comment: ""),
                    isLoading: true,
                    isEnabled: false) { }
            } else {
                SecondaryButton(NSLocalizedString("triage.reset",
                    value: "Clear", comment: ""), systemImage: "arrow.counterclockwise") {
                    viewModel.reset()
                }
                PrimaryButton(NSLocalizedString("triage.submit",
                    value: "Get triage", comment: ""),
                    systemImage: "wand.and.sparkles",
                    isEnabled: viewModel.canSubmit) {
                    viewModel.submit()
                }
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            modelStatusRow(label: NSLocalizedString("model.guard",   value: "Prompt Guard",  comment: ""), status: viewModel.promptGuardStatus)
            modelStatusRow(label: NSLocalizedString("model.triage",  value: "Triage LLM",    comment: ""), status: viewModel.triageStatus)
            modelStatusRow(label: NSLocalizedString("model.medical", value: "Medical LLM",   comment: ""), status: viewModel.medicalStatus)
        }
        .padding(Theme.spacingSM)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func modelStatusRow(label: String, status: ModelStatus) -> some View {
        HStack {
            Image(systemName: iconName(for: status))
                .foregroundStyle(color(for: status))
            Text(label).font(.system(.subheadline, design: .rounded))
            Spacer()
            Text(status.displayDescription)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func iconName(for status: ModelStatus) -> String {
        switch status {
        case .idle:        return "circle.dotted"
        case .downloading: return "arrow.down.circle"
        case .ready:       return "checkmark.seal"
        case .onDevice:    return "externaldrive.fill"
        case .running:     return "waveform"
        case .failed:      return "xmark.circle"
        }
    }

    private func color(for status: ModelStatus) -> Color {
        switch status {
        case .ready:       return .green
        case .onDevice:    return .teal
        case .running:     return .accentColor
        case .failed:      return .red
        case .downloading: return .orange
        case .idle:        return .secondary
        }
    }

    @ViewBuilder
    private var streamingSection: some View {
        switch viewModel.phase {
        case .generating, .parsing, .enriching:
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("triage.streaming.title",
                    value: "Reasoning…", comment: ""))
                    .font(.system(.headline, design: .rounded))
                ScrollView {
                    Text(viewModel.streamingText)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.spacingSM)
                }
                .frame(maxHeight: 220)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
            }
        default:
            EmptyView()
        }
    }
}
