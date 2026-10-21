import Testing
import Foundation
@testable import PrestoCV
import PrestoCVImporting

@MainActor
@Suite("ImportViewModel - the screen that reads a CV the person already has")
struct ImportViewModelTests {

    private struct UnreadableFile: Error {}

    private func makeViewModel(
        reader: ScriptedPDFReader = ScriptedPDFReader(),
        fileReader: ScriptedFileReader = ScriptedFileReader()
    ) -> ImportViewModel {
        ImportViewModel(importer: ImportCV(pdfReader: reader, limits: .standard), mapper: ImportedCVMapper(), fileReader: fileReader)
    }

    /// A PDF page with a name, a title and a job, as a reader sees it.
    private var page: ExtractedPage {
        var words: [ExtractedWord] = []
        func put(_ text: String, x: Double, y: Double, size: Double = 10) {
            var cursor = x
            for word in text.split(separator: " ") {
                let width = Double(word.count) * size * 0.5
                words.append(ExtractedWord(text: String(word), frame: Rect(x: cursor, y: y, width: width, height: size), fontSize: size, isBold: size > 12))
                cursor += width + size * 0.3
            }
        }
        put("Lena Hartmann", x: 50, y: 50, size: 20)
        put("Elektrikerin", x: 50, y: 80)
        put("Berufserfahrung", x: 50, y: 120, size: 13)
        put("03/2019 – heute", x: 50, y: 140)
        put("Elektrikerin, Beispiel GmbH, Leipzig", x: 200, y: 140)
        return ExtractedPage(width: 595, height: 842, words: words)
    }

    @Test("A pasted CV opens as an unsaved CV, with its review")
    func pastedText() {
        let viewModel = makeViewModel()
        viewModel.paste(["Giulia Bianchi\nInfermiera\n\nEsperienza\nInfermiera | Ospedale Esempio | Torino | 03/2019 – oggi"])

        #expect(viewModel.canImportText)
        viewModel.importText()

        #expect(viewModel.failure == nil)
        #expect(viewModel.imported?.cv.personalInfo.name == "Giulia Bianchi")
        #expect(viewModel.imported?.cv.relevant_experience.first?.company == "Ospedale Esempio")
    }

    @Test("Pasting takes the place of the text; pasting nothing changes nothing")
    func pasting() {
        let viewModel = makeViewModel()
        viewModel.text = "old"
        viewModel.paste(["first line", "second line"])
        #expect(viewModel.text == "first line\nsecond line")

        viewModel.paste([])
        #expect(viewModel.text == "first line\nsecond line")
    }

    @Test("There is nothing to import from a text without letters")
    func noLetters() {
        let viewModel = makeViewModel()
        viewModel.text = "--- \n 2019"

        #expect(!viewModel.canImportText)
        viewModel.importText()
        #expect(viewModel.imported == nil)
    }

    @Test("A text over the limit is refused with its message")
    func tooLong() {
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: ScriptedPDFReader(), limits: ImportLimits(
                maximumPDFBytes: 10, maximumPages: 1, maximumCharacters: 20,
                maximumWords: 10, maximumLines: 10, maximumCells: 10, maximumAnalysisSteps: 1_000
            )),
            mapper: ImportedCVMapper(), fileReader: ScriptedFileReader()
        )
        viewModel.text = "Giulia Bianchi, Infermiera a Torino"
        viewModel.importText()

        #expect(viewModel.failure == .tooLarge)
        #expect(viewModel.failure?.messageKey.localized != viewModel.failure?.messageKey)
    }

    @Test("A PDF from Files is read and imported, and the screen is busy meanwhile only")
    func pdfFromFiles() async {
        let viewModel = makeViewModel(reader: ScriptedPDFReader(layout: .pages([page])))
        await viewModel.importFile(at: URL(fileURLWithPath: "/tmp/cv.pdf"))?.value

        #expect(!viewModel.isImporting)
        #expect(viewModel.failure == nil)
        #expect(viewModel.imported?.cv.personalInfo.name == "Lena Hartmann")
        #expect(viewModel.imported?.cv.relevant_experience.first?.company == "Beispiel GmbH")
    }

    @Test("A pasted PDF is imported as a chosen one is")
    func pastedPDF() async {
        let viewModel = makeViewModel(reader: ScriptedPDFReader(layout: .pages([page])))
        await viewModel.importPDF(Data([1]))?.value

        #expect(viewModel.imported?.cv.personalInfo.name == "Lena Hartmann")
    }

    @Test("Each failure has its message: a scan, a protected PDF, a file that is no PDF, a file that cannot be read, one too large",
          arguments: [
              (ImportError.noText, nil, ImportFailure.scan),
              (ImportError.encrypted, nil, .encrypted),
              (ImportError.unreadable, nil, .unreadable),
              (nil, ImportError.tooLarge, .tooLarge),
              (nil, ImportError.empty, .empty),
          ] as [(ImportError?, ImportError?, ImportFailure)])
    func failures(readerError: ImportError?, fileError: ImportError?, expected: ImportFailure) async {
        let viewModel = makeViewModel(
            reader: ScriptedPDFReader(error: readerError),
            fileReader: ScriptedFileReader(error: fileError)
        )
        await viewModel.importFile(at: URL(fileURLWithPath: "/tmp/cv.pdf"))?.value

        #expect(viewModel.failure == expected)
        #expect(viewModel.imported == nil)
        #expect(expected.messageKey.localized != expected.messageKey, "\(expected.messageKey) is missing from the string catalog")
    }

    @Test("A file the system does not let the app read is told apart from a PDF that cannot be read")
    func fileNotRead() async {
        let viewModel = makeViewModel(fileReader: ScriptedFileReader(error: UnreadableFile()))
        await viewModel.importFile(at: URL(fileURLWithPath: "/tmp/cv.pdf"))?.value

        #expect(viewModel.failure == .fileNotRead)
        viewModel.clearFailure()
        #expect(viewModel.failure == nil)
    }

    @Test("A PDF opened in the app is read to the end, slow as it may be, after the pending file is cleared; its copy goes only then")
    func openedInTheApp() async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let copy = try fixture.copyInTemporaryInbox()
        let sleeps = HeldSleeps()
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: SlowPDFReader(sleeps: sleeps, layout: .pages([page])), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: fixture.reader()
        )
        let router = AppRouter(isAIShipped: false)
        router.openImport(of: copy)

        // The screen's task, which SwiftUI cancels as the pending file it is keyed on is cleared
        let screenTask = Task { @MainActor in router.takePendingImportFile().flatMap { viewModel.importFile(at: $0) } }
        screenTask.cancel()
        let importing = try #require(await screenTask.value)
        await sleeps.waitUntilStarted(1)
        #expect(router.pendingImportFile == nil)
        #expect(viewModel.isImporting)
        #expect(FileManager.default.fileExists(atPath: copy.path), "The copy stays while the PDF is read")
        await sleeps.endAll()
        await importing.value

        #expect(viewModel.imported?.cv.personalInfo.name == "Lena Hartmann")
        #expect(!viewModel.isImporting)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("A PDF opened in the app that holds no CV lets its copy go too")
    func openedInTheAppWithoutText() async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let copy = try fixture.copyInTemporaryInbox()
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: ScriptedPDFReader(error: ImportError.noText), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: fixture.reader()
        )

        await viewModel.importFile(at: copy)?.value

        #expect(viewModel.failure == .scan)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("A PDF opened in the app that is over the size lets its copy go, unread")
    func openedInTheAppTooLarge() async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let copy = try fixture.copyInTemporaryInbox(bytes: 101)
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([page])), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: fixture.reader()
        )

        await viewModel.importFile(at: copy)?.value

        #expect(viewModel.failure == .tooLarge)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("A PDF opened in the app whose import is cancelled lets its copy go")
    func openedInTheAppThenCancelled() async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let copy = try fixture.copyInTemporaryInbox()
        let sleeps = HeldSleeps()
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: SlowPDFReader(sleeps: sleeps, layout: .pages([page])), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: fixture.reader()
        )
        let importing = try #require(viewModel.importFile(at: copy))
        await sleeps.waitUntilStarted(1)

        viewModel.cancelImport()
        await importing.value

        #expect(viewModel.imported == nil)
        #expect(viewModel.failure == nil)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("A PDF opened in the app while another import runs is let go unread, and the import running goes on")
    func openedWhileImporting() async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let first = try fixture.copyInTemporaryInbox(named: "first.pdf")
        let second = try fixture.copyInTemporaryInbox(named: "second.pdf")
        let sleeps = HeldSleeps()
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: SlowPDFReader(sleeps: sleeps, layout: .pages([page])), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: fixture.reader()
        )
        let importing = try #require(viewModel.importFile(at: first))
        await sleeps.waitUntilStarted(1)

        #expect(viewModel.importFile(at: second) == nil)

        #expect(!FileManager.default.fileExists(atPath: second.path))
        #expect(FileManager.default.fileExists(atPath: first.path), "The copy of the PDF being read stays")
        await sleeps.endAll()
        await importing.value
        #expect(viewModel.imported?.cv.personalInfo.name == "Lena Hartmann")
        #expect(!FileManager.default.fileExists(atPath: first.path))
    }

    @Test("A PDF opened again while its own import runs is not let go: the import running has still to read it")
    func openedAgainWhileItsImportRuns() async throws {
        let sleeps = HeldSleeps()
        let released = RemovedFiles()
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([page])), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: SlowFileReader(sleeps: sleeps, released: released)
        )
        let copy = URL(fileURLWithPath: "/tmp/Inbox/cv.pdf")
        let importing = try #require(viewModel.importFile(at: copy))
        await sleeps.waitUntilStarted(1)

        #expect(viewModel.importFile(at: copy) == nil)
        #expect(viewModel.importFile(at: URL(fileURLWithPath: "/tmp/Inbox/./cv.pdf")) == nil, "However the path is written")
        #expect(released.urls.isEmpty, "The first read may not have opened the file yet")

        await sleeps.endAll()
        await importing.value
        #expect(viewModel.imported?.cv.personalInfo.name == "Lena Hartmann")
        #expect(released.urls == [copy], "The import lets the file go once, when it is done with it")
    }

    @Test("A PDF opened again through a link to its folder is the PDF being read: its copy stays until that import is done, then goes once",
          arguments: [false, true])
    func openedAgainThroughALink(readThroughTheLink: Bool) async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let copy = try fixture.copyInTemporaryInbox()
        let link = fixture.root.appendingPathComponent("Link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fixture.container)
        let viaLink = link.appendingPathComponent("tmp/\(AppContainerFixture.bundleIdentifier)-Inbox/\(copy.lastPathComponent)")
        let (reading, delivered) = readThroughTheLink ? (viaLink, copy) : (copy, viaLink)
        let removed = RemovedFiles()
        let copies = OpenedFileCopies(container: fixture.container, removeFile: { url in
            removed.add(url)
            try FileManager.default.removeItem(at: url)
        })
        let sleeps = HeldSleeps()
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: SlowPDFReader(sleeps: sleeps, layout: .pages([page])), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: ChosenFileReader(maximumBytes: 100, copies: copies)
        )
        let importing = try #require(viewModel.importFile(at: reading))
        await sleeps.waitUntilStarted(1)

        #expect(viewModel.importFile(at: delivered) == nil)

        #expect(removed.urls.isEmpty, "The import running has still to let the copy go")
        #expect(FileManager.default.fileExists(atPath: copy.path))
        await sleeps.endAll()
        await importing.value
        #expect(viewModel.imported?.cv.personalInfo.name == "Lena Hartmann")
        #expect(removed.urls.count == 1, "The copy goes once, when its import is done")
        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("A PDF opened again once its import is done is a new PDF: it is read and let go")
    func openedAgainAfterItsImport() async throws {
        let sleeps = HeldSleeps()
        let released = RemovedFiles()
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([page])), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: SlowFileReader(sleeps: sleeps, released: released)
        )
        let copy = URL(fileURLWithPath: "/tmp/Inbox/cv.pdf")
        let first = try #require(viewModel.importFile(at: copy))
        await sleeps.waitUntilStarted(1)
        await sleeps.endAll()
        await first.value

        let second = try #require(viewModel.importFile(at: copy))
        await sleeps.waitUntilStarted(2)
        await sleeps.endAll()
        await second.value

        #expect(released.urls == [copy, copy])
    }

    @Test("Leaving the screen stops the import running, with nothing to tell")
    func leavingStopsTheImport() async throws {
        let sleeps = HeldSleeps()
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: SlowPDFReader(sleeps: sleeps, layout: .pages([page])), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: ScriptedFileReader()
        )
        let importing = try #require(viewModel.importPDF(Data([1])))
        await sleeps.waitUntilStarted(1)

        viewModel.cancelImport()
        await importing.value

        #expect(viewModel.imported == nil)
        #expect(viewModel.failure == nil)
        #expect(!viewModel.isImporting)
    }

    @Test("Once the draft opens, coming back to the screen does not open it again")
    func draftOpensOnce() {
        let viewModel = makeViewModel()
        viewModel.text = "Giulia Bianchi\nInfermiera"
        viewModel.importText()
        #expect(viewModel.imported != nil)

        viewModel.draftOpened()

        #expect(viewModel.imported == nil)
        #expect(viewModel.text == "Giulia Bianchi\nInfermiera", "The text stays, to adjust and import again")
    }
}

/// A file reader that hands over a byte, or throws.
struct ScriptedFileReader: ImportFileReading {
    var error: (any Error & Sendable)?

    func read(_ url: URL) async throws -> Data {
        if let error { throw error }
        return Data([1])
    }

    func release(_ url: URL) {}
}

/// A file reader whose reading lasts until the test ends its sleep, as the reading of a slow disk does, and that notes the
/// files it is told to let go.
private struct SlowFileReader: ImportFileReading {
    let sleeps: HeldSleeps
    let released: RemovedFiles

    func read(_ url: URL) async throws -> Data {
        try await sleeps.sleep(for: .seconds(5))
        return Data([1])
    }

    func release(_ url: URL) {
        released.add(url)
    }
}

/// A PDF reader that takes its time, as a long PDF does: it reads once the test ends its sleep, and stops if its task
/// is cancelled meanwhile, as the PDFKit reader does between pages.
private struct SlowPDFReader: PDFTextExtracting {
    let sleeps: HeldSleeps
    let layout: ExtractedLayout

    func layout(ofPDF data: Data, limits: ImportLimits) async throws -> ExtractedLayout {
        try await sleeps.sleep(for: .seconds(5))
        try Task.checkCancellation()
        return layout
    }
}

@Suite("OpenedFileCopies - the copy of a PDF opened in the app goes, wherever the system put it; the person's files stay")
struct OpenedFileCopiesTests {

    @Test("The copy the system leaves in the app, wherever it puts it, is deleted",
          arguments: [AppContainerFixture.Place.temporaryInbox, .documentsInbox])
    func copyIsDeleted(place: AppContainerFixture.Place) throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let copy = try fixture.file(at: place, bytes: 10)

        fixture.copies().release(copy)

        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("A file chosen in Files, outside the app's container, stays")
    func fileOutsideTheContainerStays() throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let chosen = try fixture.file(at: .files, bytes: 10)

        fixture.copies().release(chosen)

        #expect(FileManager.default.fileExists(atPath: chosen.path))
    }

    @Test("A folder beside the container, whose name starts with the container's, is not the container")
    func siblingFolderStays() throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let sibling = try fixture.file(at: .besideTheContainer, bytes: 10)

        fixture.copies().release(sibling)

        #expect(FileManager.default.fileExists(atPath: sibling.path))
    }

    @Test("The container itself is not a copy")
    func containerStays() throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }

        fixture.copies().release(fixture.container)

        #expect(FileManager.default.fileExists(atPath: fixture.container.path))
    }

    @Test("A path that climbs out of the container with .. is outside it")
    func climbingOutStays() throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let chosen = try fixture.file(at: .files, bytes: 10)
        let climbing = fixture.container.appendingPathComponent("tmp/../../Files/\(chosen.lastPathComponent)")

        fixture.copies().release(climbing)

        #expect(FileManager.default.fileExists(atPath: chosen.path))
    }

    @Test("A copy is found in the container whether the path to it goes through a symbolic link or not, as /var is /private/var on a device")
    func containerBehindASymbolicLink() throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let copy = try fixture.file(at: .temporaryInbox, bytes: 10)
        let link = fixture.root.appendingPathComponent("Link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fixture.container)
        let viaLink = link.appendingPathComponent("tmp/\(AppContainerFixture.bundleIdentifier)-Inbox/\(copy.lastPathComponent)")

        fixture.copies().release(viaLink)

        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("A link in the container to a file of the person's leads outside it: the file stays")
    func linkOutOfTheContainerStays() throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let chosen = try fixture.file(at: .files, bytes: 10)
        let folder = fixture.folder(at: .temporaryInbox)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let link = folder.appendingPathComponent("cv.pdf")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: chosen)

        fixture.copies().release(link)

        #expect(FileManager.default.fileExists(atPath: chosen.path))
    }

    @Test("A URL that is no file is not a copy")
    func noFileURLStays() throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let removed = RemovedFiles()
        let copies = OpenedFileCopies(container: fixture.container, removeFile: { removed.add($0) })

        copies.release(URL(string: "https://example.com\(fixture.container.path)/tmp/cv.pdf")!)

        #expect(removed.urls.isEmpty)
    }

    @Test("A copy that cannot be deleted is left, without a word: the next copy of the same name replaces it")
    func failedRemovalIsLeft() throws {
        struct Stuck: Error {}
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let copy = try fixture.copyInTemporaryInbox()
        let copies = OpenedFileCopies(container: fixture.container, removeFile: { _ in throw Stuck() })

        copies.release(copy)

        #expect(FileManager.default.fileExists(atPath: copy.path))
    }
}

@Suite("ChosenFileReader - a PDF from Files or from Open in PrestoCV, read once and not kept")
struct ChosenFileReaderTests {

    @Test("A copy the system left in the app is read as it is, and deleted once let go, not when read")
    func copyIsDeletedOnceLetGo() async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let reader = fixture.reader()
        let copy = try fixture.copyInTemporaryInbox()

        #expect(try await reader.read(copy).count == 10)
        #expect(FileManager.default.fileExists(atPath: copy.path))
        reader.release(copy)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("A file chosen in Files is read and left alone when let go")
    func chosenFileStays() async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let reader = fixture.reader()
        let chosen = try fixture.file(at: .files, bytes: 10)

        #expect(try await reader.read(chosen).count == 10)
        reader.release(chosen)
        #expect(FileManager.default.fileExists(atPath: chosen.path))
    }

    @Test("A file over the size is refused before it is read")
    func tooLarge() async throws {
        let fixture = try AppContainerFixture()
        defer { fixture.remove() }
        let reader = fixture.reader()
        let large = try fixture.file(at: .files, bytes: 101)

        await #expect(throws: ImportError.tooLarge) { try await reader.read(large) }
    }
}

/// The files a test removed, in the order they went.
final class RemovedFiles: @unchecked Sendable {
    private let lock = NSLock()
    private var removed: [URL] = []

    var urls: [URL] {
        lock.withLock { removed }
    }

    func add(_ url: URL) {
        lock.withLock { removed.append(url) }
    }
}

/// The app's container as the system lays it out, in a folder of its own, with the places a file can come from: the
/// folders where the system copies a file opened in the app, and Files, which lies outside the container.
struct AppContainerFixture {
    static let bundleIdentifier = "com.example.app"

    enum Place: CaseIterable {
        /// Where current versions of iOS copy a file opened in the app
        case temporaryInbox
        /// Where earlier versions did
        case documentsInbox
        /// The person's own folders, outside the app's container
        case files
        /// A folder whose name starts with the container's
        case besideTheContainer
    }

    let root: URL
    let container: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        container = root.appendingPathComponent("Container")
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    }

    func folder(at place: Place) -> URL {
        switch place {
        case .temporaryInbox: container.appendingPathComponent("tmp/\(Self.bundleIdentifier)-Inbox")
        case .documentsInbox: container.appendingPathComponent("Documents/Inbox")
        case .files: root.appendingPathComponent("Files")
        case .besideTheContainer: root.appendingPathComponent("Container-backup")
        }
    }

    @discardableResult
    func file(at place: Place, named name: String = "cv.pdf", bytes: Int) throws -> URL {
        let folder = folder(at: place)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try Data(repeating: 0x25, count: bytes).write(to: url)
        return url
    }

    func copyInTemporaryInbox(named name: String = "cv.pdf", bytes: Int = 10) throws -> URL {
        try file(at: .temporaryInbox, named: name, bytes: bytes)
    }

    func copies() -> OpenedFileCopies {
        OpenedFileCopies(container: container, removeFile: { try FileManager.default.removeItem(at: $0) })
    }

    func reader(maximumBytes: Int = 100) -> ChosenFileReader {
        ChosenFileReader(maximumBytes: maximumBytes, copies: copies())
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
