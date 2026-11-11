import SwiftUI

extension View {
    /// Tells VoiceOver of each new value of `change`, once, in the words the feature picks for it. Nil, as a value or
    /// as its words, tells nothing.
    func announce<Change: Equatable>(
        _ change: Change?, words: @escaping (Change) -> LocalizedStringResource?
    ) -> some View {
        modifier(Announcing(change: change, words: words))
    }
}

private struct Announcing<Change: Equatable>: ViewModifier {
    let change: Change?
    let words: (Change) -> LocalizedStringResource?
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.onChange(of: change) { _, new in
            guard let new, var resource = words(new) else { return }
            // In the language the screen shows, as every other text of it
            resource.locale = locale
            AccessibilityNotification.Announcement(String(localized: resource)).post()
        }
    }
}
