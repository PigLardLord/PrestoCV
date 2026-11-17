import Foundation
import Observation
internal import PrestoCVApplication
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// The export sheet of one open CV: the PDF, which is also the preview, in the language chosen, and its share.
@MainActor
@Observable
public final class ExportSheetViewModel {

    /// The language the person chose in the sheet; nil is automatic.
    public private(set) var selectedLanguage: ExportLanguage?
    /// The language automatic stands for: the one the CV holds, or nil when it holds none.
    public private(set) var automaticLanguage: ExportLanguage?
    public private(set) var status: ExportStatus = .idle
    /// The end of the last export for VoiceOver to tell, when the status line says a problem: set as an export ends
    /// without its PDF or with a PDF shorter than the CV needs. It is nil while one runs, after one that made the PDF
    /// in full, and when the CV lacks a field: the list under the pages says which, and Share's value points to it.
    public private(set) var statusToAnnounce: ExportStatus?
    /// The PDF of the last export, or nil while one runs or when it failed.
    public private(set) var document: ExportedDocument?
    /// The identity of the export that made `document`: set and cleared together with it. A share names the PDF by it.
    public private(set) var documentID: ExportID?
    /// The name of the PDF's file, in the language of the PDF: set before the export starts, so it is there whenever
    /// `document` is.
    public private(set) var suggestedFileName: String?
    /// What the CV lacks, as the sheet read it at the start of the last export.
    public private(set) var missing = ExportMissing.unknown
    /// A share of the PDF that went through, until the next export.
    public private(set) var shareOutcome: ShareOutcome?
    /// The last share of the PDF that could not go through: its file could not be written, or the share sheet reported
    /// an error. A new try, a share that goes through and the next export clear it.
    public private(set) var shareFailure: ShareFailure?
    /// The PDF on the whole screen, or nil when the sheet shows it at its own size. It is always the PDF the sheet holds:
    /// a new export and the end of the sheet close it.
    public private(set) var fullPDF: FullPDF?
    /// The share the system's share sheet shows, from the moment its file is written; nil when there is none. The share
    /// sheet ends it, and a new export or the end of the sheet lets it go.
    public private(set) var openShare: PDFShare?

    /// The language of the PDF: the one chosen, else the one the CV holds.
    public var effectiveLanguage: ExportLanguage? { selectedLanguage ?? automaticLanguage }

    /// The languages the sheet offers: the app's first while the PDF has no language.
    public var offeredLanguages: [ExportLanguage] {
        guard effectiveLanguage == nil else { return offered }
        return [appLanguage] + offered.filter { $0 != appLanguage }
    }

    /// Whether Share can be used now: it waits for the export and for the file of a share, and needs the PDF. The share
    /// sheet itself is not counted: it covers the sheet until it ends.
    public var shareAvailability: ShareAvailability {
        if status == .exporting || writing { return .preparing }
        guard document != nil, documentID != nil, suggestedFileName != nil else { return .unavailable }
        return .ready
    }

    /// True when the sheet closes as Done: a share of its PDF went through.
    public var closesAsDone: Bool { shareOutcome != nil }

    // MARK: - State

    @ObservationIgnored private let exporter: any CVExporting
    @ObservationIgnored private let files: any ExportFileSharing
    @ObservationIgnored private let snapshot: @MainActor () -> ExportSnapshot
    @ObservationIgnored private let offered: [ExportLanguage]
    @ObservationIgnored private let appLanguage: ExportLanguage
    @ObservationIgnored private let fileNamePattern: @Sendable (ExportLanguage) -> String
    @ObservationIgnored private let onLanguageChosen: @MainActor (ExportLanguage?) -> Void
    /// Fixes the end of a pause now, and gives the wait for it.
    @ObservationIgnored private let pauseFromNow: () -> () async throws -> Void
    @ObservationIgnored private var running: Task<Void, Never>?
    /// Counts the intents that start or end an export: a task publishes only while it holds the latest one.
    @ObservationIgnored private var generation = 0
    /// True while the file of a share is being written: a second tap writes nothing, and Share shows it is preparing.
    private var writing = false
    /// Counts the failed shares, so that each one is a new value.
    @ObservationIgnored private var failures = 0

    /// - Parameters:
    ///   - files: Writes the PDF as a file for the share sheet, and removes it when the share ends.
    ///   - snapshot: The CV as the editor shows it now, read at the start of each export.
    ///   - offeredLanguages: The languages a PDF can be written in.
    ///   - appLanguage: The language of the app, offered first when the CV holds none.
    ///   - fileNamePattern: The pattern of the PDF's title in a language, with "%@" where the name goes (R13).
    ///   - onLanguageChosen: Takes a language chosen in the sheet to the CV; nil is automatic.
    ///   - clock: The clock the pause is measured on.
    ///   - pause: How long after the last intent the export starts, so that several quick changes make one export.
    public init(
        exporter: any CVExporting, files: any ExportFileSharing, snapshot: @escaping @MainActor () -> ExportSnapshot,
        offeredLanguages: [ExportLanguage],
        appLanguage: ExportLanguage, fileNamePattern: @escaping @Sendable (ExportLanguage) -> String,
        onLanguageChosen: @escaping @MainActor (ExportLanguage?) -> Void, clock: any Clock<Duration>, pause: Duration
    ) {
        self.exporter = exporter
        self.files = files
        self.snapshot = snapshot
        self.offered = offeredLanguages
        self.appLanguage = appLanguage
        self.fileNamePattern = fileNamePattern
        self.onLanguageChosen = onLanguageChosen
        self.pauseFromNow = Self.pause(pause, on: clock)
    }

    /// The end of a pause is fixed when the pause starts, on the clock's own instants.
    private static func pause<C: Clock<Duration>>(_ pause: Duration, on clock: C) -> () -> () async throws -> Void {
        {
            let deadline = clock.now.advanced(by: pause)
            return { try await clock.sleep(until: deadline, tolerance: nil) }
        }
    }

    // MARK: - Intents

    /// Starts the export of the CV as it stands. The shell calls it when it opens the sheet.
    public func start() { begin() }

    /// Exports in `language`, and takes the choice to the CV; nil is automatic. The export begins before the choice goes
    /// out, so a call into the sheet from `onLanguageChosen` (a `stop()`, another `select`) is the later intent.
    public func select(language: ExportLanguage?) {
        selectedLanguage = language
        begin()
        onLanguageChosen(language)
    }

    /// Exports again, with the CV as it stands now: the screen calls it when the look changes while the sheet is open.
    public func refresh() { begin() }

    /// Shows the PDF on the whole screen, under the name of its file. Without a PDF there is nothing to show.
    public func showFullPDF() {
        guard let document, let documentID, let suggestedFileName else { return }
        fullPDF = FullPDF(id: documentID, document: document, fileName: suggestedFileName)
    }

    /// The whole screen closes; the sheet keeps its PDF.
    public func closeFullPDF() { fullPDF = nil }

    /// The sheet goes away: the running export stops and the PDF is dropped.
    public func stop() {
        running?.cancel()
        generation += 1
        status = .idle
        statusToAnnounce = nil
        document = nil
        documentID = nil
        suggestedFileName = nil
        fullPDF = nil
        openShare = nil
        writing = false
        shareFailure = nil
    }

    /// Writes the PDF as a file under its name, then opens the share. Without a PDF, or while a share is open or its
    /// file is being written, it does nothing. A file that cannot be written opens no share and marks the share as
    /// failed; the next tap tries again.
    public func share() {
        guard openShare == nil, !writing, let document, let documentID, let suggestedFileName else { return }
        writing = true
        shareFailure = nil
        let mine = generation
        Task { [weak self, files] in
            do {
                let file = try await files.write(document.pdf, named: suggestedFileName)
                guard let self else {
                    files.remove(file)
                    return
                }
                self.shareWritten(file, named: suggestedFileName, of: documentID, mine)
            } catch {
                self?.writeFailed(mine)
            }
        }
    }

    // MARK: - The share

    /// The file of a share is written: the share opens, unless a new export or the end of the sheet came first, and then
    /// the file goes at once.
    private func shareWritten(_ file: SharedFile, named fileName: String, of export: ExportID, _ mine: Int) {
        guard mine == generation else {
            files.remove(file)
            return
        }
        writing = false
        openShare = PDFShare(file: file, fileName: fileName, export: export, files: files, sheet: self)
    }

    /// The file of a share could not be written: the share is marked as failed, unless a new export or the end of the
    /// sheet came first.
    private func writeFailed(_ mine: Int) {
        guard mine == generation else { return }
        writing = false
        markShareFailed()
    }

    /// The share sheet of `share` ended: the sheet lets it go, confirms it when it went through, and marks it when it
    /// failed.
    func shareEnded(_ share: PDFShare, with result: ShareResult) {
        if openShare === share { openShare = nil }
        shareEnded(result, of: share.export)
    }

    /// The share sheet of the PDF made by export `shared` ended. Only a save or a send is confirmed; a share that went
    /// through another way, or was cancelled, says nothing.
    func shareEnded(_ result: ShareResult, of shared: ExportID) {
        // A share that ends after a newer export started is about a PDF no longer on screen, even when the new PDF holds
        // the same bytes
        guard shared == documentID else { return }
        switch result {
        case .saved: wentThrough(.saved)
        case .sent: wentThrough(.sent)
        case .failed: markShareFailed()
        case .other, .cancelled: break
        }
    }

    private func wentThrough(_ outcome: ShareOutcome) {
        shareOutcome = outcome
        shareFailure = nil
    }

    private func markShareFailed() {
        failures += 1
        shareFailure = ShareFailure(ordinal: failures)
    }

    // MARK: - The export

    private func begin() {
        running?.cancel()
        generation += 1
        let mine = generation
        status = .exporting
        statusToAnnounce = nil
        document = nil
        documentID = nil
        suggestedFileName = nil
        shareOutcome = nil
        shareFailure = nil
        fullPDF = nil
        openShare = nil
        writing = false
        let waitForThePause = pauseFromNow()
        running = Task { [weak self] in
            do {
                try await waitForThePause()
            } catch {
                // Only a newer intent cancels the pause, and it has published its own state
                return
            }
            await self?.export(mine)
        }
    }

    private func export(_ mine: Int) async {
        guard let (cv, language) = readTheCV(mine) else { return }
        let status: ExportStatus
        var document: ExportedDocument?
        do {
            let outcome = try await exporter.export(cv, language: language)
            document = ExportedDocument(pdf: outcome.pdf, pages: outcome.pageCount)
            status = outcome.truncated
                ? .truncated(pages: outcome.pageCount, required: outcome.requiredPages)
                : .done(pages: outcome.pageCount)
        } catch let failure as ExportFailure {
            status = ExportStatus(failure)
        } catch is CancellationError {
            status = .idle
        } catch {
            status = .failed
        }
        publish(mine) {
            self.document = document
            self.documentID = document.map { _ in ExportID(generation: mine) }
            self.settle(status)
        }
    }

    /// The export ended with `ended`: the status line shows it, and VoiceOver is told it when it is a problem.
    private func settle(_ ended: ExportStatus) {
        status = ended
        statusToAnnounce = ended.isTold ? ended : nil
    }

    /// Reads the CV, publishes what the sheet knows of it before the export, and gives it with the language of the PDF;
    /// nil when nothing is to be exported, or when `mine` is no longer the latest intent: the snapshot closure can call
    /// into the sheet, so the generation is checked again after it.
    private func readTheCV(_ mine: Int) -> (CV, DocumentLanguage)? {
        guard mine == generation else { return nil }
        let cv = snapshot().cv
        guard mine == generation else { return nil }
        return prepare(cv)
    }

    private func prepare(_ cv: CV) -> (CV, DocumentLanguage)? {
        automaticLanguage = cv.language.map(ExportLanguage.init(language:))
        missing = ExportMissing(cv)
        guard missing.blockers.isEmpty else {
            settle(.notReady)
            return nil
        }
        guard let language = effectiveLanguage?.language else {
            settle(.languageNeeded)
            return nil
        }
        suggestedFileName = fileName(of: cv, in: language)
        return (cv, language)
    }

    /// The name of the PDF's file, from the person's name and the pattern of the PDF's language (R6, R13).
    private func fileName(of cv: CV, in language: DocumentLanguage) -> String {
        PDFFileName(titlePattern: fileNamePattern(ExportLanguage(language: language)))
            .fileName(personName: cv.personal.fullName, cvName: cv.title)
    }

    /// Every change made after an await goes through here: it is made only while `mine` is the latest intent, so the
    /// task of a superseded intent changes nothing, whenever it ends.
    @discardableResult
    private func publish<Value>(_ mine: Int, _ change: () -> Value) -> Value? {
        guard mine == generation else { return nil }
        return change()
    }
}

/// A sheet is the item its presentation is bound to: one sheet, one presentation.
extension ExportSheetViewModel: Identifiable {}

private extension ExportStatus {
    /// True for an end that the status line says as a problem, which VoiceOver is told. A CV that lacks a field is not:
    /// the list under the pages names the field.
    var isTold: Bool {
        switch self {
        case .idle, .exporting, .done, .notReady: false
        case .truncated, .languageNeeded, .unsupportedLanguage, .invalid, .incomplete, .textNotVisible, .failed: true
        }
    }
}
