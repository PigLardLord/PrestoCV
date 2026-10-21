import Foundation

/// What VoiceOver is told about saving. Each one is an event of its own: a retry that fails again is announced again,
/// which the state "the save failed" would not do, because it did not change.
struct SaveAnnouncement: Equatable {
    enum Kind: Equatable {
        /// A change could not be saved.
        case failed
        /// The CV is saved, after a change could not be.
        case saved
    }

    let kind: Kind
    /// Tells two announcements of one kind apart.
    let sequence: Int

    var text: String {
        switch kind {
        case .failed: "editor.save_failed".localized
        case .saved: "editor.saved".localized
        }
    }
}
