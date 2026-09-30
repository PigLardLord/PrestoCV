import PrestoCVDomain
import PrestoCVApplication

/// The port presentation uses to create, save and load a CV; implemented in `PrestoCVIntegration`.
public protocol CVEditing: Sendable {
    /// A new, unsaved CV with a fresh identity.
    func newCV() -> CV
    /// Stores the CV and returns it as stored, with its new revision, which the caller adopts; not cancellable.
    func save(_ cv: CV) async throws(AuthoringError) -> CV
    /// The stored CV; not cancellable.
    func load(_ id: CVID) async throws(AuthoringError) -> CV
}
