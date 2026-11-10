import SwiftUI

extension View {
    /// Tells VoiceOver of each new value of `change`, once, in the words the feature picks for it: one announcement that
    /// reads them one after the other. Nil tells nothing.
    func announce<Change: Equatable>(
        _ change: Change?, words: @escaping (Change) -> [LocalizedStringResource]
    ) -> some View {
        modifier(Announcing(change: change, words: words))
    }
}

private struct Announcing<Change: Equatable>: ViewModifier {
    let change: Change?
    let words: (Change) -> [LocalizedStringResource]
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.onChange(of: change) { _, new in
            guard let new else { return }
            // In the language the screen shows, as every other text of it. One announcement, so that a second one does
            // not cut the first off; every language of the app parts its sentences with a space.
            let spoken = words(new).map { text in
                var resource = text
                resource.locale = locale
                return String(localized: resource)
            }
            AccessibilityNotification.Announcement(spoken.joined(separator: " ")).post()
        }
    }
}
