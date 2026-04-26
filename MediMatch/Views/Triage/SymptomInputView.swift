import SwiftUI

struct SymptomInputView: View {
    @ObservedObject var viewModel: TriageViewModel
    @EnvironmentObject private var settings: AccessibilitySettings
    @EnvironmentObject private var speech:   SpeechRecognitionService
    @State private var permissionDenied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            descriptionField
            voiceRow
            symptomCatalog
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text(NSLocalizedString("triage.input.title",
                value: "Describe what you're feeling", comment: ""))
                .font(.system(.headline, design: .rounded))
                .dismissesKeyboardOnTap()
            TextEditor(text: $viewModel.input)
                .frame(minHeight: 120)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.input.isEmpty {
                        Text(NSLocalizedString("triage.input.placeholder",
                            value: "e.g. fever for two days, dry cough, mild chest pain when breathing.",
                            comment: ""))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(Text(NSLocalizedString("a11y.symptom.field",
                    value: "Symptom description text field", comment: "")))
        }
    }

    private var voiceRow: some View {
        HStack(spacing: Theme.spacingSM) {
            if settings.voiceInputEnabled {
                Button {
                    Task { await toggleRecording() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title3)
                        Text(speech.isRecording
                             ? NSLocalizedString("triage.voice.stop", value: "Stop", comment: "")
                             : NSLocalizedString("triage.voice.start", value: "Voice input", comment: ""))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(speech.isRecording
                                       ? Color.red.opacity(0.15)
                                       : Color.accentColor.opacity(0.15))
                    )
                }
                .accessibilityHint(Text(NSLocalizedString("a11y.voice.hint",
                    value: "Toggles on-device speech recognition.", comment: "")))
            }
            if !speech.transcript.isEmpty {
                Text(speech.transcript)
                    .lineLimit(2)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if permissionDenied {
                Text(NSLocalizedString("triage.voice.denied",
                    value: "Microphone access denied", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .dismissesKeyboardOnTap()
    }

    private var symptomCatalog: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text(NSLocalizedString("triage.catalog.title",
                value: "Or pick from common symptoms", comment: ""))
                .font(.system(.headline, design: .rounded))
                .dismissesKeyboardOnTap()

            ForEach(Symptom.BodySystem.allCases, id: \.self) { body in
                if let symptoms = SymptomCatalog.byBodySystem[body], !symptoms.isEmpty {
                    DisclosureGroup(body.displayName) {
                        chipsLayout(symptoms: symptoms)
                            .padding(.top, 6)
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func chipsLayout(symptoms: [Symptom]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(symptoms) { symptom in
                let selected = viewModel.selectedSymptomIds.contains(symptom.id)
                Button {
                    viewModel.toggleSymptom(symptom.id)
                } label: {
                    Text(symptom.displayName)
                        .font(.system(.subheadline, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(selected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .foregroundStyle(selected ? Color.accentColor : .primary)
                }
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }

    @MainActor
    private func toggleRecording() async {
        if speech.isRecording {
            speech.stop()
            // Append the transcript to the input box.
            let captured = speech.transcript
            if !captured.isEmpty {
                if !viewModel.input.isEmpty { viewModel.input += " " }
                viewModel.input += captured
            }
            speech.reset()
            return
        }
        let ok = await speech.requestAuthorization()
        permissionDenied = !ok
        guard ok else { return }
        do {
            try speech.start(locale: settings.preferredLocale)
        } catch {
            permissionDenied = true
        }
    }
}

/// Tiny flow layout. Replaces the `Layout` requirement with a custom one that
/// wraps chips. Targets iOS 17 (we set deployment target accordingly).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: proposal.width ?? lineWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
