import Combine
import Foundation
import PrestoCVImporting

/// Reads the bytes of a file the person chose, within a size, from wherever the system lets the app read it.
typealias ImportFileReader = @Sendable (URL) async throws -> Data

/// Why an import produced no CV, as the import screen tells it.
enum ImportFailure: Equatable {
    case empty
    case tooLarge
    case tooManyPages
    case encrypted
    case unreadable
    /// A PDF without text: a scan or a photo.
    case scan
    /// The file could not be read.
    case fileNotRead

    var messageKey: String {
        switch self {
        case .empty: return "import.error.empty"
        case .tooLarge: return "import.error.too_large"
        case .tooManyPages: return "import.error.too_many_pages"
        case .encrypted: return "import.error.encrypted"
        case .unreadable: return "import.error.unreadable"
        case .scan: return "import.error.scan"
        case .fileNotRead: return "import.error.file"
        }
    }

    init(_ error: ImportError) {
        switch error {
        case .empty: self = .empty
        case .tooLarge: self = .tooLarge
        case .tooManyPages: self = .tooManyPages
        case .encrypted: self = .encrypted
        case .unreadable: self = .unreadable
        case .noText: self = .scan
        }
    }
}

/// The screen that turns a CV someone already has into a new one: pasted text, or a PDF from Files (ADR 0027). It
/// holds no rule of its own: the import reads, the mapper builds the unsaved CV, and the editor opens it.
@MainActor
final class ImportViewModel: ObservableObject {

    /// The text to import: pasted, or typed.
    @Published var text = ""
    @Published private(set) var isImporting = false
    @Published private(set) var failure: ImportFailure?
    /// The CV read from the text or the file, unsaved: the editor opens it for review.
    @Published private(set) var imported: ImportedDraft?

    private let importer: ImportCV
    private let mapper: ImportedCVMapper
    private let readFile: ImportFileReader

    init(importer: ImportCV, mapper: ImportedCVMapper, readFile: @escaping ImportFileReader) {
        self.importer = importer
        self.mapper = mapper
        self.readFile = readFile
    }

    /// Whether there is text to import, and no import running.
    var canImportText: Bool {
        text.contains(where: \.isLetter) && !isImporting
    }

    /// What the paste button gives: the text on the clipboard takes the place of what was there.
    func paste(_ strings: [String]) {
        let pasted = strings.joined(separator: "\n")
        guard !pasted.isEmpty else { return }
        text = pasted
    }

    func importText() {
        guard canImportText else { return }
        failure = nil
        do {
            imported = mapper.map(try importer.importText(text))
        } catch let error as ImportError {
            failure = ImportFailure(error)
        } catch {
            failure = .unreadable
        }
    }

    /// Imports the PDF the person chose in Files. Nothing of the file is kept.
    func importFile(at url: URL) async {
        guard !isImporting else { return }
        isImporting = true
        failure = nil
        defer { isImporting = false }
        let data: Data
        do {
            data = try await readFile(url)
        } catch let error as ImportError {
            failure = ImportFailure(error)
            return
        } catch {
            failure = .fileNotRead
            return
        }
        await read(data)
    }

    /// Imports a PDF the person copied, in Files for example, and pasted.
    func importPDF(_ data: Data) async {
        guard !isImporting else { return }
        isImporting = true
        failure = nil
        defer { isImporting = false }
        await read(data)
    }

    private func read(_ data: Data) async {
        do {
            imported = mapper.map(try await importer.importPDF(data))
        } catch let error as ImportError {
            failure = ImportFailure(error)
        } catch is CancellationError {
            // The screen went away: nothing to tell
        } catch {
            failure = .unreadable
        }
    }

    func clearFailure() {
        failure = nil
    }

    /// The draft went to the editor: coming back to the screen does not open it again.
    func draftOpened() {
        imported = nil
    }
}
