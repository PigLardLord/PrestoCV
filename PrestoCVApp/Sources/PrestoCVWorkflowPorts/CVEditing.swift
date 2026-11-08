import PrestoCVDomain
import PrestoCVApplication

/// What the editor and the CV screens do with a stored CV (ADR 0010).
public protocol CVEditing: Sendable {
    /// A new, unsaved CV with a fresh identity.
    func new() -> CV
    func load(_ id: CVID) async throws(EditFailure) -> CV
    /// Stores the CV: created at its first save, updated after. Returns it with the revision and times of the store.
    func save(_ cv: CV) async throws(EditFailure) -> CV
    func rename(_ cv: CV, to title: String) async throws(EditFailure) -> CV
    /// A copy under a new identity, keeping content, design and language. Also the way to keep a CV deleted elsewhere.
    func duplicate(_ cv: CV, title: String) async throws(EditFailure) -> CV
    func delete(_ cv: CV) async throws(EditFailure)
    /// The writer of the open CV: the one owner of its revision. Every write of the open CV (its text, its look, its
    /// language) goes through it. `stored` is the CV as the store holds it, nil for an unsaved one.
    func autosaveWriter(startingFrom stored: CV?) -> any CVAutosaveWriting
}

/// Every write of the CV an editor has open. Calls are served one at a time, in the order they were made, so none sees a
/// revision another is about to replace. Untyped `throws`: a cancelled task throws `CancellationError`, any other
/// failure is an `EditFailure`.
public protocol CVAutosaveWriting: Sendable {
    /// Stores the text of `content` (title, details, sections) onto the CV the writer holds, keeping the look and the
    /// language the writer holds, stored or not: a text snapshot never undoes a look or a language chosen since. The
    /// first write of an unsaved CV creates it, with the look and the language chosen so far; one that fails or is
    /// cancelled before it reached the store keeps them for the retry.
    ///
    /// A cancelled write may still have been stored; then it returns normally. A cancelled write that was not stored
    /// throws `CancellationError`, never an `EditFailure`.
    func write(_ content: CV) async throws

    /// Changes the look of the open CV; the text the person has typed is not written by this call. Returns the CV with
    /// the change. When the CV is stored, stores it and returns it as stored. While nothing is stored, writes nothing and
    /// keeps the change in the writer, on top of the changes made before: the first `write` stores them all.
    func changeLook(_ change: LookChange, of content: CV) async throws -> CV

    /// Like `changeLook`, for the language of the document (nil: automatic).
    func setDocumentLanguage(_ language: DocumentLanguage?, of content: CV) async throws -> CV
}
