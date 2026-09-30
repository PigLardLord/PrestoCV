import PrestoCVDomain
import PrestoCVApplication

/// The port presentation uses to create, save and load a CV; implemented in `PrestoCVIntegration`.
public protocol CVEditing: Sendable {
    func newCV() -> CV
    func save(_ cv: CV) async throws(AuthoringError) -> CV
    func load(_ id: CVID) async throws(AuthoringError) -> CV
}
