import Foundation

/// A single line in the on-device triage chat (user or assistant text).
public struct TriageChatTurn: Identifiable, Hashable, Sendable {
    public enum Role: String, Sendable {
        case user
        case assistant
    }

    public let id: UUID
    public let role: Role
    public let text: String

    public init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }

    /// Renders a stable transcript the LLM and history screens can use.
    public static func makeTranscript(_ turns: [TriageChatTurn]) -> String {
        turns
            .map { turn in
                switch turn.role {
                case .user: return "User: \(turn.text)"
                case .assistant: return "Assistant: \(turn.text)"
                }
            }
            .joined(separator: "\n\n")
    }
}
