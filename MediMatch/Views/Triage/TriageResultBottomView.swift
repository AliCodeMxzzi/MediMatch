import SwiftUI

/// Single result region at the **bottom** of the Triage tab: a loading state while
/// the model runs, then one structured `TriageResultView` (no raw token streaming).
struct TriageResultBottomView: View {
    let phase: TriageViewModel.Phase
    let result: TriageResult?
    let highContrast: Bool

    @ViewBuilder
    var body: some View {
        if isInFlight {
            inFlightResultCard
        } else if let r = result, isFinished {
            TriageResultView(result: r, highContrast: highContrast, showSummary: true)
        }
    }

    private var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    private var isInFlight: Bool {
        switch phase {
        case .validating, .classifying, .generating, .parsing: return true
        default: return false
        }
    }

    private var inFlightResultCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "text.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                Text(NSLocalizedString("triage.result.title",
                    value: "Your triage result", comment: ""))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
            }

            HStack(alignment: .firstTextBaseline, spacing: Theme.spacingMD) {
                ProgressView()
                    .tint(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("triage.bottom.preparing",
                        value: "Preparing your result…",
                        comment: ""))
                        .font(.system(.headline, design: .rounded))
                    Text(detailMessage)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusCard, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusCard, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.32), lineWidth: 1)
        )
    }

    private var detailMessage: String {
        switch phase {
        case .validating:
            return NSLocalizedString("triage.progress.subtitle.validating",
                value: "Checking that we can help with what you shared.",
                comment: "")
        case .classifying:
            return NSLocalizedString("triage.progress.subtitle.classifying",
                value: "Running a quick safety check on your text.",
                comment: "")
        case .generating:
            return NSLocalizedString("triage.progress.subtitle.generating",
                value: "Turning your symptoms into clear, plain-language advice.",
                comment: "")
        case .parsing:
            return NSLocalizedString("triage.progress.subtitle.parsing",
                value: "Preparing the structured triage and next steps for you.",
                comment: "")
        default:
            return ""
        }
    }
}
