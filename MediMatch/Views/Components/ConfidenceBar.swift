import SwiftUI

/// Horizontal bar visualizing a confidence score in [0, 1].
public struct ConfidenceBar: View {
    public let value: Double
    public let tint: Color

    public init(value: Double, tint: Color = .accentColor) {
        self.value = max(0, min(1, value))
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(width: max(8, proxy.size.width * value))
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel(Text(NSLocalizedString("confidence.label",
            value: "Confidence", comment: "")))
        .accessibilityValue(Text(percentString))
    }

    private var percentString: String {
        let pct = Int((value * 100).rounded())
        return "\(pct)%"
    }
}

public struct EmptyStateView: View {
    public let icon: String
    public let title: String
    public let message: String

    public init(icon: String, title: String, message: String) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    public var body: some View {
        VStack(spacing: Theme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(Color.secondary)
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.spacingLG)
        .frame(maxWidth: .infinity)
    }
}
