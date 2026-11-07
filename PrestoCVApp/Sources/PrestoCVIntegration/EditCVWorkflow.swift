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

    public func autosaveWriter(startingFrom stored: CV?) -> any CVAutosaveWriting {
        AutosaveWriter(repository: repository, stored: stored)
    }
}

/// The one owner of the revision of an open CV. It keeps the latest CV the store returned, so the text the editor holds is
/// written onto the revision the store has (the editor cannot set a revision), and it serves its calls one at a time, in
/// order: a call that waits keeps its place even if its task is cancelled meanwhile.
///
/// A write that reached the store is done, whatever happened to the task meanwhile; a cancelled task whose write did not
/// reach the store throws `CancellationError`.
actor AutosaveWriter: CVAutosaveWriting {
    private let save: SaveCV
    private let change: ChangeCV
    private var latest: CV?
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(repository: any CVRepository, stored: CV?) {
        save = SaveCV(repository: repository)
        change = ChangeCV(repository: repository)
        latest = stored
    }

    func write(_ content: CV, isStored: Bool) async throws {
        await turn()
        defer { next() }
        try Task.checkCancellation()
        let target = isStored ? (latest.map { $0.holding(contentOf: content) } ?? content) : content
        latest = try await settled { () async throws(AuthoringError) -> CV in try await save(target) }
    }

    func changeLook(_ look: LookChange, of content: CV) async throws -> CV {
        await turn()
        defer { next() }
        try Task.checkCancellation()
        guard let current = latest else { return ChangeCV.applying(look, to: content) }
        let stored = try await settled { () async throws(AuthoringError) -> CV in try await change.look(of: current, look) }
        latest = stored
        return stored
    }

    func setDocumentLanguage(_ language: DocumentLanguage?, of content: CV) async throws -> CV {
        await turn()
        defer { next() }
        try Task.checkCancellation()
        guard let current = latest else { return ChangeCV.applying(language: language, to: content) }
        let stored = try await settled { () async throws(AuthoringError) -> CV in try await change.documentLanguage(of: current, to: language) }
        latest = stored
        return stored
    }

    /// Runs a store operation: its failure is an `EditFailure`, or `CancellationError` when the task was cancelled meanwhile.
    private func settled(_ operation: () async throws(AuthoringError) -> CV) async throws -> CV {
        do { return try await operation() } catch {
            if Task.isCancelled { throw CancellationError() }
            throw EditFailure(error)
        }
    }

    private func turn() async {
        guard busy else { busy = true; return }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func next() {
        if waiting.isEmpty { busy = false } else { waiting.removeFirst().resume() }
    }
}
