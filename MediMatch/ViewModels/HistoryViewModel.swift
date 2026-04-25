import Foundation

@MainActor
public final class HistoryViewModel: ObservableObject {

    @Published public private(set) var entries: [HistoryEntry] = []

    private let persistence: PersistenceService

    public init(persistence: PersistenceService) {
        self.persistence = persistence
        Task { [weak self] in await self?.refresh() }
    }

    public func refresh() async {
        self.entries = await persistence.loadHistory()
    }

    public func clear() async {
        await persistence.clearHistory()
        await refresh()
    }
}
