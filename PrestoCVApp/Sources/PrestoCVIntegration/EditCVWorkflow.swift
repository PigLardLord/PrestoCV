import PrestoCVDomain
import PrestoCVApplication
import PrestoCVWorkflowPorts

/// Implements `CVEditing` by delegating to the application's `NewCV`, `SaveCV` and `LoadCV`. It has no rules of its own.
public struct EditCVWorkflow: CVEditing {
    private let makeNew: NewCV, saveCV: SaveCV, loadCV: LoadCV

    public init(repository: any CVRepository, ids: any IDGenerator) {
        makeNew = NewCV(ids: ids); saveCV = SaveCV(repository: repository); loadCV = LoadCV(repository: repository)
    }

    public func newCV() -> CV { makeNew() }
    public func save(_ cv: CV) async throws(AuthoringError) -> CV { try await saveCV(cv) }
    public func load(_ id: CVID) async throws(AuthoringError) -> CV { try await loadCV(id) }
}
