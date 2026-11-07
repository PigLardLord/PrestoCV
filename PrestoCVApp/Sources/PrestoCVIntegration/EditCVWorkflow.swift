import PrestoCVDomain
import PrestoCVApplication
import PrestoCVWorkflowPorts

/// Editing a stored CV, on the use cases of the application layer. Their typed errors become `EditFailure` (R7).
public struct EditCVWorkflow: CVEditing {
    private let repository: any CVRepository
    private let ids: any IDGenerator

    public init(repository: any CVRepository, ids: any IDGenerator) { self.repository = repository; self.ids = ids }

    public func new() -> CV { NewCV(ids: ids)() }

    public func load(_ id: CVID) async throws(EditFailure) -> CV {
        do { return try await LoadCV(repository: repository)(id) } catch { throw EditFailure(error) }
    }

    public func save(_ cv: CV) async throws(EditFailure) -> CV {
        do { return try await SaveCV(repository: repository)(cv) } catch { throw EditFailure(error) }
    }

    public func rename(_ cv: CV, to title: String) async throws(EditFailure) -> CV {
        do { return try await RenameCV(repository: repository)(cv, to: title) } catch { throw EditFailure(error) }
    }

    public func duplicate(_ cv: CV, title: String) async throws(EditFailure) -> CV {
        do { return try await DuplicateCV(repository: repository, ids: ids)(cv, title: title) } catch { throw EditFailure(error) }
    }

    public func delete(_ cv: CV) async throws(EditFailure) {
        do { try await DeleteCV(repository: repository)(cv) } catch { throw EditFailure(error) }
    }

    public func changeLook(of cv: CV, _ change: LookChange) async throws(EditFailure) -> CV {
        do { return try await ChangeCV(repository: repository).look(of: cv, change) } catch { throw EditFailure(error) }
    }

    public func setDocumentLanguage(of cv: CV, to language: DocumentLanguage?) async throws(EditFailure) -> CV {
        do { return try await ChangeCV(repository: repository).documentLanguage(of: cv, to: language) } catch { throw EditFailure(error) }
    }

    public func autosaveWriter(startingFrom stored: CV?) -> any CVAutosaveWriting {
        AutosaveWriter(save: SaveCV(repository: repository), stored: stored)
    }
}

/// Keeps the latest CV the store returned, so the content the editor holds is written onto the revision the store has
/// (the editor cannot set a revision). A cancelled task writes nothing.
actor AutosaveWriter: CVAutosaveWriting {
    private let save: SaveCV
    private var latest: CV?

    init(save: SaveCV, stored: CV?) { self.save = save; latest = stored }

    func write(_ content: CV, isStored: Bool) async throws {
        try Task.checkCancellation()
        let target = isStored ? (latest.map { $0.holding(contentOf: content) } ?? content) : content
        do { latest = try await save(target) } catch { throw EditFailure(error) }
    }
}
