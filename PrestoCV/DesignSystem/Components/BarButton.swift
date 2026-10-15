import SwiftUI

/// What a button of a navigation bar shows.
///
/// A bar keeps its buttons at a regular text size, also at the accessibility sizes, and there the words of "Cancel"
/// and "Save" leave the title between them so little room that it ends in "…". From those sizes on a button shows
/// its symbol alone, as Apple's own apps do; VoiceOver still reads its name.
enum BarButtonContent: Equatable {
    case words
    case symbol

    /// - Parameter screenTextSize: The text size of the screen. Inside a bar every size reads as a regular one.
    static func resolve(screenTextSize: DynamicTypeSize) -> BarButtonContent {
        screenTextSize.isAccessibilitySize ? .symbol : .words
    }
}

/// A button of a navigation bar: its words, or its symbol at the accessibility sizes. See `BarButtonContent`.
struct BarButton: View {
    let title: String
    let systemImage: String
    /// The text size of the screen, read outside the bar.
    let screenTextSize: DynamicTypeSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            switch BarButtonContent.resolve(screenTextSize: screenTextSize) {
            case .words:
                Text(title)
            case .symbol:
                Image(systemName: systemImage)
            }
        }
        .accessibilityLabel(title)
        .accessibilityShowsLargeContentViewer {
            Label(title, systemImage: systemImage)
        }
    }
}
