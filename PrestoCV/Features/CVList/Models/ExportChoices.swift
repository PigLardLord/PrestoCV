import PrestoCVCore
import struct PrestoCVApplication.LookChange

/// What was chosen for a CV in its export sheet, the language of its PDF and its look, and the CV does not hold yet: the
/// latest choice of each. The list keeps it from the moment a choice is made until the row of the CV shows it, so that
/// the next sheet starts from what the last one left, and not from a row that is a save behind.
struct ExportChoices: Equatable {
    /// The language chosen for the PDF. `Language(nil)` is a choice too: Automatic.
    struct Language: Equatable {
        let value: DocumentLanguage?
    }

    var documentLanguage: Language?
    /// The parts of the look the person chose, with the look the sheet showed once they had.
    var look: LookChange?

    init(documentLanguage: Language? = nil, look: LookChange? = nil) {
        self.documentLanguage = documentLanguage
        self.look = look
    }

    /// Nothing was chosen.
    var isEmpty: Bool {
        documentLanguage == nil && look == nil
    }

    /// These choices and then `later`: the latest choice of the language, and the parts of the look chosen in either, each
    /// with the value of its latest choice.
    func followed(by later: ExportChoices) -> ExportChoices {
        ExportChoices(
            documentLanguage: later.documentLanguage ?? documentLanguage,
            look: look.map { earlier in later.look.map(earlier.followed(by:)) ?? earlier } ?? later.look
        )
    }

    /// `cv` after the choices are made on it: its language, and the parts of its look that were chosen, as the store
    /// applies them. A CV that already shows the choices is left as it is, so a row that was stored since is not undone.
    func applied(to cv: CVModel) -> CVModel {
        var chosen = cv
        if let documentLanguage {
            chosen.documentLanguage = documentLanguage.value?.rawValue
        }
        if let look {
            chosen.look = CVLook.applying(look, to: cv.look)
        }
        return chosen
    }
}
