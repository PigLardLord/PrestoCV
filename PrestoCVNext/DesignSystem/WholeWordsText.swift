import SwiftUI

/// Text that keeps its words whole: a long word (a German compound at a large text size) shrinks to fit the line instead of
/// breaking in the middle, and the text wraps between words.
struct WholeWordsText: View {
    private let key: LocalizedStringKey

    init(_ key: LocalizedStringKey) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .lineLimit(nil)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
            .fixedSize(horizontal: false, vertical: true)
    }
}
