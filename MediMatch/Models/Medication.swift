import Foundation

/// A user-managed medication record (entirely on-device).
public struct Medication: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var dosage: String
    public var schedule: Schedule
    public var notes: String
    public var startDate: Date
    public var endDate: Date?
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        schedule: Schedule,
        notes: String = "",
        startDate: Date = .init(),
        endDate: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.schedule = schedule
        self.notes = notes
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
    }
}

public struct Schedule: Codable, Hashable, Sendable {
    public enum Cadence: String, Codable, Sendable, CaseIterable {
        case onceDaily      = "once_daily"
        case twiceDaily     = "twice_daily"
        case threeTimesDaily = "three_times_daily"
        case asNeeded       = "as_needed"

        public var displayName: String {
            switch self {
            case .onceDaily:       return NSLocalizedString("schedule.onceDaily",  value: "Once daily",        comment: "")
            case .twiceDaily:      return NSLocalizedString("schedule.twiceDaily", value: "Twice daily",       comment: "")
            case .threeTimesDaily: return NSLocalizedString("schedule.thrice",     value: "Three times daily", comment: "")
            case .asNeeded:        return NSLocalizedString("schedule.asNeeded",   value: "As needed",         comment: "")
            }
        }

        /// Local hours-of-day used to schedule daily reminders.
        public var hoursOfDay: [Int] {
            switch self {
            case .onceDaily:       return [9]
            case .twiceDaily:      return [9, 21]
            case .threeTimesDaily: return [8, 14, 20]
            case .asNeeded:        return []
            }
        }
    }

    public var cadence: Cadence
    /// User-provided override; if empty we use `cadence.hoursOfDay`.
    public var customHours: [Int]

    public init(cadence: Cadence, customHours: [Int] = []) {
        self.cadence = cadence
        self.customHours = customHours
    }

    public var effectiveHours: [Int] {
        customHours.isEmpty ? cadence.hoursOfDay : customHours
    }
}
