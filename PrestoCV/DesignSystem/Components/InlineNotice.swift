import SwiftUI

/// How a notice lays out its message and its action: side by side, or the action under the message when the text is so
/// large that the message would be squeezed beside the button.
enum InlineNoticeLayout: Equatable {
    case sideBySide
    case stacked

    /// - Parameter textSize: The text size of the screen.
    static func resolve(textSize: DynamicTypeSize) -> InlineNoticeLayout {
        textSize.isAccessibilitySize ? .stacked : .sideBySide
    }
}

/// A one-line notice above the content of a screen, for something that went wrong without stopping the screen.
/// It can offer one action, such as dismissing the notice or trying again. The action is a target of at least 44 points
/// each way, whatever size the text has, with the whole frame in the hit area: it can be the way to recover someone's
/// edits.
struct InlineNotice: View {
    /// The least width and height of the action.
    static let minimumActionTarget = DesignTokens.InputSize.minimumTapTarget

    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        switch InlineNoticeLayout.resolve(textSize: dynamicTypeSize) {
        case .sideBySide:
            notice(HStack(spacing: DesignTokens.Spacing.sm) { content })
        case .stacked:
            notice(VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) { content })
        }
    }

    @ViewBuilder
    private var content: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(DesignTokens.Typography.caption1.font)
            .foregroundColor(DesignTokens.Colors.primary)
            .symbolRenderingMode(.multicolor)
            .frame(maxWidth: .infinity, alignment: .leading)

        if let actionTitle, let action {
            Button(action: action) {
                Text(actionTitle)
                    .font(DesignTokens.Typography.caption1.font)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: false, minimumTarget: Self.minimumActionTarget))
        }
    }

    private func notice(_ content: some View) -> some View {
        content
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.backgroundSecondary)
            .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    InlineNotice(message: "2 CVs could not be opened", actionTitle: "OK", action: {})
}
#endif
