import Foundation
import Observation
internal import PrestoCVApplication
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// The export sheet of one open CV: the PDF, which is also the preview, in the language chosen, and its share.
@MainActor
@Observable
public final class ExportSheetViewModel {

    /// The language the person chose in the sheet, nil until they choose one. A choice is the CV's language from then on,
    /// as a language read from the words is: the sheet has no way back to automatic (#407).
    public private(set) var selectedLanguage: ExportLanguage?
    /// The language of the PDF while none is chosen: the one the CV holds, else the one its words are written in, else
    /// the app's (#407). Nil until the sheet has read the CV. Once a language is chosen the words are no longer read.
    public private(set) var automaticLanguage: ExportLanguage?
    /// The last language the person picked, for VoiceOver to tell: each pick is a new value, a pick of the language
    /// already shown too, as the menu then closes on an unchanged row. Nil before a pick and once the sheet stops.
    public private(set) var languageToAnnounce: LanguageChoice?
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

    /// The language of the PDF: the one chosen, else the one automatic stands for.
    public var effectiveLanguage: ExportLanguage? { selectedLanguage ?? automaticLanguage }

    /// The languages the sheet offers.
    public let offeredLanguages: [ExportLanguage]

    /// The designs, palettes and font schemes the sheet offers.
    public let lookChoices: LookChoices
    /// The look of the PDF: the CV's as the last export read it, with the parts chosen in the sheet on top; before the
    /// first export, the look the editor showed, else the app's default one (#407).
    public private(set) var shownLook: EditorLook

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
    @ObservationIgnored private let appLanguage: ExportLanguage
    @ObservationIgnored private let fileNamePattern: @Sendable (ExportLanguage) -> String
    @ObservationIgnored private let onLanguageChosen: @MainActor (ExportLanguage) -> Void
    @ObservationIgnored private let detector: any CVLanguageDetecting
    @ObservationIgnored private let onLanguageFound: @MainActor (ExportLanguage) -> Void
    @ObservationIgnored private let onLookChosen: @MainActor (EditorLook, Set<LookPart>) -> Void
    /// The parts of the look chosen in the sheet, put on the CV each export reads: the CV the editor shows may not hold
    /// them yet, and the other parts follow it.
    @ObservationIgnored private var chosenLook: LookChange?
    /// The language the sheet found in the words of a CV that keeps none: the words are read until they tell one, and
    /// then no more.
    @ObservationIgnored private var found: DocumentLanguage?
    /// Fixes the end of a pause now, and gives the wait for it.
    @ObservationIgnored private let pauseFromNow: () -> () async throws -> Void
    @ObservationIgnored private var running: Task<Void, Never>?
    /// Counts the intents that start or end an export: a task publishes only while it holds the latest one.
    @ObservationIgnored private var generation = 0
    /// True while the file of a share is being written: a second tap writes nothing, and Share shows it is preparing.
    private var writing = false
    /// Counts the failed shares, so that each one is a new value.
    @ObservationIgnored private var failures = 0
    /// Counts the languages picked, so that each pick is a new value.
    @ObservationIgnored private var picks = 0

    /// - Parameters:
    ///   - files: Writes the PDF as a file for the share sheet, and removes it when the share ends.
    ///   - snapshot: The CV as the editor shows it now, read at the start of each export.
    ///   - offeredLanguages: The languages a PDF can be written in.
    ///   - appLanguage: The language of the app: the PDF's when the CV keeps none and its words tell none, which is
    ///     then kept nowhere (#407).
    ///   - fileNamePattern: The pattern of the PDF's title in a language, with "%@" where the name goes (R13).
    ///   - onLanguageChosen: Takes a language chosen in the sheet to the CV.
    ///   - languageDetector: Tells the language of the words of a CV that keeps none.
    ///   - onLanguageFound: Keeps in the CV the language its words were found in, unless the person chose one in the
    ///     sheet: the headings then stay in that language. It must never replace a language the CV keeps by the time it
    ///     is stored, found by another sheet or chosen (#407).
    ///   - lookOptions: The designs, palettes and font schemes the sheet offers, and the look of a CV that keeps none.
    ///   - look: The look the editor shows, nil for a CV that keeps none.
    ///   - onLookChosen: Takes a look chosen in the sheet to the CV, with the part the person chose: the others are what
    ///     the sheet showed. Called after the export begins, as `onLanguageChosen` is.
    ///   - clock: The clock the pause is measured on.
    ///   - pause: How long after the last intent the export starts, so that several quick changes make one export.
    public init(
        exporter: any CVExporting, files: any ExportFileSharing, snapshot: @escaping @MainActor () -> ExportSnapshot,
        offeredLanguages: [ExportLanguage],
        appLanguage: ExportLanguage, fileNamePattern: @escaping @Sendable (ExportLanguage) -> String,
        onLanguageChosen: @escaping @MainActor (ExportLanguage) -> Void, languageDetector: any CVLanguageDetecting,
        onLanguageFound: @escaping @MainActor (ExportLanguage) -> Void,
        lookOptions: any LookOptionsProviding, look: EditorLook?,
        onLookChosen: @escaping @MainActor (EditorLook, Set<LookPart>) -> Void,
        clock: any Clock<Duration>, pause: Duration
    ) {
        self.exporter = exporter
        self.files = files
        self.snapshot = snapshot
        self.offeredLanguages = offeredLanguages
        self.appLanguage = appLanguage
        self.fileNamePattern = fileNamePattern
        self.onLanguageChosen = onLanguageChosen
        self.detector = languageDetector
        self.onLanguageFound = onLanguageFound
        let options = lookOptions.options()
        self.lookChoices = LookChoices(options)
        self.shownLook = look
            ?? EditorLook(design: options.defaultDesign, palette: options.defaultPalette, fonts: options.defaultFonts)
        self.onLookChosen = onLookChosen
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

    /// Exports in `language`, announces the pick and takes it to the CV. The export begins and the pick is announced
    /// before the choice goes out, so a call into the sheet from `onLanguageChosen` (a `stop()`, another `select`) is
    /// the later intent. The language of the PDF on screen, or of the one being made, keeps that PDF: the pick is still
    /// announced, and still goes to the CV.
    public func select(language: ExportLanguage) {
        let keepsThePDF = language == effectiveLanguage && (status == .exporting || document != nil)
        selectedLanguage = language
        if !keepsThePDF { begin() }
        picks += 1
        languageToAnnounce = LanguageChoice(language: language, ordinal: picks)
        onLanguageChosen(language)
    }

    /// Exports again, with the CV as it stands now: the screen calls it when the look changes while the sheet is open.
    public func refresh() { begin() }

    /// Exports with `design`, shows it and takes it to the CV; the palette and fonts stay as shown.
    public func choose(design: String) {
        choose(.design, EditorLook(design: design, palette: shownLook.palette, fonts: shownLook.fonts))
    }

    /// Exports with `palette`, shows it and takes it to the CV; the design and fonts stay as shown.
    public func choose(palette: String?) {
        choose(.palette, EditorLook(design: shownLook.design, palette: palette, fonts: shownLook.fonts))
    }

    /// Exports with `fonts`, shows them and takes them to the CV; the design and palette stay as shown.
    public func choose(fonts: String?) {
        choose(.fonts, EditorLook(design: shownLook.design, palette: shownLook.palette, fonts: fonts))
    }

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
        languageToAnnounce = nil
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

    // MARK: - The look

    /// The person chose `part` of the look, and `look` is the whole look shown with it. The choice stays on the CV of
    /// every later export of this sheet, and goes to the CV after the export begins, so a call into the sheet from
    /// `onLookChosen` is the later intent. The look of the PDF on screen, or of the one being made, keeps that PDF: the
    /// choice still goes to the CV. A look with an id no design may have changes nothing.
    private func choose(_ part: LookPart, _ look: EditorLook) {
        guard let step = LookChange(shown: look, parts: [part]) else { return }
        let keepsThePDF = look == shownLook && (status == .exporting || document != nil)
        chosenLook = chosenLook.map { $0.followed(by: step) } ?? step
        shownLook = look
        if !keepsThePDF { begin() }
        onLookChosen(look, [part])
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
        guard let (cv, language) = readCVAndLanguage(mine) else { return }
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
    /// nil when nothing is to be exported, or when `mine` is no longer the latest intent. On the way it can store in the
    /// CV the language its words are written in (`wordsLanguage`). The snapshot closure and `onLanguageFound` can call
    /// into the sheet, so the generation is checked again after each.
    private func readCVAndLanguage(_ mine: Int) -> (CV, DocumentLanguage)? {
        guard mine == generation else { return nil }
        let cv = snapshot().cv
        guard mine == generation else { return nil }
        let automatic = cv.language ?? wordsLanguage(of: cv) ?? appLanguage.language
        guard mine == generation else { return nil }
        return prepare(cv, automatic: ExportLanguage(language: automatic))
    }

    /// The language of the words of a CV that keeps none, or nil when they tell none. The first one found goes to the
    /// CV. Once the person chose a language the words are not read: that choice goes to the CV instead. The CV keeps
    /// the found one only if it keeps none by the time it is stored (`onLanguageFound`). A save that fails leaves the CV
    /// without a language, as a failed choice does: the editor shows the failure, and the next sheet reads the words
    /// again.
    private func wordsLanguage(of cv: CV) -> DocumentLanguage? {
        if let found { return found }
        guard selectedLanguage == nil else { return nil }
        found = detector.language(of: cv, among: offeredLanguages.map(\.language))
        if let found { onLanguageFound(ExportLanguage(language: found)) }
        return found
    }

    /// Publishes what the sheet knows of the CV before the export, and gives the CV to export, with the look chosen in the
    /// sheet on top, in the language of the PDF; nil when the CV lacks a field the PDF needs.
    private func prepare(_ read: CV, automatic: ExportLanguage) -> (CV, DocumentLanguage)? {
        let cv = chosenLook.map { ChangeCV.applying($0, to: read) } ?? read
        shownLook = cv.design.map { EditorLook($0) } ?? shownLook
        automaticLanguage = automatic
        missing = ExportMissing(cv)
        guard missing.blockers.isEmpty else {
            settle(.notReady)
            return nil
        }
        let language = (selectedLanguage ?? automatic).language
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
        case .truncated, .unsupportedLanguage, .invalid, .incomplete, .textNotVisible, .failed: true
        }
    }
}
