import PrestoCVPresentation
import SwiftUI

/// The line under the CV's title that says where the person's text stands with the store. Every status has its words,
/// so nothing is left unsaid.
struct SaveStatusLine: View {
    let status: SaveStatus

    var body: some View {
        WholeWordsText(status.words)
            .footerTextStyle()
            .accessibilityIdentifier("editor.status")
    }
}

extension SaveStatus {
    /// The words of the status, on its line and in the announcement of a change. A text too long or a section too full is
    /// said in general: the field or section is named beside it in a later step.
    var words: LocalizedStringResource {
        switch self {
        case .saved: "editor.status.saved"
        case .pending: "editor.status.pending"
        case .saving: "editor.status.saving"
        case .notEnoughContent: "editor.status.notEnoughContent"
        case .textTooLong: "editor.status.textTooLong"
        case .tooManyEntries: "editor.status.tooManyEntries"
        case .tooLarge: "editor.status.tooLarge"
        case .unreadable: "editor.status.unreadable"
        case .conflict: "editor.status.conflict"
        case .deletedElsewhere: "editor.status.deletedElsewhere"
        case .failed: "editor.status.failed"
        }
    }
}
