import CVRendering
import Foundation
import Observation
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVDomain
import PrestoCVPersistence
import PrestoCVPresentation
import PrestoCVWorkflowPorts
import Testing
@testable import PrestoCVComposition

/// The factory of the screens' view models over a real composition: a temporary folder, the real repository, fake clock
/// and ids. Nothing sleeps but an export sheet, which waits for its pause on the composition's clock: a write is awaited
/// through `saveNow()`, a result through `load()`, and an export through the sheet's status.
@MainActor
@Suite("The screen factory")
struct ScreenFactoryTests {
    /// A ready composition, its folders and the id source it was given (to know which ids it hands out).
    struct Fixture {
        let composition: Composition
        let paths: AppPaths
        let ids: SequentialIDGenerator
        let counter: CompositionTests.CompileCounter

        var samples: URL { paths.root.appendingPathComponent("Samples", isDirectory: true) }

        func clean() { try? FileManager.default.removeItem(at: paths.temporary) }
    }

    private static func fixture(_ paths: AppPaths = CompositionTests.paths(), copyFolders: [URL] = []) async throws -> Fixture {
        let ids = SequentialIDGenerator()
        let counter = CompositionTests.CompileCounter()
        let state = await Composition.make(
            CompositionTests.inputs(paths, ids: ids, copyFolders: copyFolders, compileRules: CompositionTests.counting(counter))
        )
        return Fixture(composition: try CompositionTests.ready(state), paths: paths, ids: ids, counter: counter)
    }

    private static let words: @MainActor (String, Int) -> String = { title, number in "\(title) (\(number))" }

    private static func list(_ fixture: Fixture) -> CVListViewModel {
        fixture.composition.screens.makeCVList(untitled: "Untitled", numbered: words)
    }

    private static func editor(_ fixture: Fixture, _ start: EditorStart) -> EditorViewModel {
        fixture.composition.screens.makeEditor(start: start, copyTitle: { "Copy of \($0)" })
    }

    private static func store(_ fixture: Fixture) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: fixture.paths.store.path)) ?? [])
            .filter { $0.hasSuffix(".cv.json") }.sorted()
    }

    private static func writeSamples(_ fixture: Fixture, count: Int) async throws {
        try FileManager.default.createDirectory(at: fixture.samples, withIntermediateDirectories: true)
        let writer = FileCVRepository(directory: fixture.samples, clock: SteppingClock())
        for index in 1...count {
            let id = CVID(UUID(uuidString: "5A5A5A5A-0000-0000-0000-00000000000\(index)")!)
            _ = try await writer.create(FixtureCV.full(id: id))
        }
    }

    private static func typed(_ editor: EditorViewModel, title: String) {
        var content = editor.content
        content.title = title
        content.fullName = "Ada Lovelace"
        editor.content = content
    }

    @Test("The factory is the composition's one instance")
    func oneInstance() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }

        #expect(fixture.composition.screens === fixture.composition.screens)
    }

    @Test("A CV stored through the composition's repository is a row of the list, and a rename reaches the file")
    func list() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        _ = try await fixture.composition.repository.create(FixtureCV.full())
        let list = Self.list(fixture)

        await list.load()

        #expect(list.rows.count == 1)
        let row = try #require(list.rows.first)
        await list.rename(row.reference, to: "Renamed by the list")
        let file = try #require(Self.store(fixture).first)
        let text = try String(contentsOf: fixture.paths.store.appendingPathComponent(file), encoding: .utf8)
        #expect(text.contains("Renamed by the list"))
    }

    @Test("The shell's navigation model starts with the list and follows the rows the list reads")
    func shell() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        _ = try await fixture.composition.repository.create(FixtureCV.full())
        let list = Self.list(fixture)
        await list.load()
        let row = try #require(list.rows.first)

        let shell = fixture.composition.screens.makeShell()
        #expect(shell.selection == nil)
        shell.open(.stored(row.reference))
        shell.reconcile(with: list.rows)
        #expect(shell.selection == row.reference)
        shell.reconcile(with: [])
        #expect(shell.selection == nil)
    }

    @Test("On an empty store the first run offers the examples, then blank, and no import while the app has no import screen")
    func firstRunWithExamples() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        try await Self.writeSamples(fixture, count: 2)
        let firstRun = fixture.composition.screens.makeFirstRun()

        await firstRun.load()

        #expect(firstRun.state == .firstRun)
        guard firstRun.entries.count == 2, case .examples(let examples) = firstRun.entries[0] else {
            Issue.record("expected the examples, then blank, got \(firstRun.entries)")
            return
        }
        #expect(examples.count == 2)
        #expect(firstRun.entries.last == .blank)
    }

    @Test("Without a Samples folder the first run says the examples are unavailable and still offers blank")
    func firstRunWithoutExamples() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        let firstRun = fixture.composition.screens.makeFirstRun()

        await firstRun.load()

        #expect(firstRun.entries == [.examplesIssue(.unavailable), .blank])
    }

    @Test("Blank and an example give a draft under an id of the composition's source, and store nothing")
    func startsAreDrafts() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        try await Self.writeSamples(fixture, count: 1)
        let firstRun = fixture.composition.screens.makeFirstRun()
        await firstRun.load()
        guard case .examples(let examples)? = firstRun.entries.first(where: { if case .examples = $0 { true } else { false } }) else {
            Issue.record("expected the examples")
            return
        }
        let example = StartChoice.example(examples[0])

        let blank = firstRun.start(.blank)
        let fromExample = firstRun.start(example)

        guard case .draft(let blankDraft)? = blank, case .draft(let exampleDraft)? = fromExample else {
            Issue.record("expected two drafts, got \(String(describing: blank)) and \(String(describing: fromExample))")
            return
        }
        #expect(Self.store(fixture).isEmpty)
        // Both drafts took their id from the composition's source: the next id it gives is the third
        let third = fixture.composition.ids.next()
        #expect(third == CVID(UUID(uuidString: "00000000-0000-0000-0000-000000000003")!))
        await Self.store(draft: blankDraft, fixture, expectedID: "00000000-0000-0000-0000-000000000001")
        await Self.store(draft: exampleDraft, fixture, expectedID: "00000000-0000-0000-0000-000000000002")
    }

    /// Opens an editor on the draft, types, writes, and checks the stored CV carries the id the draft was given.
    private static func store(draft: CVDraft, _ fixture: Fixture, expectedID: String, sourceLocation: SourceLocation = #_sourceLocation) async {
        let editor = Self.editor(fixture, .draft(draft))
        await editor.load()
        typed(editor, title: "Draft \(expectedID.suffix(1))")
        await editor.saveNow()
        let names = Self.store(fixture)
        #expect(names.contains(expectedID.uppercased() + ".cv.json") || names.contains(expectedID + ".cv.json"),
                "the store holds \(names)", sourceLocation: sourceLocation)
    }

    @Test("The reference of a row opens that CV in the editor")
    func editorStored() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        _ = try await fixture.composition.repository.create(FixtureCV.full())
        let list = Self.list(fixture)
        await list.load()
        let reference = try #require(list.rows.first?.reference)
        let editor = Self.editor(fixture, .stored(reference))

        await editor.load()

        #expect(editor.opening == .open)
        #expect(editor.content.fullName == FixtureCV.full().personal.fullName)
    }

    @Test("A blank editor and a draft editor store what is typed, and the first run is then returning")
    func editorsStore() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        let firstRun = fixture.composition.screens.makeFirstRun()
        await firstRun.load()
        let draftEditor: EditorViewModel
        guard case .draft(let draft)? = firstRun.start(.blank) else {
            Issue.record("expected a draft")
            return
        }
        draftEditor = Self.editor(fixture, .draft(draft))
        let blankEditor = Self.editor(fixture, .blank)

        for editor in [draftEditor, blankEditor] {
            await editor.load()
            Self.typed(editor, title: "Typed")
            await editor.saveNow()
        }

        #expect(try await fixture.composition.repository.list().cvs.count == 2)
        let again = fixture.composition.screens.makeFirstRun()
        await again.load()
        #expect(again.state == .returning)
    }

    @Test("A CV an editor saved is a row of a list that loads afterwards")
    func sharedStore() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        let editor = Self.editor(fixture, .blank)
        await editor.load()
        Self.typed(editor, title: "Shared")
        await editor.saveNow()
        let list = Self.list(fixture)

        await list.load()

        #expect(list.rows.count == 1)
    }

    @Test("A list that loads while an editor holds unwritten text reads the store after the editor wrote it")
    func listWaitsForEditors() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        let editor = Self.editor(fixture, .blank)
        await editor.load()
        Self.typed(editor, title: "Unwritten")
        let list = Self.list(fixture)

        await list.load()

        #expect(list.rows.count == 1, "the pause of the autosave has not passed, yet the row is there")
        withExtendedLifetime(editor) {}
    }

    /// Holds one write, the n-th (a `create` or an `update`), at a gate the test opens, so that what the main actor does
    /// meanwhile is deterministic. The other writes pass, and are counted.
    private actor WriteGate {
        private let holding: Int
        private var calls = 0
        private var reached: CheckedContinuation<Void, Never>?
        private var release: CheckedContinuation<Void, Never>?
        private var isReached = false
        private var isOpen = false

        init(holding call: Int) {
            holding = call
        }

        /// How many writes have come to the gate.
        var count: Int { calls }

        func hold() async {
            calls += 1
            guard calls == holding else { return }
            isReached = true
            reached?.resume()
            reached = nil
            guard !isOpen else { return }
            await withCheckedContinuation { release = $0 }
        }

        func waitReached() async {
            guard !isReached else { return }
            await withCheckedContinuation { reached = $0 }
        }

        func open() {
            isOpen = true
            release?.resume()
            release = nil
        }
    }

    /// The in-memory repository whose writes, `create` and `update`, go through the gate.
    private struct GatedRepository: CVRepository {
        let inner: InMemoryCVRepository
        let gate: WriteGate

        func create(_ cv: CV) async throws(RepositoryError) -> CV {
            await gate.hold()
            return try await inner.create(cv)
        }
        func update(_ cv: CV) async throws(RepositoryError) -> CV {
            await gate.hold()
            return try await inner.update(cv)
        }
        func load(_ id: CVID) async throws(RepositoryError) -> CV { try await inner.load(id) }
        func list() async throws(RepositoryError) -> CVListing { try await inner.list() }
        func delete(_ id: CVID, revision: Int) async throws(RepositoryError) { try await inner.delete(id, revision: revision) }
    }

    @Test("An editor made while the list waits for an earlier editor's write is stored too before the list reads")
    func listWaitsForEditorsMadeMeanwhile() async throws {
        let gate = WriteGate(holding: 1)
        let factory = ScreenFactory(
            repository: GatedRepository(inner: InMemoryCVRepository(), gate: gate),
            samples: InMemorySampleCVSource([]), ids: SequentialIDGenerator(), clock: SteppingClock(),
            editorClock: ManualClock(), importer: NoImporter(), importFiles: NoImportFiles(), exporter: NoExporter(),
            lookOptions: FixedLookOptions(), languages: []
        )
        let first = factory.makeEditor(start: .blank, copyTitle: { $0 })
        await first.load()
        Self.typed(first, title: "First")
        let list = factory.makeCVList(untitled: "Untitled", numbered: Self.words)
        let loading = Task { @MainActor in await list.load() }
        await gate.waitReached()
        let second = factory.makeEditor(start: .blank, copyTitle: { $0 })
        await second.load()
        Self.typed(second, title: "Second")

        await gate.open()
        await loading.value

        #expect(Set(list.rows.map(\.label)) == ["First", "Second"])
        withExtendedLifetime((first, second)) {}
    }

    @Test("An edit made after an editor's turn in the list's wait is not waited for, and shows on the list's next load")
    func listShowsALaterEditOnItsNextLoad() async throws {
        let gate = WriteGate(holding: 2)
        let factory = ScreenFactory(
            repository: GatedRepository(inner: InMemoryCVRepository(), gate: gate),
            samples: InMemorySampleCVSource([]), ids: SequentialIDGenerator(), clock: SteppingClock(),
            editorClock: ManualClock(), importer: NoImporter(), importFiles: NoImportFiles(), exporter: NoExporter(),
            lookOptions: FixedLookOptions(), languages: []
        )
        let first = factory.makeEditor(start: .blank, copyTitle: { $0 })
        await first.load()
        Self.typed(first, title: "First")
        let second = factory.makeEditor(start: .blank, copyTitle: { $0 })
        await second.load()
        Self.typed(second, title: "Second")
        let list = factory.makeCVList(untitled: "Untitled", numbered: Self.words)
        let loading = Task { @MainActor in await list.load() }
        await gate.waitReached()
        // The first editor has stored at its turn, and the second one's write is held: the person edits the first.
        Self.typed(first, title: "First, edited")

        await gate.open()
        await loading.value

        // The edit came after the first editor's turn, so the list does not wait for it, and the autosave's pause has not
        // passed: the list shows what the first editor stored at its turn
        #expect(Set(list.rows.map(\.label)) == ["First", "Second"])
        await list.load()
        #expect(Set(list.rows.map(\.label)) == ["First, edited", "Second"])
        withExtendedLifetime((first, second)) {}
    }

    @Test("The list's wait stores an editor once and does not chase an edit made while that write runs", .timeLimit(.minutes(1)))
    func listDoesNotChaseTyping() async throws {
        let gate = WriteGate(holding: 1)
        let factory = ScreenFactory(
            repository: GatedRepository(inner: InMemoryCVRepository(), gate: gate),
            samples: InMemorySampleCVSource([]), ids: SequentialIDGenerator(), clock: SteppingClock(),
            editorClock: ManualClock(), importer: NoImporter(), importFiles: NoImportFiles(), exporter: NoExporter(),
            lookOptions: FixedLookOptions(), languages: []
        )
        let editor = factory.makeEditor(start: .blank, copyTitle: { $0 })
        await editor.load()
        Self.typed(editor, title: "First")
        let list = factory.makeCVList(untitled: "Untitled", numbered: Self.words)
        let loading = Task { @MainActor in await list.load() }
        await gate.waitReached()
        // The editor's write is held: the person goes on typing while it runs
        Self.typed(editor, title: "First, edited")

        await gate.open()
        await loading.value

        #expect(list.rows.map(\.label) == ["First"])
        #expect(await gate.count == 1, "the list's wait wrote once")
        await list.load()
        #expect(list.rows.map(\.label) == ["First, edited"])
        withExtendedLifetime(editor) {}
    }

    @Test("The factory does not keep an editor alive")
    func registryIsWeak() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        weak var released: EditorViewModel?
        do {
            let editor = Self.editor(fixture, .blank)
            await editor.load()
            released = editor
        }
        let list = Self.list(fixture)

        await list.load()

        #expect(released == nil)
    }

    // MARK: Import

    /// Waits until the screen's import has ended, however it ended.
    private static func ended(_ screen: ImportViewModel) async {
        for await importing in Observations({ screen.status == .importing }) where !importing { break }
    }

    /// A folder of the composition's temporary folder, made empty.
    private static func folder(_ name: String, in paths: AppPaths) throws -> URL {
        let folder = paths.temporary.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Bytes that are no PDF: the real import reads them and fails.
    private static func junk(named name: String, in folder: URL) throws -> URL {
        let file = folder.appendingPathComponent(name)
        try Data("not a PDF".utf8).write(to: file)
        return file
    }

    @Test("An import screen made by the factory reads a pasted text into a draft", .timeLimit(.minutes(1)))
    func importOfAText() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        let screen = fixture.composition.screens.makeImport()
        screen.paste(["""
        Ada Lovelace
        ada@example.com

        Experience
        Analyst, Example Engines, 2019 – 2024
        Wrote the first programs for the engine.

        Education
        BSc Mathematics, Example University, 2015 – 2018
        """])

        screen.importText()
        await Self.ended(screen)

        #expect(screen.status == .ready)
        guard case .draft? = screen.result?.start else {
            Issue.record("expected a draft, got \(String(describing: screen.result?.start))")
            return
        }
        #expect(Self.store(fixture).isEmpty, "an import stores nothing until the person saves")
    }

    @Test("A file in a copy folder is deleted after its import", .timeLimit(.minutes(1)))
    func importDeletesACopy() async throws {
        let paths = CompositionTests.paths()
        let inbox = try Self.folder("app.example-Inbox", in: paths)
        let fixture = try await Self.fixture(paths, copyFolders: [inbox])
        defer { fixture.clean() }
        let copy = try Self.junk(named: "cv.pdf", in: inbox)
        let screen = fixture.composition.screens.makeImport()

        screen.importFile(at: copy)
        await Self.ended(screen)

        #expect(screen.status == .failed(.unreadable))
        #expect(!FileManager.default.fileExists(atPath: copy.path), "the system's copy is deleted")
        #expect(FileManager.default.fileExists(atPath: inbox.path), "the copy folder stays")
    }

    @Test("A file outside the copy folders stays after its import", .timeLimit(.minutes(1)))
    func importKeepsAChosenFile() async throws {
        let paths = CompositionTests.paths()
        let inbox = try Self.folder("app.example-Inbox", in: paths)
        let chosen = try Self.folder("Files", in: paths)
        let fixture = try await Self.fixture(paths, copyFolders: [inbox])
        defer { fixture.clean() }
        let file = try Self.junk(named: "cv.pdf", in: chosen)
        let screen = fixture.composition.screens.makeImport()

        screen.importFile(at: file)
        await Self.ended(screen)

        #expect(screen.status == .failed(.unreadable))
        #expect(FileManager.default.fileExists(atPath: file.path), "a file the person chose is theirs")
    }

    @Test("The rules are compiled once, also after every factory was used")
    func rulesCompiledOnce() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        _ = try await fixture.composition.repository.create(FixtureCV.full())
        let list = Self.list(fixture)

        await list.load()
        await fixture.composition.screens.makeFirstRun().load()
        let editor = Self.editor(fixture, .blank)
        await editor.load()
        _ = fixture.composition.screens.makeImport()
        await fixture.composition.screens.makeLook(for: try #require(list.rows.first?.reference)).load()
        _ = try Self.sheet(fixture, editor)

        #expect(fixture.counter.calls == 1)
    }

    // MARK: Look and export

    private static func sheet(_ fixture: Fixture, _ editor: EditorViewModel) throws -> ExportSheetViewModel? {
        fixture.composition.screens.makeExportSheet(
            for: editor, appLanguage: try #require(ExportLanguage("en")), fileNamePattern: { _ in "CV %@" },
            onLanguageChosen: { _ in }
        )
    }

    /// The only CV of the store, stored with the look `design` keeps, and its reference.
    private static func storedCV(_ fixture: Fixture, design: DesignChoice?) async throws -> CVReference {
        var cv = FixtureCV.full()
        cv.choose(design: design)
        _ = try await fixture.composition.repository.create(cv)
        let list = Self.list(fixture)
        await list.load()
        return try #require(list.rows.first?.reference)
    }

    /// The layout of the PDF an export sheet makes of the CV, through an editor that opens it.
    private static func exported(_ fixture: Fixture, _ reference: CVReference) async throws -> PDFLayout {
        let editor = Self.editor(fixture, .stored(reference))
        await editor.load()
        let sheet = try #require(try Self.sheet(fixture, editor))
        sheet.start()
        for await exporting in Observations({ sheet.status == .exporting }) where !exporting { break }
        let pdf = try #require(sheet.document?.pdf, "the export ended with \(sheet.status)")
        return try #require(fixture.composition.inspector.layout(of: pdf))
    }

    /// Chooses `design` in a look picker and applies it.
    private static func choose(_ fixture: Fixture, _ reference: CVReference, design: String) async throws {
        let look = fixture.composition.screens.makeLook(for: reference)
        await look.load()
        look.choose(design: design)
        await look.apply()
        try #require(look.status == .applied)
    }

    @Test("A look picker offers the installed designs by their codes, and shows the default design for a CV that keeps none")
    func lookOffersTheInstalledDesigns() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        let reference = try await Self.storedCV(fixture, design: nil)
        let look = fixture.composition.screens.makeLook(for: reference)

        await look.load()

        #expect(look.status == .ready)
        #expect(look.choices.designs.map(\.id) == ["minimal", "modern", "professional"])
        #expect(look.choices.designs.map(\.nameCode) == ["design.minimal", "design.modern", "design.professional"])
        #expect(look.shown.design == "professional")
    }

    @Test("No export sheet is made for an editor that has not loaded its CV, and one is once it has")
    func sheetNeedsALoadedEditor() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        let editor = Self.editor(fixture, .blank)

        #expect(try Self.sheet(fixture, editor) == nil)
        await editor.load()
        #expect(try Self.sheet(fixture, editor) != nil)
    }

    @Test("An export sheet offers the languages of the bundled headings")
    func sheetOffersTheBundledLanguages() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        let editor = Self.editor(fixture, .blank)
        await editor.load()

        let sheet = try #require(try Self.sheet(fixture, editor))

        let bundled = try fixture.composition.headings.supportedLanguages()
        #expect(bundled.isEmpty == false)
        #expect(Set(sheet.offeredLanguages.map(\.tag)) == Set(bundled.compactMap(ExportLanguage.init).map(\.tag)))
    }

    @Test("The export sheet waits 250 ms after the last change, as in version 1")
    func exportPause() {
        #expect(ScreenFactory.exportPause == .milliseconds(250))
    }

    @Test("A design chosen in the look picker changes the exported PDF, and a CV that keeps none exports with the default", .timeLimit(.minutes(1)))
    func designChoiceChangesThePDF() async throws {
        let fixture = try await Self.fixture()
        defer { fixture.clean() }
        let reference = try await Self.storedCV(fixture, design: nil)

        let none = try await Self.exported(fixture, reference)
        try await Self.choose(fixture, reference, design: "minimal")
        let minimal = try await Self.exported(fixture, reference)
        try await Self.choose(fixture, reference, design: "professional")
        let professional = try await Self.exported(fixture, reference)

        #expect(minimal != none)
        #expect(professional == none)
    }
}
