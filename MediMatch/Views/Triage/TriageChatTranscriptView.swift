import SwiftUI

struct TriageChatTranscriptView: View {
    let turns: [TriageChatTurn]
    let streamingProse: String
    let isResponding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            Text(NSLocalizedString("triage.chat.title",
                value: "Conversation",
                comment: "Triage — chat with assistant title"))
                .font(.system(.headline, design: .rounded))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(turns) { turn in
                    switch turn.role {
                    case .user:
                        userBubble(turn.text)
                    case .assistant:
                        assistantBubble(turn.text, isPartial: false)
                    }
                }
                if isResponding, !streamingProse.isEmpty,
                   turns.last?.role != .assistant {
                    assistantBubble(streamingProse, isPartial: true)
                } else if isResponding, streamingProse.isEmpty, turns.last?.role == .user {
                    HStack(alignment: .center, spacing: 8) {
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
                }
            }
        }
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 32)
            Text(text)
                .font(.system(.body, design: .rounded))
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .padding(Theme.spacingMD)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                        .fill(Color.accentColor.opacity(0.18))
                )
        }
    }

    private func assistantBubble(_ text: String, isPartial: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("triage.chat.assistantLabel",
                    value: "MediMatch",
                    comment: "Assistant name in triage chat"))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.system(.body, design: .rounded))
                    .lineSpacing(5)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
                    .opacity(isPartial ? 0.88 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.spacingMD)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            Spacer(minLength: 20)
        }
    }
}
