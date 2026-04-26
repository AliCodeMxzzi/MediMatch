import SwiftUI

struct TriageView: View {
    private var keyboardDoneTitle: String {
        NSLocalizedString("common.keyboard.done", value: "Done", comment: "Keyboard toolbar dismiss")
    }
    @EnvironmentObject private var settings: AccessibilitySettings
    @StateObject private var viewModel: TriageViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: TriageViewModel(
            orchestrator: container.orchestrator,
            promptGuard:  container.promptGuard,
            triage:       container.triage,
            settings:     container.settings
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    SymptomInputView(viewModel: viewModel)
                    actionsRow
                    progressSection
                    if let warning = viewModel.inlineWarning {
                        warningCard(warning)
                    }
                    if case .failed(let message) = viewModel.phase {
                        failureCard(message)
                    }
                    TriageResultBottomView(
                        phase: viewModel.phase,
                        result: viewModel.lastResult,
                        highContrast: settings.highContrast
                    )
                    triagePageFooter
                    Spacer(minLength: 32)
                    Color.clear
                        .frame(minHeight: 160)
                        .contentShape(Rectangle())
                        .onTapGesture { KeyboardDismissal.endEditing() }
                }
                .padding(Theme.spacingMD)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .navigationTitle(NSLocalizedString("tab.triage", value: "Triage", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(keyboardDoneTitle) { KeyboardDismissal.endEditing() }
                }
            }
        }
    }

    private var triagePageFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppConfig.appName)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.caption)
                Text(AppConfig.appTagline)
                    .font(.system(.caption, design: .rounded))
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text(NSLocalizedString("triage.privacy.note",
                    value: "All inference runs on your device. No symptoms leave your phone.",
                    comment: ""))
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.spacingMD)
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
        .dismissesKeyboardOnTap()
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
                KeyboardDismissal.endEditing()
                viewModel.reset()
            }
        }
        .padding(Theme.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                .fill(Color.red.opacity(0.08))
        )
        .dismissesKeyboardOnTap()
    }

    private var actionsRow: some View {
        HStack(spacing: Theme.spacingMD) {
            if viewModel.isRunning {
                SecondaryButton(NSLocalizedString("triage.cancel",
                    value: "Cancel", comment: ""), systemImage: "stop.circle") {
                    KeyboardDismissal.endEditing()
                    viewModel.cancel()
                }
                PrimaryButton(NSLocalizedString("triage.thinking",
                    value: "Working…", comment: ""),
                    isLoading: true,
                    isEnabled: false) { }
            } else {
                SecondaryButton(NSLocalizedString("triage.reset",
                    value: "Clear", comment: ""), systemImage: "arrow.counterclockwise") {
                    KeyboardDismissal.endEditing()
                    viewModel.reset()
                }
                PrimaryButton(
                    NSLocalizedString("triage.submit",
                        value: "Get triage", comment: ""),
                    systemImage: "wand.and.sparkles",
                    isEnabled: viewModel.canSubmit) {
                    KeyboardDismissal.endEditing()
                    viewModel.submit()
                }
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            modelStatusRow(label: NSLocalizedString("model.guard",  value: "Prompt Guard", comment: ""), status: viewModel.promptGuardStatus)
            modelStatusRow(label: NSLocalizedString("model.triage",  value: "Triage LLM",    comment: ""), status: viewModel.triageStatus)
        }
        .padding(Theme.spacingSM)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .dismissesKeyboardOnTap()
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
        case .loading:     return "internaldrive"
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
        case .loading:     return .teal
        case .idle:        return .secondary
        }
    }

}
