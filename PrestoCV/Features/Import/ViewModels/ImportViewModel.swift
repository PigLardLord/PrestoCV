import Combine
import Foundation
import PrestoCVImporting

/// Reads the bytes of a file the person chose, within a size, from wherever the system lets the app read it, and lets
/// the file go once the import is done with it.
protocol ImportFileReading: Sendable {
    func read(_ url: URL) async throws -> Data
    /// The import is done with the file, with a CV or without one.
    func release(_ url: URL)
}

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
/// holds no rule of its own: the import reads, the mapper builds the CV, and the editor opens and stores it.
@MainActor
final class ImportViewModel: ObservableObject {

    /// The text to import: pasted, or typed.
    @Published var text = ""
    @Published private(set) var isImporting = false
    @Published private(set) var failure: ImportFailure?
    /// The CV read from the text or the file, not stored yet: the editor opens it for review and stores it as it is.
    @Published private(set) var imported: ImportedDraft?

    private let importer: ImportCV
    private let mapper: ImportedCVMapper
    private let fileReader: any ImportFileReading
    private var importing: Task<Void, Never>?
    /// The file being read, from the moment it is handed over until the import is done with it.
    private var importingFile: URL?

    init(importer: ImportCV, mapper: ImportedCVMapper, fileReader: any ImportFileReading) {
        self.importer = importer
        self.mapper = mapper
        self.fileReader = fileReader
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

    /// Imports the PDF the person chose in Files, or opened in the app, in a task of the screen's own: the task that
    /// hands the file over may end, as the file it was given is cleared, long before the reading does. Nothing of the
    /// file is kept, and the file is let go only once the import is done with it.
    /// - Returns: The import's task, or nil when another import is running: the file is let go unread, unless it is the
    ///   file being read, which that import lets go itself.
    @discardableResult
    func importFile(at url: URL) -> Task<Void, Never>? {
        guard !isImporting else {
            if url.resolvedFileURL != importingFile?.resolvedFileURL {
                fileReader.release(url)
            }
            return nil
        }
        importingFile = url
        return start {
            defer {
                self.importingFile = nil
                self.fileReader.release(url)
            }
            let data: Data
            do {
                data = try await self.fileReader.read(url)
            } catch let error as ImportError {
                self.failure = ImportFailure(error)
                return
            } catch {
                self.failure = .fileNotRead
                return
            }
            await self.read(data)
        }
    }

    /// Imports a PDF the person copied, in Files for example, and pasted.
    /// - Returns: The import's task, or nil when another import is running.
    @discardableResult
    func importPDF(_ data: Data) -> Task<Void, Never>? {
        guard !isImporting else { return nil }
        return start { await self.read(data) }
    }

    /// The screen went away: the import running stops, with nothing to tell.
    func cancelImport() {
        importing?.cancel()
    }

    private func start(_ work: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        isImporting = true
        failure = nil
        let task = Task {
            await work()
            self.isImporting = false
        }
        importing = task
        return task
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
