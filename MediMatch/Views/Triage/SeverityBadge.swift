import SwiftUI

public struct SeverityBadge: View {
    public let severity: Severity
    public let confidence: Double?
    public let highContrast: Bool

    public init(severity: Severity, confidence: Double? = nil, highContrast: Bool = false) {
        self.severity = severity
        self.confidence = confidence
        self.highContrast = highContrast
    }

    public var body: some View {
        let color = Theme.color(for: severity, highContrast: highContrast)
        HStack(spacing: Theme.spacingSM) {
            Image(systemName: Theme.icon(for: severity))
            VStack(alignment: .leading, spacing: 2) {
                Text(severity.displayName)
                    .font(.system(.headline, design: .rounded))
                if let confidence {
                    Text(String(format: NSLocalizedString("severity.confidence",
                        value: "Confidence: %d%%", comment: ""), Int((confidence * 100).rounded())))
                        .font(.system(.caption, design: .rounded))
                        .opacity(0.85)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Theme.spacingMD)
        .padding(.vertical, Theme.spacingSM)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                .fill(color)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(severity.displayName). \(severity.shortGuidance)"))
    }
}
