import SwiftUI

/// Draws any label as text in the accent: the accent at rest and the pressed accent while pressed, both opaque, and a
/// slight shrink. A press never fades the label below its contrast. The label sets no colour of its own, which would
/// hide the pressed one.
struct AccentTextButtonStyle: ButtonStyle {
    /// The colour of the label, at rest or pressed.
    static func foregroundColor(isPressed: Bool) -> Color {
        isPressed ? DesignTokens.Colors.accentPressed : DesignTokens.Colors.accent
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Self.foregroundColor(isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
