import SwiftUI

/// One action of an inline notice: its title, what VoiceOver reads for it, and the name UI tests find it by.
struct NoticeAction {
    let title: LocalizedStringResource
    let identifier: String?
    let label: LocalizedStringResource?
    let perform: () -> Void

    /// `actionIdentifier` names the button for UI tests, when a screen shows several notices that each need their own.
    /// `label` is what VoiceOver reads for the button instead of its title, when several notices offer the same action
    /// and the title alone does not say which notice the button acts on.
    init(
        _ title: LocalizedStringResource,
        actionIdentifier: String? = nil,
        label: LocalizedStringResource? = nil,
        perform: @escaping () -> Void
    ) {
        self.title = title
        self.identifier = actionIdentifier
        self.label = label
        self.perform = perform
    }
}

/// A message that stands among the content it is about, such as at the top of a list, with the actions it offers: read
/// the list again, hide the message, write a text again or open it. Each button is at least as tall as the smallest tap
/// target; the buttons stand side by side when they fit and one under the other when they do not. The message and each
/// button stay elements of their own for VoiceOver, inside one container.
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
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.small) { buttons }
                VStack(alignment: .leading, spacing: Spacing.small) { buttons }
            }
        }
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .contain)
    }

    private var buttons: some View {
        ForEach(actions.indices, id: \.self) { index in
            button(for: actions[index])
        }
    }

    @ViewBuilder
    private func button(for action: NoticeAction) -> some View {
        let base = Button(action: action.perform) {
            WholeWordsText(action.title)
                .frame(minHeight: TapTarget.minimumHeight)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: CornerRadius.control))
        .accessibilityLabel(Text(action.label ?? action.title))
        if let identifier = action.identifier {
            base.accessibilityIdentifier(identifier)
        } else {
            base
        }
    }
}
