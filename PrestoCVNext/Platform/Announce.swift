import SwiftUI

extension View {
    /// Tells VoiceOver of each new value of `change`, once, in the words the feature picks for it. Nil tells nothing.
    func announce<Change: Equatable>(
        _ change: Change?, words: @escaping (Change) -> LocalizedStringResource
    ) -> some View {
        modifier(Announcing(change: change) { [words($0)] })
    }

    /// Tells VoiceOver of each new value of `change`, once, in the sentences the feature picks for it, one after the other
    /// in a single announcement: one posted while another is spoken cuts it short. Nil tells nothing.
    func announce<Change: Equatable>(
        _ change: Change?, sentences: @escaping (Change) -> [LocalizedStringResource]
    ) -> some View {
        modifier(Announcing(change: change, sentences: sentences))
    }
}

private struct Announcing<Change: Equatable>: ViewModifier {
    let change: Change?
    let sentences: (Change) -> [LocalizedStringResource]
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.onChange(of: change) { _, new in
            guard let new else { return }
            // In the language the screen shows, as every other text of it
            let words = sentences(new).map { sentence in
                var resource = sentence
                resource.locale = locale
                return String(localized: resource)
            }
            AccessibilityNotification.Announcement(words.joined(separator: " ")).post()
        }
    }
}
