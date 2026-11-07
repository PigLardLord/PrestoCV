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
    func changeLook(of cv: CV, _ change: LookChange) async throws(EditFailure) -> CV
    func setDocumentLanguage(of cv: CV, to language: DocumentLanguage?) async throws(EditFailure) -> CV
    /// The writer an `Autosave` of the editor calls. `stored` is the CV as the store holds it, nil for an unsaved one.
    /// Overlapping saves are serialised by the view model (ADR 0010), not here.
    func autosaveWriter(startingFrom stored: CV?) -> any CVAutosaveWriting
}

/// One write of the editor's content. Untyped `throws`: a cancelled task throws `CancellationError`, any other
/// failure is an `EditFailure`.
public protocol CVAutosaveWriting: Sendable {
    func write(_ content: CV, isStored: Bool) async throws
}
