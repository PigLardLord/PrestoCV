import SwiftUI

/// A message that stands among the content it is about, such as at the top of a list, with the one action it offers:
/// read the list again, or hide the message. The button is at least as tall as the smallest tap target, and the message
/// and the button stay two elements for VoiceOver, inside one container.
struct InlineNotice<Message: View>: View {
    private let actionTitle: LocalizedStringResource
    private let action: () -> Void
    private let message: Message

    init(actionTitle: LocalizedStringResource, action: @escaping () -> Void, @ViewBuilder message: () -> Message) {
        self.actionTitle = actionTitle
        self.action = action
        self.message = message()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            message
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: action) {
                WholeWordsText(actionTitle)
                    .frame(minHeight: TapTarget.minimumHeight)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: CornerRadius.control))
        }
        .padding(.vertical, Spacing.small)
        .accessibilityElement(children: .contain)
    }
}
