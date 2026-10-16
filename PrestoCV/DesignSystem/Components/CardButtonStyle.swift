import SwiftUI

/// Draws a card as a button: the card as it is, a little smaller while pressed. A press never fades the card, so its
/// text and its symbols keep their contrast.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
