import SwiftUI

public struct PrimaryButton: View {
    public let title: String
    public let systemImage: String?
    public let role: ButtonRole?
    public let isLoading: Bool
    public let isEnabled: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: Theme.spacingSM) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                    .fill(isEnabled ? Color.accentColor : Color.gray.opacity(0.5))
            )
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isLoading ? [.updatesFrequently] : [])
    }
}

public struct SecondaryButton: View {
    public let title: String
    public let systemImage: String?
    public let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacingSM) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title).font(.system(.body, design: .rounded, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(Color.accentColor)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusControl, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1.5)
            )
        }
    }
}
