@testable import PrestoCV

/// An intake for the AI screen's tests: it reads as a CV only the texts it was given, with the draft given for each, and
/// leaves every other text to the AI draft.
struct ScriptedPastedCV: PastedCVReading {
    var drafts: [String: ImportedDraft] = [:]

    func read(_ text: String) -> ImportedDraft? {
        drafts[text]
    }
}
