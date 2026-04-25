import SwiftUI

struct ModelStatusView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            Section(header: Text(NSLocalizedString("models.section.routing",
                value: "Routing", comment: ""))) {
                routingRow(
                    task: NSLocalizedString("models.task.input",
                        value: "Input safety", comment: ""),
                    model: AppConfig.ModelID.promptGuard,
                    purpose: NSLocalizedString("models.purpose.input",
                        value: "symptom_input_processing", comment: "")
                )
                routingRow(
                    task: NSLocalizedString("models.task.output",
                        value: "Output safety", comment: ""),
                    model: AppConfig.ModelID.promptGuard,
                    purpose: NSLocalizedString("models.purpose.output",
                        value: "condition_mapping", comment: "")
                )
                routingRow(
                    task: NSLocalizedString("models.task.recommend",
                        value: "Triage recommendation", comment: ""),
                    model: AppConfig.ModelID.triageRecommender,
                    purpose: NSLocalizedString("models.purpose.recommend",
                        value: "recommendation_system", comment: "")
                )
                routingRow(
                    task: NSLocalizedString("models.task.medical",
                        value: "Medication & history check", comment: ""),
                    model: AppConfig.ModelID.medicalAssistant,
                    purpose: NSLocalizedString("models.purpose.medical",
                        value: "local_data_management", comment: "")
                )
            }

            Section(header: Text(NSLocalizedString("models.section.status",
                value: "Status", comment: ""))) {
                statusRow(
                    name: NSLocalizedString("model.guard", value: "Prompt Guard", comment: ""),
                    status: viewModel.promptGuardStatus,
                    telemetry: viewModel.promptGuardTelemetry
                )
                statusRow(
                    name: NSLocalizedString("model.triage", value: "Triage LLM", comment: ""),
                    status: viewModel.triageStatus,
                    telemetry: viewModel.triageTelemetry
                )
                statusRow(
                    name: NSLocalizedString("model.medical", value: "Medical LLM", comment: ""),
                    status: viewModel.medicalStatus,
                    telemetry: viewModel.medicalTelemetry
                )
            }

            Section {
                Button {
                    viewModel.warmUpAllModels()
                } label: {
                    Label(NSLocalizedString("models.warmUp",
                        value: "Pre-download all models", comment: ""),
                          systemImage: "arrow.down.circle")
                }
            } footer: {
                Text(NSLocalizedString("models.warmUp.note",
                    value: "Models are fetched from ZETIC Melange the first time they're used. After that, all inference happens offline.",
                    comment: ""))
            }

            Section(header: Text(NSLocalizedString("models.section.mode",
                value: "Inference mode", comment: ""))) {
                row(label: NSLocalizedString("models.mode",
                        value: "ModelMode", comment: ""),
                    value: AppConfig.inferenceModeName)
                row(label: NSLocalizedString("models.runtime",
                        value: "Runtime", comment: ""),
                    value: "ZeticMLange iOS 1.6+")
            }
        }
        .navigationTitle(NSLocalizedString("settings.models",
            value: "On-device models", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func routingRow(task: String, model: String, purpose: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(task).font(.system(.subheadline, design: .rounded, weight: .semibold))
            Text(model).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
            Text(purpose).font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func statusRow(name: String, status: ModelStatus, telemetry: InferenceTelemetry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                Text(status.displayDescription)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(color(for: status))
            }
            HStack(spacing: 16) {
                stat(label: NSLocalizedString("models.calls",
                    value: "Calls", comment: ""), value: "\(telemetry.totalCalls)")
                stat(label: NSLocalizedString("models.lastLatency",
                    value: "Last latency", comment: ""), value: "\(telemetry.lastLatencyMillis) ms")
            }
            if let err = telemetry.lastError {
                Text(err).font(.caption2).foregroundStyle(.red).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func stat(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(.caption, design: .monospaced))
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.system(.subheadline, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func color(for status: ModelStatus) -> Color {
        switch status {
        case .ready:       return .green
        case .running:     return .accentColor
        case .failed:      return .red
        case .downloading: return .orange
        case .idle:        return .secondary
        }
    }
}
