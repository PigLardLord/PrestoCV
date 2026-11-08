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
    /// The file the import running reads, nil when it reads none.
    @ObservationIgnored private var reading: URL?
    /// Counts the intents that start or end an import: a task publishes only while it holds the latest one.
    @ObservationIgnored private var generation = 0

    /// Does no I/O and starts nothing.
    public init(importer: any CVImporting, files: any ImportFileReading) {
        self.importer = importer
        self.files = files
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

    /// A PDF file the person chose or opened in the app. The file is let go once its import ended, however it ended.
    /// One handed over while an import runs is let go unread, unless it is the file being read, which its own import
    /// lets go: nothing of a file is kept (ADR 0027).
    public func importFile(at url: URL) {
        guard status != .importing else {
            if !Self.isSameFile(url, reading) { files.release(url) }
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
        reading = file
        result = nil
        status = .importing
        let files = files
        running = Task { [weak self] in
            // After the draft or the problem is published, so that the file outlives its own import only.
            defer { if let file { files.release(file) } }
            let ended: Result<ImportOutcome, any Error>
            do { ended = .success(try await work()) } catch { ended = .failure(error) }
            self?.finish(mine, ended, from: source)
        }
    }

    private func finish(_ mine: Int, _ ended: Result<ImportOutcome, any Error>, from source: ImportSource) {
        guard mine == generation else { return }
        running = nil
        reading = nil
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
        reading = nil
    }

    /// An import failure of the file port stays what it is; any other error of the file is `fileNotRead`.
    private static func readFailure(_ error: any Error) -> any Error {
        if error is ImportFailure || error is CancellationError { return error }
        return ImportFailure.fileNotRead
    }

    /// The same file however it is spelled: links resolved, `.` and `..` taken out.
    private static func isSameFile(_ url: URL, _ other: URL?) -> Bool {
        guard let other else { return false }
        return url.resolvingSymlinksInPath().standardizedFileURL == other.resolvingSymlinksInPath().standardizedFileURL
    }
}
