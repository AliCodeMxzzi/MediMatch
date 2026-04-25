import SwiftUI

/// App-wide design tokens. Centralizes colors and spacing so we can support
/// dynamic type and a high-contrast preference from a single place.
public enum Theme {

    // MARK: - Spacing

    public static let spacingXS: CGFloat = 4
    public static let spacingSM: CGFloat = 8
    public static let spacingMD: CGFloat = 16
    public static let spacingLG: CGFloat = 24
    public static let spacingXL: CGFloat = 32

    // MARK: - Radii

    public static let cornerRadiusCard: CGFloat = 16
    public static let cornerRadiusControl: CGFloat = 12

    // MARK: - Severity colors (semantic)

    public static func color(for severity: Severity, highContrast: Bool) -> Color {
        switch severity {
        case .selfCare:
            return highContrast ? Color(red: 0.0, green: 0.45, blue: 0.20) : Color.green
        case .urgentCare:
            return highContrast ? Color(red: 0.82, green: 0.42, blue: 0.0) : Color.orange
        case .emergency:
            return highContrast ? Color(red: 0.78, green: 0.0, blue: 0.0) : Color.red
        case .unknown:
            return Color.secondary
        }
    }

    public static func icon(for severity: Severity) -> String {
        switch severity {
        case .selfCare: return "house.fill"
        case .urgentCare: return "stethoscope"
        case .emergency: return "cross.case.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// View modifier that adapts text styles based on accessibility prefs.
public struct AccessibleText: ViewModifier {
    public let style: Font.TextStyle
    @Environment(\.sizeCategory) private var sizeCategory

    public func body(content: Content) -> some View {
        content
            .font(.system(style, design: .rounded))
            .lineSpacing(2)
            .dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
}

public extension View {
    func accessibleText(_ style: Font.TextStyle = .body) -> some View {
        modifier(AccessibleText(style: style))
    }
}
