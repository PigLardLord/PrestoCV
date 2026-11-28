import PrestoCVDomain
import PrestoCVApplication
import PrestoCVWorkflowPorts

/// Editing a stored CV, on the use cases of the application layer. Their typed errors become `EditFailure` (R7).
public struct EditCVWorkflow: CVEditing {
    private let repository: any CVRepository
    private let ids: any IDGenerator

    public init(repository: any CVRepository, ids: any IDGenerator) { self.repository = repository; self.ids = ids }

    public func new() -> CV { NewCV(ids: ids)() }

    @concurrent public func load(_ id: CVID) async throws(EditFailure) -> CV {
        do { return try await LoadCV(repository: repository)(id) } catch { throw EditFailure(error) }
    }

    @concurrent public func save(_ cv: CV) async throws(EditFailure) -> CV {
        do { return try await SaveCV(repository: repository)(cv) } catch { throw EditFailure(error) }
    }

    @concurrent public func rename(_ cv: CV, to title: String) async throws(EditFailure) -> CV {
        do { return try await RenameCV(repository: repository)(cv, to: title) } catch { throw EditFailure(error) }
    }

    @concurrent public func duplicate(_ cv: CV, title: String) async throws(EditFailure) -> CV {
        do { return try await DuplicateCV(repository: repository, ids: ids)(cv, title: title) } catch { throw EditFailure(error) }
    }

    @concurrent public func delete(_ cv: CV) async throws(EditFailure) {
        do { try await DeleteCV(repository: repository)(cv) } catch { throw EditFailure(error) }
    }

    public func autosaveWriter(startingFrom stored: CV?) -> any CVAutosaveWriting {
        AutosaveWriter(repository: repository, stored: stored)
    }
}

/// The one owner of the open CV's revision, look and language. It keeps the latest CV the store returned, so the text the
/// editor holds is written onto the revision the store has (the editor cannot set a revision). While nothing is stored it
/// keeps the unsaved CV instead, so a look or a language chosen before the first write is not lost to a text snapshot
/// taken earlier. It serves its calls one at a time, in order: a call that waits keeps its place even if its task is
/// cancelled meanwhile.
///
/// A write that reached the store is done, whatever happened to the task meanwhile; a cancelled task whose write did not
/// reach the store throws `CancellationError`. A write that fails or is cancelled before it reached the store leaves the
/// unsaved look and language for the retry.
actor AutosaveWriter: CVAutosaveWriting {
    private let save: SaveCV
    private let change: ChangeCV
    /// The CV as the store holds it, once it holds it.
    private var latest: CV?
    /// The CV as far as the writer knows it while nothing is stored: only its look and language count.
    private var unsaved: CV?
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(repository: any CVRepository, stored: CV?) {
        save = SaveCV(repository: repository)
        change = ChangeCV(repository: repository)
        latest = stored
    }

    func write(_ content: CV) async throws {
        await turn()
        defer { next() }
        try Task.checkCancellation()
        let target = (latest ?? unsaved).map { $0.holding(contentOf: content) } ?? content
        latest = try await settled { () async throws(AuthoringError) -> CV in try await save(target) }
        unsaved = nil
    }

    func changeLook(_ look: LookChange, of content: CV) async throws -> CV {
        await turn()
        defer { next() }
        try Task.checkCancellation()
        guard let current = latest else {
            let changed = ChangeCV.applying(look, to: withText(of: content))
            unsaved = changed
            return changed
        }
        let stored = try await settled { () async throws(AuthoringError) -> CV in try await change.look(of: current, look) }
        latest = stored
        return stored
    }

    func setDocumentLanguage(_ language: DocumentLanguage?, of content: CV) async throws -> CV {
        await turn()
        defer { next() }
        try Task.checkCancellation()
        guard let current = latest else {
            let changed = ChangeCV.applying(language: language, to: withText(of: content))
            unsaved = changed
            return changed
        }
        let stored = try await settled { () async throws(AuthoringError) -> CV in try await change.documentLanguage(of: current, to: language) }
        latest = stored
        return stored
    }

    /// The unsaved CV the writer holds with the text of `content`, or `content` when it holds none.
    private func withText(of content: CV) -> CV { unsaved.map { $0.holding(contentOf: content) } ?? content }

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
