import SwiftUI

/// One action a notice or an empty state offers: its title, what VoiceOver reads for it, and the name UI tests find it by.
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

    /// The names Voice Control takes for the button: the title it shows, then the label VoiceOver reads when there is one,
    /// so that the words on screen always work (WCAG 2.5.3, label in name).
    var inputLabels: [LocalizedStringResource] {
        [title] + (label.map { [$0] } ?? [])
    }
}

/// The buttons of a notice or an empty state, in the order given. Each is at least as tall as the smallest tap target;
/// they stand side by side when they fit and one under the other, aligned as `alignment` says, when they do not.
struct NoticeButtons: View {
    private let actions: [NoticeAction]
    private let alignment: HorizontalAlignment

    init(_ actions: [NoticeAction], alignment: HorizontalAlignment) {
        self.actions = actions
        self.alignment = alignment
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.small) { buttons }
            VStack(alignment: alignment, spacing: Spacing.small) { buttons }
        }
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
        .accessibilityInputLabels(action.inputLabels.map { Text($0) })
        if let identifier = action.identifier {
            base.accessibilityIdentifier(identifier)
        } else {
            base
        }
    }
}
