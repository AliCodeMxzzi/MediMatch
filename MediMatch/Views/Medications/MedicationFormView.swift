import SwiftUI

struct MedicationFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var dosage: String
    @State private var notes: String
    @State private var cadence: Schedule.Cadence
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var customHourSelections: Set<Int>

    private let originalId: UUID?
    private let isActive: Bool
    private let onSave: (Medication) -> Void
    private let onCancel: () -> Void

    init(
        medication: Medication?,
        onSave: @escaping (Medication) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSave = onSave
        self.onCancel = onCancel
        if let m = medication {
            self.originalId = m.id
            self.isActive = m.isActive
            _name = State(initialValue: m.name)
            _dosage = State(initialValue: m.dosage)
            _notes = State(initialValue: m.notes)
            _cadence = State(initialValue: m.schedule.cadence)
            _startDate = State(initialValue: m.startDate)
            _hasEndDate = State(initialValue: m.endDate != nil)
            _endDate = State(initialValue: m.endDate ?? Date().addingTimeInterval(60 * 60 * 24 * 30))
            _customHourSelections = State(initialValue: Set(m.schedule.customHours))
        } else {
            self.originalId = nil
            self.isActive = true
            _name = State(initialValue: "")
            _dosage = State(initialValue: "")
            _notes = State(initialValue: "")
            _cadence = State(initialValue: .onceDaily)
            _startDate = State(initialValue: Date())
            _hasEndDate = State(initialValue: false)
            _endDate = State(initialValue: Date().addingTimeInterval(60 * 60 * 24 * 30))
            _customHourSelections = State(initialValue: [])
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("medications.form.basics",
                    value: "Basics", comment: "")) {
                    TextField(NSLocalizedString("medications.form.name",
                        value: "Name", comment: ""), text: $name)
                    TextField(NSLocalizedString("medications.form.dosage",
                        value: "Dosage (e.g. 500 mg)", comment: ""), text: $dosage)
                    TextField(NSLocalizedString("medications.form.notes",
                        value: "Notes", comment: ""), text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(NSLocalizedString("medications.form.schedule",
                    value: "Schedule", comment: "")) {
                    Picker(NSLocalizedString("medications.form.cadence",
                        value: "How often", comment: ""), selection: $cadence) {
                        ForEach(Schedule.Cadence.allCases, id: \.self) { cadence in
                            Text(cadence.displayName).tag(cadence)
                        }
                    }

                    if cadence != .asNeeded {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("medications.form.times",
                                value: "Reminder times", comment: ""))
                                .font(.subheadline)
                            HourGrid(selection: $customHourSelections,
                                     defaultHours: cadence.hoursOfDay)
                            Text(NSLocalizedString("medications.form.times.hint",
                                value: "Tap to choose specific hours, or leave blank to use the defaults.",
                                comment: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(NSLocalizedString("medications.form.dates",
                    value: "Dates", comment: "")) {
                    DatePicker(NSLocalizedString("medications.form.start",
                        value: "Start", comment: ""), selection: $startDate,
                        displayedComponents: .date)
                    Toggle(NSLocalizedString("medications.form.hasEnd",
                        value: "Set end date", comment: ""), isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker(NSLocalizedString("medications.form.end",
                            value: "End", comment: ""), selection: $endDate,
                            displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(originalId == nil
                ? NSLocalizedString("medications.form.titleNew", value: "New medication", comment: "")
                : NSLocalizedString("medications.form.titleEdit", value: "Edit medication", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel",
                        value: "Cancel", comment: ""), action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.save",
                        value: "Save", comment: "")) {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let schedule = Schedule(
            cadence: cadence,
            customHours: Array(customHourSelections).sorted()
        )
        let med = Medication(
            id: originalId ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines),
            schedule: schedule,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            isActive: isActive
        )
        onSave(med)
    }
}

private struct HourGrid: View {
    @Binding var selection: Set<Int>
    let defaultHours: [Int]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<24, id: \.self) { hour in
                let isSelected = selection.contains(hour)
                let isDefault = defaultHours.contains(hour) && selection.isEmpty
                Button {
                    if selection.contains(hour) {
                        selection.remove(hour)
                    } else {
                        selection.insert(hour)
                    }
                } label: {
                    Text(label(hour: hour))
                        .font(.caption)
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
                .buttonStyle(.bordered)
                .tint(isSelected || isDefault ? Color.accentColor : Color.gray)
            }
        }
    }

    private func label(hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: Calendar.current.date(from: components) ?? Date())
    }
}
