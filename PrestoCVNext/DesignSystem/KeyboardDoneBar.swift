import SwiftUI

/// The bar with the button that puts the keyboard away, for the keyboards that have no key to do so (the phone pad) and
/// for a text of several lines, whose return key starts a new line. A view puts it above the keyboard with
/// `aboveTheKeyboard(shown:content:)` while one of its fields has the focus.
///
/// The bar is drawn here rather than asked of the system (`ToolbarItemPlacement.keyboard`): the system's bar makes
/// SwiftUI log "Invalid frame dimension (negative or non-finite)." once the keyboard is up, and in the detail of a split
/// view as soon as the view appears, on iOS 26.5 and 27.0, Apple's own example of the placement included (#478).
struct KeyboardDoneBar: View {
    private let title: LocalizedStringResource
    private let done: () -> Void

    /// - Parameters:
    ///   - title: The button's words, which the feature gives.
    ///   - done: What putting the keyboard away does, such as clearing the focus.
    init(_ title: LocalizedStringResource, done: @escaping () -> Void) {
        self.title = title
        self.done = done
    }

    var body: some View {
        HStack {
            Spacer()
            Button(action: done) {
                Text(title)
                    .fontWeight(.semibold)
                    .frame(minHeight: TapTarget.minimumHeight)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("keyboard.done")
        }
        .padding(.horizontal, Spacing.medium)
        .background(.bar)
    }
}
