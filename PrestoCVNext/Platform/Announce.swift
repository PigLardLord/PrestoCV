import SwiftUI

extension View {
    /// Tells VoiceOver of each new value of `change`, once, in the sentences the feature picks for it, one after the other in
    /// a single announcement queued after what VoiceOver is saying, so that none cuts another short; then reports it told.
    /// Nil tells nothing, and no sentence posts nothing.
    func announce<Change: Equatable>(
        _ change: Change?, sentences: @escaping (Change) -> [LocalizedStringResource],
        told: @escaping (Change) -> Void
    ) -> some View {
        modifier(Announcing(change: change, sentences: sentences, told: told))
    }

    /// Tells VoiceOver of each new value of `change`, once, in the words the feature picks for it, queued as above. Nil,
    /// as a value or as its words, tells nothing.
    func announce<Change: Equatable>(
        _ change: Change?, words: @escaping (Change) -> LocalizedStringResource?
    ) -> some View {
        announce(change, sentences: { words($0).map { [$0] } ?? [] }, told: { _ in })
    }
}

private struct Announcing<Change: Equatable>: ViewModifier {
    let change: Change?
    let sentences: (Change) -> [LocalizedStringResource]
    let told: (Change) -> Void
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
            if !words.isEmpty {
                // Queued: one of the default priority is cut short by the next speech, such as that of the field the
                // focus moves to
                var announcement = AttributedString(words.joined(separator: " "))
                announcement.accessibilitySpeechAnnouncementPriority = .low
                AccessibilityNotification.Announcement(announcement).post()
            }
            told(new)
        }
    }
}
