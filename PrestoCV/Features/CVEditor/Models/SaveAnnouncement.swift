import Foundation

/// What VoiceOver is told about the person's work in the editor: that it could not be saved, that it is saved again, or that
/// the import's notice is dismissed. Each one is an event of its own: a retry that fails again is announced again, which the
/// state "the save failed" would not do, because it did not change.
struct SaveAnnouncement: Equatable {
    enum Kind: Equatable {
        /// A change could not be saved.
        case failed
        /// The CV is saved, after a change could not be.
        case saved
        /// The person dismissed the import's notice, and the banner went with the button that held VoiceOver's focus.
        case noticeDismissed
    }

    let kind: Kind
    /// Tells two announcements of one kind apart.
    let sequence: Int

    var text: String {
        switch kind {
        case .failed: "editor.save_failed".localized
        case .saved: "editor.saved".localized
        case .noticeDismissed: "editor.notice.dismissed".localized
        }
    }

    /// VoiceOver says it over what it reads of the element it moves to: the dismissal took away the element that held the
    /// focus, so VoiceOver moves, and its reading would otherwise cut the announcement short.
    var speaksOverFocusChange: Bool {
        switch kind {
        case .failed, .saved: false
        case .noticeDismissed: true
        }
    }
}
