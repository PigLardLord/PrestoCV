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
        readFile: @escaping ImportFileReader = { _ in Data([1]) }
    ) -> ImportViewModel {
        ImportViewModel(importer: ImportCV(pdfReader: reader, limits: .standard), mapper: ImportedCVMapper(), readFile: readFile)
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
            importer: ImportCV(pdfReader: ScriptedPDFReader(), limits: ImportLimits(maximumPDFBytes: 10, maximumPages: 1, maximumCharacters: 20)),
            mapper: ImportedCVMapper(), readFile: { _ in Data() }
        )
        viewModel.text = "Giulia Bianchi, Infermiera a Torino"
        viewModel.importText()

        #expect(viewModel.failure == .tooLarge)
        #expect(viewModel.failure?.messageKey.localized != viewModel.failure?.messageKey)
    }

    @Test("A PDF from Files is read and imported, and the screen is busy meanwhile only")
    func pdfFromFiles() async {
        let viewModel = makeViewModel(reader: ScriptedPDFReader(layout: .pages([page])))
        await viewModel.importFile(at: URL(fileURLWithPath: "/tmp/cv.pdf"))

        #expect(!viewModel.isImporting)
        #expect(viewModel.failure == nil)
        #expect(viewModel.imported?.cv.personalInfo.name == "Lena Hartmann")
        #expect(viewModel.imported?.cv.relevant_experience.first?.company == "Beispiel GmbH")
    }

    @Test("A pasted PDF is imported as a chosen one is")
    func pastedPDF() async {
        let viewModel = makeViewModel(reader: ScriptedPDFReader(layout: .pages([page])))
        await viewModel.importPDF(Data([1]))

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
            readFile: { _ in
                if let fileError { throw fileError }
                return Data([1])
            }
        )
        await viewModel.importFile(at: URL(fileURLWithPath: "/tmp/cv.pdf"))

        #expect(viewModel.failure == expected)
        #expect(viewModel.imported == nil)
        #expect(expected.messageKey.localized != expected.messageKey, "\(expected.messageKey) is missing from the string catalog")
    }

    @Test("A file the system does not let the app read is told apart from a PDF that cannot be read")
    func fileNotRead() async {
        let viewModel = makeViewModel(readFile: { _ in throw UnreadableFile() })
        await viewModel.importFile(at: URL(fileURLWithPath: "/tmp/cv.pdf"))

        #expect(viewModel.failure == .fileNotRead)
        viewModel.clearFailure()
        #expect(viewModel.failure == nil)
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

@Suite("ChosenFileReader - a PDF from Files or from Open in PrestoCV, read once and not kept")
struct ChosenFileReaderTests {

    private func file(in folder: URL, bytes: Int) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("cv.pdf")
        try Data(repeating: 0x25, count: bytes).write(to: url)
        return url
    }

    @Test("The copy the system leaves in the Inbox is deleted once read; a file chosen in Files is left alone")
    func inboxCopyIsDeleted() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let inbox = root.appendingPathComponent("Inbox")
        let reader = ChosenFileReader(maximumBytes: 100, inbox: inbox)

        let copy = try file(in: inbox, bytes: 10)
        #expect(try await reader.read(copy).count == 10)
        #expect(!FileManager.default.fileExists(atPath: copy.path))

        let chosen = try file(in: root.appendingPathComponent("Files"), bytes: 10)
        #expect(try await reader.read(chosen).count == 10)
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
