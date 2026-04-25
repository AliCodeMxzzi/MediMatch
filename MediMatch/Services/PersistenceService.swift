import Foundation

/// Local-only persistence layer. Uses `FileManager` JSON files stored in the
/// app's sandboxed Application Support directory. Nothing is uploaded.
public actor PersistenceService {

    private let baseURL: URL
    private let medsURL: URL
    private let historyURL: URL
    private let prefsURL: URL

    public init() throws {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
        let dir = appSupport.appendingPathComponent("MediMatch", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.baseURL = dir
        self.medsURL    = dir.appendingPathComponent("medications.json")
        self.historyURL = dir.appendingPathComponent("history.json")
        self.prefsURL   = dir.appendingPathComponent("preferences.json")
    }

    // MARK: - Medications

    public func loadMedications() -> [Medication] {
        decode([Medication].self, from: medsURL) ?? []
    }

    public func saveMedications(_ meds: [Medication]) {
        encode(meds, to: medsURL)
    }

    public func activeMedications() -> [Medication] {
        loadMedications().filter { $0.isActive }
    }

    public func upsertMedication(_ med: Medication) {
        var current = loadMedications()
        if let idx = current.firstIndex(where: { $0.id == med.id }) {
            current[idx] = med
        } else {
            current.append(med)
        }
        saveMedications(current)
    }

    public func deleteMedication(id: UUID) {
        let updated = loadMedications().filter { $0.id != id }
        saveMedications(updated)
    }

    // MARK: - History

    public func loadHistory() -> [HistoryEntry] {
        decode([HistoryEntry].self, from: historyURL) ?? []
    }

    public func appendHistory(_ entry: HistoryEntry) {
        var current = loadHistory()
        current.insert(entry, at: 0)
        if current.count > 50 {
            current = Array(current.prefix(50))
        }
        encode(current, to: historyURL)
    }

    public func clearHistory() {
        encode([HistoryEntry](), to: historyURL)
    }

    // MARK: - Preferences

    public func loadPreferences() -> AppPreferences {
        decode(AppPreferences.self, from: prefsURL) ?? .default
    }

    public func savePreferences(_ prefs: AppPreferences) {
        encode(prefs, to: prefsURL)
    }

    // MARK: - Wipe-all (privacy)

    public func wipeAllData() {
        let fm = FileManager.default
        for url in [medsURL, historyURL, prefsURL] {
            try? fm.removeItem(at: url)
        }
    }

    /// Reports the on-disk sizes of each data file. Used by the privacy dashboard.
    public func storageReport() -> StorageReport {
        let fm = FileManager.default
        func sizeOf(_ url: URL) -> Int64 {
            (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        }
        return StorageReport(
            medicationsBytes: sizeOf(medsURL),
            historyBytes:     sizeOf(historyURL),
            preferencesBytes: sizeOf(prefsURL)
        )
    }

    // MARK: - Codable helpers

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: [.atomic])
        }
    }
}

public struct AppPreferences: Codable, Sendable, Equatable {
    public var preferredLanguage: String
    public var highContrast: Bool
    public var largerText: Bool
    public var voiceInputEnabled: Bool
    public var notificationsEnabled: Bool

    public static let `default` = AppPreferences(
        preferredLanguage: Locale.current.language.languageCode?.identifier ?? "en",
        highContrast: false,
        largerText: false,
        voiceInputEnabled: true,
        notificationsEnabled: true
    )
}

public struct StorageReport: Sendable, Equatable {
    public let medicationsBytes: Int64
    public let historyBytes: Int64
    public let preferencesBytes: Int64

    public var totalBytes: Int64 {
        medicationsBytes + historyBytes + preferencesBytes
    }
}
