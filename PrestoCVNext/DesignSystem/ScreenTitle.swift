import SwiftUI

/// The headline of a screen, announced to VoiceOver as a heading.
struct ScreenTitle: View {
    private let key: LocalizedStringResource

    init(_ key: LocalizedStringResource) {
        self.key = key
    }

    var body: some View {
        WholeWordsText(key)
            .font(.title2.bold())
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }
}
