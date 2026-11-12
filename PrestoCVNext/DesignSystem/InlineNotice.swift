import SwiftUI

/// A message that stands among the content it is about, such as at the top of a list, with the actions it offers: read
/// the list again, hide the message, write a text again or open it (`NoticeButtons`), or none, when the person acts in the
/// content itself. The message and each button stay elements of their own for VoiceOver, inside one container.
struct InlineNotice<Message: View>: View {
    private let actions: [NoticeAction]
    private let message: Message

    /// A notice with one action. `actionIdentifier` and `actionLabel` are those of `NoticeAction`.
    init(
        actionTitle: LocalizedStringResource,
        actionIdentifier: String? = nil,
        actionLabel: LocalizedStringResource? = nil,
        action: @escaping () -> Void,
        @ViewBuilder message: () -> Message
    ) {
        self.init(
            actions: [NoticeAction(actionTitle, actionIdentifier: actionIdentifier, label: actionLabel, perform: action)],
            message: message
        )
    }

    /// A notice with several actions, in the order given.
    init(actions: [NoticeAction], @ViewBuilder message: () -> Message) {
        self.actions = actions
        self.message = message()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            message
                .frame(maxWidth: .infinity, alignment: .leading)
            if !actions.isEmpty {
                NoticeButtons(actions, alignment: .leading)
            }
        }
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .contain)
    }
}
