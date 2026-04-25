import SwiftUI

struct TriageResultView: View {
    let result: TriageResult
    let highContrast: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            SeverityBadge(severity: result.severity,
                          confidence: result.severityConfidence,
                          highContrast: highContrast)

            Text(result.summary)
                .font(.system(.body, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(NSLocalizedString("a11y.summary",
                    value: "Triage summary", comment: "")))

            if !result.recommendedActions.isEmpty {
                section(title: NSLocalizedString("triage.actions",
                    value: "Recommended actions", comment: "")) {
                    ForEach(result.recommendedActions, id: \.self) { action in
                        bullet(action, icon: "checkmark.circle.fill", color: .accentColor)
                    }
                }
            }

            if !result.redFlags.isEmpty {
                section(title: NSLocalizedString("triage.redFlags",
                    value: "Red flags — seek care if these appear", comment: "")) {
                    ForEach(result.redFlags, id: \.self) { flag in
                        bullet(flag, icon: "exclamationmark.triangle.fill", color: .red)
                    }
                }
            }

            if !result.candidates.isEmpty {
                section(title: NSLocalizedString("triage.candidates",
                    value: "Possible explanations", comment: "")) {
                    ForEach(result.candidates) { candidate in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(candidate.name)
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                Spacer()
                                Text(String(format: "%d%%", Int((candidate.confidence * 100).rounded())))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            ConfidenceBar(value: candidate.confidence)
                                .frame(height: 8)
                            if !candidate.rationale.isEmpty {
                                Text(candidate.rationale)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(Theme.spacingSM)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                }
            }

            if let enrichment = result.medicalEnrichment, !enrichment.isEmpty {
                section(title: NSLocalizedString("triage.medical",
                    value: "Medication & history check", comment: "")) {
                    Text(enrichment)
                        .font(.system(.body, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Theme.spacingMD)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                }
            }

            disclaimer
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text(title)
                .font(.system(.headline, design: .rounded))
            content()
        }
    }

    private func bullet(_ text: String, icon: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text)
                .font(.system(.body, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var disclaimer: some View {
        Text(AppConfig.medicalDisclaimer)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.top, Theme.spacingSM)
    }
}
