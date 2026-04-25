import SwiftUI

struct MedicationCard: View {
    let medication: Medication
    let onToggleActive: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(medication.name)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text(medication.dosage.isEmpty ? "—" : medication.dosage)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { medication.isActive },
                    set: { _ in onToggleActive() }
                ))
                .labelsHidden()
                .accessibilityLabel(Text(String(format: NSLocalizedString(
                    "medications.toggle.a11y", value: "Active reminders for %@",
                    comment: ""), medication.name)))
            }

            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .foregroundStyle(Color.accentColor)
                Text(scheduleSummary)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if !medication.notes.isEmpty {
                Text(medication.notes)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack {
                Spacer()
                Button {
                    onEdit()
                } label: {
                    Label(NSLocalizedString("common.edit",
                        value: "Edit", comment: ""), systemImage: "pencil")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(Theme.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusCard, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .padding(.vertical, 4)
    }

    private var scheduleSummary: String {
        let cadence = medication.schedule.cadence.displayName
        let hours = medication.schedule.effectiveHours
        if hours.isEmpty {
            return cadence
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let times = hours.map { hour -> String in
            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let date = Calendar.current.date(from: components) ?? Date()
            return formatter.string(from: date)
        }
        return "\(cadence) — \(times.joined(separator: ", "))"
    }
}
