import SwiftUI

struct TriageChatTranscriptView: View {
    let turns: [TriageChatTurn]
    let streamingProse: String
    let isResponding: Bool
    /// Shown in the same card as the latest completed assistant reply (not a second screen area).
    let structuredResult: TriageResult?
    let highContrast: Bool

    private var lastAssistantIndex: Int? {
        turns.enumerated().reversed().first { $0.element.role == .assistant }?.offset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "text.bubble.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(NSLocalizedString("triage.chat.title",
                        value: "Your triage",
                        comment: "Triage — single unified result area title"))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text(NSLocalizedString("triage.chat.subtitle",
                        value: "One response: guidance, most likely explanations, and next steps.",
                        comment: "Triage single-pass subtitle"))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                ForEach(Array(turns.enumerated()), id: \.element.id) { index, turn in
                    switch turn.role {
                    case .user:
                        userBubble(turn.text)
                    case .assistant:
                        let showAddOn = shouldShowStructuredAddOn(forAssistantAt: index)
                        assistantBubble(turn.text, isPartial: false, structured: showAddOn ? structuredResult : nil)
                    }
                }
                if isResponding, !streamingProse.isEmpty,
                   turns.last?.role != .assistant {
                    assistantBubble(streamingProse, isPartial: true, structured: nil)
                } else if isResponding, streamingProse.isEmpty, turns.last?.role == .user {
                    HStack(alignment: .center, spacing: 10) {
                        ProgressView()
                            .tint(.accentColor)
                        Text(NSLocalizedString("triage.chat.thinking",
                            value: "Composing a reply…",
                            comment: ""))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.spacingMD)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                            .fill(Color(.tertiarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 0.5)
                    )
                }
            }

            if hasAnyAssistant {
                Text(AppConfig.medicalDisclaimer)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.spacingMD)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                            .fill(Color(.tertiarySystemBackground).opacity(0.65))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.25), lineWidth: 0.5)
                    )
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

    private var hasAnyAssistant: Bool {
        turns.contains { $0.role == .assistant }
    }

    private func shouldShowStructuredAddOn(forAssistantAt index: Int) -> Bool {
        guard !isResponding, structuredResult != nil, let li = lastAssistantIndex else { return false }
        return index == li
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 28)
            Text(text)
                .font(.system(.body, design: .rounded))
                .lineSpacing(5)
                .foregroundStyle(.primary)
                .padding(.horizontal, Theme.spacingMD)
                .padding(.vertical, Theme.spacingMD - 2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusCard, style: .continuous)
                        .fill(Color.accentColor.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusCard, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 0.5)
                )
        }
    }

    private func assistantBubble(_ text: String, isPartial: Bool, structured: TriageResult?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("triage.chat.assistantLabel",
                    value: "MediMatch",
                    comment: "Assistant name in triage chat"))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.system(.body, design: .rounded))
                    .lineSpacing(6)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .opacity(isPartial ? 0.9 : 1)

                if let r = structured {
                    TriageInChatStructuredAddOn(result: r, highContrast: highContrast)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusCard, style: .continuous)
                    .fill(Color(.tertiarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusCard, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
            )
            Spacer(minLength: 16)
        }
    }
}

// MARK: - Single-place severity + next steps (inside the assistant card)

private struct TriageInChatStructuredAddOn: View {
    let result: TriageResult
    let highContrast: Bool

    private var uniqueActions: [String] {
        TriageInChatStructuredAddOn.dedupe(result.recommendedActions, max: 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            Divider()
                .background(Color(.separator).opacity(0.6))

            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("triage.inChat.severityLabel",
                    value: "Triage level",
                    comment: "Label above severity badge in chat"))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                SeverityBadge(
                    severity: result.severity,
                    confidence: result.severityConfidence,
                    highContrast: highContrast
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !uniqueActions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("triage.inChat.nextSteps",
                        value: "Practical next steps",
                        comment: "Heading inside chat card"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(uniqueActions.enumerated()), id: \.offset) { n, line in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(n + 1).")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(Color.accentColor)
                                    .frame(minWidth: 22, alignment: .trailing)
                                Text(line)
                                    .font(.system(.body, design: .rounded))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.spacingMD)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.22), lineWidth: 0.5)
                )
            }
            if !result.candidates.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("triage.candidates",
                        value: "Possible explanations", comment: ""))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
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
            if !result.redFlags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("triage.inChat.redFlags",
                        value: "Seek care urgently if",
                        comment: "Compact red flags in chat"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(result.redFlags.prefix(3).enumerated()), id: \.offset) { _, flag in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Color.red)
                            Text(flag)
                                .font(.system(.body, design: .rounded))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(Theme.spacingMD)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                        .fill(Color.red.opacity(highContrast ? 0.18 : 0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.25), lineWidth: 0.5)
                )
            }
        }
    }

    private static func dedupe(_ lines: [String], max: Int) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            let k = t.lowercased()
            if seen.insert(k).inserted {
                out.append(t)
            }
            if out.count >= max { break }
        }
        return out
    }
}
