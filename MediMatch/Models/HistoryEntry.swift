import Foundation

/// Local-only record of a triage session (kept on-device).
public struct HistoryEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let result: TriageResult

    public init(id: UUID = UUID(), date: Date = .init(), result: TriageResult) {
        self.id = id
        self.date = date
        self.result = result
    }
}
