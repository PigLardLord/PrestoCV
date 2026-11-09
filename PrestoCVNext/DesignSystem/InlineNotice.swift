import SwiftUI

/// A message that stands among the content it is about, such as at the top of a list, with the one action it offers:
/// read the list again, or hide the message. The button is at least as tall as the smallest tap target, and the message
/// and the button stay two elements for VoiceOver, inside one container.
struct InlineNotice<Message: View>: View {
    private let actionTitle: LocalizedStringResource
    private let actionIdentifier: String?
    private let actionLabel: LocalizedStringResource?
    private let action: () -> Void
    private let message: Message

    /// `actionIdentifier` names the button for UI tests, when a screen shows several notices that each need their own.
    /// `actionLabel` is what VoiceOver reads for the button instead of its title, when several notices offer the same
    /// action and the title alone does not say which notice the button acts on.
    init(
        actionTitle: LocalizedStringResource,
        actionIdentifier: String? = nil,
        actionLabel: LocalizedStringResource? = nil,
        action: @escaping () -> Void,
        @ViewBuilder message: () -> Message
    ) {
        self.actionTitle = actionTitle
        self.actionIdentifier = actionIdentifier
        self.actionLabel = actionLabel
        self.action = action
        self.message = message()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            message
                .frame(maxWidth: .infinity, alignment: .leading)
            button
        }
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var button: some View {
        let base = Button(action: action) {
            WholeWordsText(actionTitle)
                .frame(minHeight: TapTarget.minimumHeight)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: CornerRadius.control))
        .accessibilityLabel(Text(actionLabel ?? actionTitle))
        if let actionIdentifier {
            base.accessibilityIdentifier(actionIdentifier)
        } else {
            base
        }
    }
}
