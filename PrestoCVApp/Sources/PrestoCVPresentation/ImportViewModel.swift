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
    /// Counts the intents that start or end an import: a task publishes only while it holds the latest one.
    @ObservationIgnored private var generation = 0

    /// Does no I/O and starts nothing.
    public init(importer: any CVImporting, files: any ImportFileReading) {
        self.importer = importer
        self.files = files
    }

    // MARK: - Intents

    /// What the person pasted: the PDFs and the strings of the clipboard's items. A PDF, such as one copied in Files, goes
    /// to the import as a PDF, like a file, and the text stays as it was: it wins over strings pasted with it, as it is
    /// the whole document. Otherwise the strings take the place of the text, one per line. A paste of nothing changes
    /// nothing.
    public func paste(_ strings: [String], pdfs: [Data]) {
        if let pdf = pdfs.first {
            importPDF(pdf)
            return
        }
        let pasted = strings.joined(separator: "\n")
        guard !pasted.isEmpty else { return }
        text = pasted
    }

    public func importText() {
        guard canImportText else { return }
        let text = text, importer = importer
        start(from: .pasted, releasing: nil) { try await importer.importCV(fromText: text) }
    }

    /// A PDF file the person chose or opened in the app. The port receives it first. If an import runs, the file is not
    /// read and is released at once; otherwise the import task reads it and releases it when the task ends, however the
    /// import ended, also when the view model is gone. The view model never decides which files are the same.
    public func importFile(at url: URL) {
        let received = files.receive(url)
        guard status != .importing else {
            files.release(received)
            return
        }
        let importer = importer, files = files
        start(from: .file, releasing: { files.release(received) }) {
            let data: Data
            do { data = try await files.readPDF(of: received) } catch {
                throw Self.readFailure(error)
            }
            try Task.checkCancellation()
            return try await importer.importCV(fromPDF: data)
        }
    }

    /// The system could not hand over the file the person chose: the screen tells them, as for a file it could not read.
    /// While an import runs nothing changes.
    public func fileNotOpened() {
        guard status != .importing else { return }
        source = .file
        result = nil
        status = .failed(.fileNotRead)
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

    private func importPDF(_ data: Data) {
        guard status != .importing else { return }
        let importer = importer
        start(from: .file, releasing: nil) { try await importer.importCV(fromPDF: data) }
    }

    private func start(from source: ImportSource, releasing release: (@Sendable () -> Void)?,
                       _ work: @escaping @MainActor () async throws -> ImportOutcome) {
        running?.cancel()
        generation += 1
        let mine = generation
        self.source = source
        result = nil
        status = .importing
        running = Task { [weak self] in
            // After the draft or the problem is published; the closure holds the port, not the view model.
            defer { release?() }
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
