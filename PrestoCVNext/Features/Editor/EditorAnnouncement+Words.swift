import PrestoCVPresentation
import SwiftUI

extension EditorAnnouncement {
    /// The words VoiceOver tells: where the status settled, then the note of each problem the status does not name.
    var sentences: [LocalizedStringResource] {
        (status.map { [$0.words] } ?? []) + problems.map(noteWords(of:))
    }
}
