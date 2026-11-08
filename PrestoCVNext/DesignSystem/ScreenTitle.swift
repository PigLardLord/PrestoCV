import SwiftUI

/// The headline of a screen, announced to VoiceOver as a heading.
struct ScreenTitle: View {
    private let key: LocalizedStringKey

    init(_ key: LocalizedStringKey) {
        self.key = key
    }

    var body: some View {
        WholeWordsText(key)
            .font(.title2.bold())
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }
}
