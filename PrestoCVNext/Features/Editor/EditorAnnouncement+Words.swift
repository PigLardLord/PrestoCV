import PrestoCVPresentation
import SwiftUI

extension EditorAnnouncement {
    /// The words VoiceOver tells: where the status settled (with what to do while the person cannot leave), then the note
    /// of each problem the status does not name.
    func sentences(in locale: Locale) -> [LocalizedStringResource] {
        (status.map { $0.spoken(in: locale) } ?? []) + problems.map(noteWords(of:))
    }
}
