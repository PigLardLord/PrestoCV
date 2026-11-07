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
    /// The PDF of the last export, or nil while one runs or when it failed.
    public private(set) var document: ExportedDocument?
    /// The name of the PDF's file, in the language of the PDF.
    public private(set) var suggestedFileName: String?
    /// What the CV lacks, as the sheet read it at the start of the last export.
    public private(set) var missing = ExportMissing.unknown
    /// A share of the PDF that went through, until the next export.
    public private(set) var shareOutcome: ShareOutcome?

    /// The language of the PDF: the one chosen, else the one the CV holds.
    public var effectiveLanguage: ExportLanguage? { selectedLanguage ?? automaticLanguage }

    /// The languages the sheet offers: the app's first while the PDF has no language.
    public var offeredLanguages: [ExportLanguage] {
        guard effectiveLanguage == nil else { return offered }
        return [appLanguage] + offered.filter { $0 != appLanguage }
    }

    // MARK: - State

    @ObservationIgnored private let exporter: any CVExporting
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

    /// - Parameters:
    ///   - snapshot: The CV as the editor shows it now, read at the start of each export.
    ///   - offeredLanguages: The languages a PDF can be written in.
    ///   - appLanguage: The language of the app, offered first when the CV holds none.
    ///   - fileNamePattern: The pattern of the PDF's title in a language, with "%@" where the name goes (R13).
    ///   - onLanguageChosen: Takes a language chosen in the sheet to the CV; nil is automatic.
    ///   - clock: The clock the pause is measured on.
    ///   - pause: How long after the last intent the export starts, so that several quick changes make one export.
    public init(
        exporter: any CVExporting, snapshot: @escaping @MainActor () -> ExportSnapshot, offeredLanguages: [ExportLanguage],
        appLanguage: ExportLanguage, fileNamePattern: @escaping @Sendable (ExportLanguage) -> String,
        onLanguageChosen: @escaping @MainActor (ExportLanguage?) -> Void, clock: any Clock<Duration>, pause: Duration
    ) {
        self.exporter = exporter
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

    /// Starts the export of the CV as it stands. The view calls it from its `.task`.
    public func start() { begin() }

    /// Exports in `language`, and takes the choice to the CV; nil is automatic.
    public func select(language: ExportLanguage?) {
        selectedLanguage = language
        onLanguageChosen(language)
        begin()
    }

    /// Exports again, with the CV as it stands now: the screen calls it when the look changes while the sheet is open.
    public func refresh() { begin() }

    /// The sheet goes away: the running export stops and the PDF is dropped.
    public func stop() {
        running?.cancel()
        generation += 1
        status = .idle
        document = nil
        suggestedFileName = nil
    }

    /// The share sheet of `shared` ended.
    public func shareEnded(_ result: ShareResult, of shared: ExportedDocument) {
        // A share that ends after a newer export started is about a PDF no longer on screen
        guard shared == document else { return }
        switch result {
        case .saved: shareOutcome = .saved
        case .sent: shareOutcome = .sent
        case .cancelled: break
        }
    }

    // MARK: - The export

    private func begin() {
        running?.cancel()
        generation += 1
        let mine = generation
        status = .exporting
        document = nil
        suggestedFileName = nil
        shareOutcome = nil
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
        guard let (cv, language) = publish(mine, prepare) ?? nil else { return }
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
            self.status = status
        }
    }

    /// Reads the CV, publishes what the sheet knows of it before the export, and gives it with the language of the PDF;
    /// nil when nothing is to be exported.
    private func prepare() -> (CV, DocumentLanguage)? {
        let cv = snapshot().cv
        automaticLanguage = cv.language.map(ExportLanguage.init(language:))
        missing = ExportMissing(cv)
        guard missing.blockers.isEmpty else {
            status = .notReady
            return nil
        }
        guard let language = effectiveLanguage?.language else {
            status = .languageNeeded
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
