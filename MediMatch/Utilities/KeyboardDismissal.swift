import SwiftUI
import UIKit

/// Resigns the first responder to hide the software keyboard.
public enum KeyboardDismissal {
    public static func endEditing() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

/// Taps on the modified view end editing; subviews (text fields, buttons) keep normal hit testing.
private struct DismissesKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { KeyboardDismissal.endEditing() }
    }
}

public extension View {
    /// Use on headers, side sections, and non-text areas so users can leave keyboard mode with a tap.
    func dismissesKeyboardOnTap() -> some View {
        modifier(DismissesKeyboardOnTapModifier())
    }
}
