import SwiftUI

struct TriageResultView: View {
    let result: TriageResult
    let highContrast: Bool
    /// When `false`, the long prose is shown in chat only; this card is severity + next steps.
    var showSummary: Bool = true

    private var displaySummary: String {
        TriageDisplayFormatting.summaryForDisplay(result.summary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "text.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(showSummary
                     ? NSLocalizedString("triage.result.title",
                        value: "Your triage result", comment: "")
                     : NSLocalizedString("triage.result.titleWithChat",
                        value: "Triage & next steps",
                        comment: "When main reply is above in chat"))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
            }
            .padding(.bottom, Theme.spacingMD)

            SeverityBadge(severity: result.severity,
                          confidence: result.severityConfidence,
                          highContrast: highContrast)
                .padding(.bottom, Theme.spacingMD)

            if showSummary {
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    Text(NSLocalizedString("triage.result.summaryLabel",
                        value: "Summary", comment: ""))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(displaySummary)
                        .font(.system(.body, design: .rounded))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text(NSLocalizedString("a11y.summary",
                            value: "Triage summary", comment: "")))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                )
                .padding(.bottom, Theme.spacingLG)
            }

            if !result.recommendedActions.isEmpty {
                sectionGroup(
                    title: NSLocalizedString("triage.result.nextSteps",
                        value: "Next steps", comment: ""),
                    symbol: "arrow.triangle.branch"
                ) {
                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        ForEach(Array(result.recommendedActions.enumerated()), id: \.offset) { index, action in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1).")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 28, alignment: .trailing)
                                Text(action)
                                    .font(.system(.body, design: .rounded))
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            if !result.redFlags.isEmpty {
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    sectionHeader(
                        NSLocalizedString("triage.redFlags",
                            value: "Red flags — seek care if these appear", comment: ""),
                        symbol: "exclamationmark.triangle.fill"
                    )
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        ForEach(result.redFlags, id: \.self) { flag in
                            actionRow(flag, icon: "exclamationmark.circle.fill", color: .red)
                        }
                    }
                }
                .padding(Theme.spacingMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                        .fill(Color.red.opacity(highContrast ? 0.2 : 0.08))
                )
                .padding(.bottom, Theme.spacingLG)
            }

            if !result.candidates.isEmpty {
                sectionGroup(
                    title: NSLocalizedString("triage.candidates",
                        value: "Possible explanations", comment: ""),
                    symbol: "list.bullet.clipboard"
                ) {
                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        ForEach(result.candidates) { candidate in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(candidate.name)
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    Spacer(minLength: 8)
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
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(Theme.spacingMD)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                                    .fill(Color(.tertiarySystemBackground))
                            )
                        }
                    }
                }
            }

            if let enrichment = result.medicalEnrichment, !enrichment.isEmpty {
                sectionGroup(
                    title: NSLocalizedString("triage.medical",
                        value: "Medication & history check", comment: ""),
                    symbol: "pills"
                ) {
                    Text(enrichment)
                        .font(.system(.body, design: .rounded))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Theme.spacingMD)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                }
            }

            disclaimer
        }
        .padding(Theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusCard, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusCard, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sectionGroup<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            sectionHeader(title, symbol: symbol)
            content()
        }
        .padding(.bottom, Theme.spacingLG)
    }

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(.headline, design: .rounded))
        }
    }

    @ViewBuilder
    private func actionRow(_ text: String, icon: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
            Text(text)
                .font(.system(.body, design: .rounded))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var disclaimer: some View {
        Text(AppConfig.medicalDisclaimer)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.top, Theme.spacingSM)
    }
}
