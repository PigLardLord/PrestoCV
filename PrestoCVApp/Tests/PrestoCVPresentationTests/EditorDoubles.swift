import Foundation
import Synchronization
import Testing
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// Holds the writes that reach it while it is closed, so that a test decides when each one goes on.
actor Gate {
    private var isClosed = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var waiting: Int { waiters.count }

    func close() { isClosed = true }

    func open() {
        isClosed = false
        releaseAll()
    }

    func releaseAll() {
        let released = waiters
        waiters = []
        released.forEach { $0.resume() }
    }

    func pass() async {
        guard isClosed else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

/// The editing port on the use cases of the application layer and an in-memory store, with a gate before each write
/// of the autosave and a record of what reached it.
final class EditingFake: CVEditing {
    let store = InMemoryCVRepository()
    let ids = SequentialIDGenerator()
    let gate = Gate()
    /// Each CV an autosave writer took to the store, before the store checked it.
    let writes = Mutex<[CV]>([])
    let mostWritesAtOnce = Mutex(0)
    /// Thrown by the next writes of the autosave, before the store is reached.
    let writeErrors = Mutex<[any Error]>([])
    let copies = Mutex<[CV]>([])
    let languages = Mutex<[DocumentLanguage?]>([])
    let looks = Mutex<[LookChange]>([])
    let loads = Mutex(0)
    private let writesRunning = Mutex(0)

    var writeCount: Int { writes.withLock { $0.count } }

    func new() -> CV { NewCV(ids: ids)() }

    func load(_ id: CVID) async throws(EditFailure) -> CV {
        loads.withLock { $0 += 1 }
        do { return try await LoadCV(repository: store)(id) } catch { throw EditFailure(error) }
    }

    func save(_ cv: CV) async throws(EditFailure) -> CV {
        do { return try await SaveCV(repository: store)(cv) } catch { throw EditFailure(error) }
    }

    func rename(_ cv: CV, to title: String) async throws(EditFailure) -> CV {
        do { return try await RenameCV(repository: store)(cv, to: title) } catch { throw EditFailure(error) }
    }

    func duplicate(_ cv: CV, title: String) async throws(EditFailure) -> CV {
        let copy = cv.duplicated(as: ids.next(), title: title)
        copies.withLock { $0.append(copy) }
        return try await save(copy)
    }

    func delete(_ cv: CV) async throws(EditFailure) {
        do { try await DeleteCV(repository: store)(cv) } catch { throw EditFailure(error) }
    }

    func changeLook(of cv: CV, _ change: LookChange) async throws(EditFailure) -> CV {
        looks.withLock { $0.append(change) }
        do { return try await ChangeCV(repository: store).look(of: cv, change) } catch { throw EditFailure(error) }
    }

    func setDocumentLanguage(of cv: CV, to language: DocumentLanguage?) async throws(EditFailure) -> CV {
        languages.withLock { $0.append(language) }
        do { return try await ChangeCV(repository: store).documentLanguage(of: cv, to: language) } catch { throw EditFailure(error) }
    }

    func autosaveWriter(startingFrom stored: CV?) -> any CVAutosaveWriting { GatedWriter(editing: self, latest: stored) }

    /// What one autosave writer does: it keeps the CV the store returned and writes the form's content onto it.
    actor GatedWriter: CVAutosaveWriting {
        let editing: EditingFake
        var latest: CV?

        init(editing: EditingFake, latest: CV?) { self.editing = editing; self.latest = latest }

        func write(_ content: CV, isStored: Bool) async throws {
            let target = isStored ? (latest.map { $0.holding(contentOf: content) } ?? content) : content
            editing.writes.withLock { $0.append(target) }
            let running = editing.writesRunning.withLock { $0 += 1; return $0 }
            editing.mostWritesAtOnce.withLock { $0 = max($0, running) }
            await editing.gate.pass()
            editing.writesRunning.withLock { $0 -= 1 }
            if let error = editing.writeErrors.withLock({ $0.isEmpty ? nil : $0.removeFirst() }) { throw error }
            latest = try await editing.save(target)
        }
    }

    /// A CV in the store, as an earlier session left it.
    func stored(title: String, fullName: String, language: String?) async throws -> CV {
        try await store.create(CV(id: ids.next(), title: title, personal: PersonalDetails(fullName: fullName),
                                  language: language.flatMap(DocumentLanguage.init)))
    }

    /// Another window saves `cv` with another full name.
    func otherWindowSaves(_ cv: CV, fullName: String) async throws {
        var other = try await store.load(cv.id)
        other.setPersonalDetails(PersonalDetails(fullName: fullName))
        _ = try await store.update(other)
    }

    /// The CV as the store holds it now.
    func inStore(_ id: CVID) async throws -> CV { try await store.load(id) }
}

extension EditFailure {
    init(_ error: AuthoringError) {
        switch error {
        case .notEnoughContent: self = .notEnoughContent
        case .conflict(let revision): self = .conflict(storedRevision: revision)
        case .deletedElsewhere: self = .deletedElsewhere
        case .tooLarge: self = .tooLarge
        case .unavailable: self = .unavailable
        case .textTooLong(let field): self = .textTooLong(field)
        case .tooManyEntries(let section): self = .tooManyEntries(section)
        case .cvTooLarge: self = .cvTooLarge
        }
    }
}

/// The export port: it records each snapshot and gives the outcome a test set.
final class ExportingFake: CVExporting {
    let gate = Gate()
    let snapshots = Mutex<[CV]>([])
    let languages = Mutex<[DocumentLanguage]>([])
    let result = Mutex<Result<ExportOutcome, any Error>>(.success(ExportOutcome(pdf: Data([1, 2, 3]), pageCount: 1, requiredPages: 1)))

    func export(_ snapshot: CV, language: DocumentLanguage) async throws -> ExportOutcome {
        snapshots.withLock { $0.append(snapshot) }
        languages.withLock { $0.append(language) }
        await gate.pass()
        return try result.withLock { $0 }.get()
    }
}

/// The editor on the two fakes and a clock moved by hand. The pause is one second, as in version 1.
@MainActor
struct Editing {
    let editing = EditingFake()
    let exporting = ExportingFake()
    let clock = ManualClock()

    func editor(_ start: EditorStart) -> EditorViewModel {
        EditorViewModel(start: start, editing: editing, exporting: exporting, clock: self.clock, pause: .seconds(1),
                        copyTitle: { "Copy of " + $0 })
    }

    /// A CV in the store with invented values: titled "Design roles", in Italian.
    func storedCV() async throws -> CV {
        try await editing.stored(title: "Design roles", fullName: "Mara Ellison", language: "it")
    }

    /// The full name the store holds for `cv`, or nil when it holds no such CV.
    func storedName(of cv: CV) async -> String? {
        (try? await editing.inStore(cv.id))?.personal.fullName
    }

    /// An editor open on a CV of the store.
    func editor(on cv: CV) async -> EditorViewModel {
        let editor = editor(.stored(CVReference(id: cv.id)))
        await editor.load()
        return editor
    }

    /// Moves the clock past the pause and waits for the write it starts to reach the store's door.
    func passThePause(thenWrites expected: Int) async {
        self.clock.advance(by: .seconds(1))
        await waitUntil("\(expected) writes") { editing.writeCount >= expected }
    }
}

/// A bounded wait that records an issue instead of hanging or passing by luck.
@MainActor
func waitUntil(_ what: String, _ condition: @MainActor () async -> Bool) async {
    for _ in 0..<10_000 {
        if await condition() { return }
        await Task.yield()
    }
    Issue.record("timed out waiting for \(what)")
}

/// Lets every task that can run, run: for checking that something did not happen.
@MainActor
func settle() async {
    for _ in 0..<200 { await Task.yield() }
}

@MainActor
final class Returned { var value = false }

extension EditorViewModel {
    /// Types into a field of the form, as the person does.
    func type(_ field: WritableKeyPath<EditorContent, String>, _ text: String) {
        var form = content
        form[keyPath: field] = text
        content = form
    }
}
