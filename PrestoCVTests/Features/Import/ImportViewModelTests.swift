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

    /// An Inbox with the copy of a PDF opened in the app, as the system leaves it.
    private func inboxCopy() throws -> (root: URL, inbox: URL, copy: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inbox = root.appendingPathComponent("Inbox")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let copy = inbox.appendingPathComponent("cv.pdf")
        try Data([1]).write(to: copy)
        return (root, inbox, copy)
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

    @Test("A PDF opened in the app is read to the end, slow as it may be, after the pending file is cleared; its Inbox copy goes only then")
    func openedInTheApp() async throws {
        let (root, inbox, copy) = try inboxCopy()
        defer { try? FileManager.default.removeItem(at: root) }
        let sleeps = HeldSleeps()
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: SlowPDFReader(sleeps: sleeps, layout: .pages([page])), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: ChosenFileReader(maximumBytes: 100, inbox: inbox)
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

    @Test("A PDF opened in the app that holds no CV lets its Inbox copy go too")
    func openedInTheAppWithoutText() async throws {
        let (root, inbox, copy) = try inboxCopy()
        defer { try? FileManager.default.removeItem(at: root) }
        let viewModel = ImportViewModel(
            importer: ImportCV(pdfReader: ScriptedPDFReader(error: ImportError.noText), limits: .standard),
            mapper: ImportedCVMapper(),
            fileReader: ChosenFileReader(maximumBytes: 100, inbox: inbox)
        )

        await viewModel.importFile(at: copy)?.value

        #expect(viewModel.failure == .scan)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
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

@Suite("ChosenFileReader - a PDF from Files or from Open in PrestoCV, read once and not kept")
struct ChosenFileReaderTests {

    private func file(in folder: URL, bytes: Int) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("cv.pdf")
        try Data(repeating: 0x25, count: bytes).write(to: url)
        return url
    }

    @Test("The copy the system leaves in the Inbox is deleted once let go, not when read; a file chosen in Files is left alone")
    func inboxCopyIsDeleted() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let inbox = root.appendingPathComponent("Inbox")
        let reader = ChosenFileReader(maximumBytes: 100, inbox: inbox)

        let copy = try file(in: inbox, bytes: 10)
        #expect(try await reader.read(copy).count == 10)
        #expect(FileManager.default.fileExists(atPath: copy.path))
        reader.release(copy)
        #expect(!FileManager.default.fileExists(atPath: copy.path))

        let chosen = try file(in: root.appendingPathComponent("Files"), bytes: 10)
        #expect(try await reader.read(chosen).count == 10)
        reader.release(chosen)
        #expect(FileManager.default.fileExists(atPath: chosen.path))
    }

    @Test("A file over the size is refused before it is read")
    func tooLarge() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let reader = ChosenFileReader(maximumBytes: 100, inbox: root.appendingPathComponent("Inbox"))

        await #expect(throws: ImportError.tooLarge) { try await reader.read(try file(in: root, bytes: 101)) }
    }
}
