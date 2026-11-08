import Foundation
import Observation
import PrestoCVWorkflowPorts

/// The import of the CV a person already has: a text typed or pasted, a PDF pasted, or a PDF file they chose (#396).
/// One import runs at a time, in a task of the view model's own. Nothing is stored: the draft goes to the editor, which
/// stores it the first time it writes it (ADR 0027).
@MainActor
@Observable
public final class ImportViewModel {

    /// The text to import, as the person typed or pasted it. A failed import keeps it.
    public var text = ""
    /// Where the text of the import running, failed or ready came from; nil while idle.
    public private(set) var source: ImportSource?
    public private(set) var status: ImportStatus = .idle
    /// The draft of the last import, until the editor opened it.
    public private(set) var result: ImportedDraft?

    /// A text with no letter in it is no CV, and nothing starts while an import runs.
    public var canImportText: Bool { text.contains(where: \.isLetter) && status != .importing }

    // MARK: - State

    @ObservationIgnored private let importer: any CVImporting
    @ObservationIgnored private let files: any ImportFileReading
    @ObservationIgnored private var running: Task<Void, Never>?
    /// Which tasks hold which files. The tasks hold it too, so it outlives the view model until the last task ends.
    @ObservationIgnored private let holds: FileHolds
    /// Counts the intents that start or end an import: a task publishes only while it holds the latest one.
    @ObservationIgnored private var generation = 0

    /// Does no I/O and starts nothing.
    public init(importer: any CVImporting, files: any ImportFileReading) {
        self.importer = importer
        self.files = files
        holds = FileHolds(files)
    }

    // MARK: - Intents

    /// The strings the person pasted, one per line, in place of the text. A paste of nothing changes nothing.
    public func paste(_ strings: [String]) {
        let pasted = strings.joined(separator: "\n")
        guard !pasted.isEmpty else { return }
        text = pasted
    }

    public func importText() {
        guard canImportText else { return }
        let text = text, importer = importer
        start(from: .pasted, reading: nil) { try await importer.importCV(fromText: text) }
    }

    /// A PDF the person pasted, such as one copied in Files: it goes to the import as a PDF, like a file.
    public func importPDF(_ data: Data) {
        guard status != .importing else { return }
        let importer = importer
        start(from: .file, reading: nil) { try await importer.importCV(fromPDF: data) }
    }

    /// A PDF file the person chose or opened in the app. A file is let go once, when no import uses it any more,
    /// however its import ended. One handed over while an import runs is not read; it is let go at once, unless an
    /// import still uses it (the same file, however spelled), which lets it go: nothing of a file is kept (ADR 0027).
    public func importFile(at url: URL) {
        guard status != .importing else {
            holds.refuse(url)
            return
        }
        let importer = importer, files = files
        start(from: .file, reading: url) {
            let data: Data
            do { data = try await files.readPDF(fromFileAt: url) } catch {
                throw Self.readFailure(error)
            }
            try Task.checkCancellation()
            return try await importer.importCV(fromPDF: data)
        }
    }

    /// The import running stops, with nothing to tell; its late result is dropped.
    public func cancel() {
        guard status == .importing else { return }
        running?.cancel()
        running = nil
        generation += 1
        end()
    }

    /// The person read the problem: the screen is ready for another try, with the text kept.
    public func clearProblem() {
        guard case .failed = status else { return }
        end()
    }

    /// The editor opened the draft: coming back to the screen does not open it again.
    public func opened() {
        guard status == .ready else { return }
        result = nil
        end()
    }

    // MARK: - Running

    private func start(from source: ImportSource, reading file: URL?,
                       _ work: @escaping @MainActor () async throws -> ImportOutcome) {
        running?.cancel()
        generation += 1
        let mine = generation
        self.source = source
        let held = file.map { holds.hold($0) }
        result = nil
        status = .importing
        let holds = holds
        running = Task { [weak self] in
            // After the draft or the problem is published, so that the file outlives its own import only.
            defer { if let held { holds.letGo(held) } }
            let ended: Result<ImportOutcome, any Error>
            do { ended = .success(try await work()) } catch { ended = .failure(error) }
            self?.finish(mine, ended, from: source)
        }
    }

    private func finish(_ mine: Int, _ ended: Result<ImportOutcome, any Error>, from source: ImportSource) {
        guard mine == generation else { return }
        running = nil
        switch ended {
        case .success(let outcome):
            result = ImportedDraft(outcome, from: source)
            status = .ready
        case .failure(let failure as ImportFailure):
            status = .failed(ImportProblem(failure))
        case .failure(is CancellationError):
            end()                                          // ADR 0010: cancellation is not a failure
        case .failure:
            status = .failed(.unreadable)
        }
    }

    private func end() {
        status = .idle
        source = nil
    }

    /// An import failure of the file port stays what it is; any other error of the file is `fileNotRead`.
    private static func readFailure(_ error: any Error) -> any Error {
        if error is ImportFailure || error is CancellationError { return error }
        return ImportFailure.fileNotRead
    }
}

/// What one import holds of a file: the spellings it took when it started, and the URL as it was handed over. The
/// file system is read once, at that moment, and never again for this hold: a link may point elsewhere by the time the
/// import ends.
private struct FileHold: Sendable {
    let id: Int
    /// The file however it is spelled: links resolved, `.` and `..` taken out, as they were when the hold began.
    let key: URL
    /// The spelling as written: `.` and `..` taken out, links kept.
    let spelling: URL
    let url: URL

    /// Whether `other` may be the same file: by the key or the spelling either one took.
    func mayBeTheFileOf(_ other: FileHold) -> Bool { key == other.key || spelling == other.spelling }
}

/// Which imports hold which files: an import holds its file until it ends, also after a cancel. A file is released
/// exactly once, by the last import that gives it back; the imports hold this object, not the view model.
///
/// When in doubt a file is kept: a release that comes late only keeps a copy a little longer, one that comes early
/// breaks a read in progress. So a file counts as held by every hold that matches it by its captured key or by its
/// spelling, and the file system is never asked again about a hold already taken.
@MainActor
private final class FileHolds {
    private let files: any ImportFileReading
    private var held: [FileHold] = []
    private var issued = 0

    init(_ files: any ImportFileReading) { self.files = files }

    func hold(_ file: URL) -> FileHold {
        issued += 1
        let taken = FileHold(id: issued, key: file.resolvingSymlinksInPath().standardizedFileURL,
                             spelling: file.standardizedFileURL, url: file)
        held.append(taken)
        return taken
    }

    /// An import gives its file back: the file goes when no other import holds it.
    func letGo(_ gone: FileHold) {
        guard let index = held.firstIndex(where: { $0.id == gone.id }) else { return }
        held.remove(at: index)
        if !held.contains(where: { $0.mayBeTheFileOf(gone) }) { files.release(gone.url) }
    }

    /// A file handed over and not read: it goes at once, unless an import holds it (that import lets it go).
    func refuse(_ file: URL) {
        let asked = FileHold(id: 0, key: file.resolvingSymlinksInPath().standardizedFileURL,
                             spelling: file.standardizedFileURL, url: file)
        if !held.contains(where: { $0.mayBeTheFileOf(asked) }) { files.release(file) }
    }
}
