import Combine
import Foundation
import PrestoCVCore
import CVPDFExporter
import struct PrestoCVApplication.LookChange
import struct PrestoCVDomain.ExportPolicy
import struct PrestoCVDomain.ExportReadiness

/// What the user chose in the export sheet: while the sheet is shown, each change of it makes a new preview.
struct ExportSelection: Equatable {
    var templateId: String?
    var colorPalette: ColorPalette
    var fontScheme: FontScheme
    /// The language chosen for the PDF; nil is automatic
    var documentLanguage: DocumentLanguage?

    /// The design, palette and font of the selection
    var look: ExportLook {
        get { ExportLook(templateId: templateId, colorPalette: colorPalette, fontScheme: fontScheme) }
        set { (templateId, colorPalette, fontScheme) = (newValue.templateId, newValue.colorPalette, newValue.fontScheme) }
    }
}

/// Where the language chosen for a CV's PDF in its export sheet goes, for the CV to keep it; nil is automatic.
typealias DocumentLanguageSink = @MainActor (DocumentLanguage?) -> Void

/// Where the design, palette or font chosen for a CV's PDF in its export sheet goes, for the CV to keep it: the parts
/// the person chose, and no other.
typealias LookSink = @MainActor (LookChange) -> Void

/// Drives the export sheet of one CV: the template, palette, font and language the user picks, the preview of that
/// choice, and the PDF that is rendered once the preview has settled so that sharing it is a single tap.
///
/// The sheet starts from the look the CV keeps (`ExportLookResolver`) and hands each change of the design, palette or
/// font to the look sink at once, as it does the language: whoever owns the CV stores it. What is handed over is what
/// the person chose, with the look the sheet shows: a part they did not touch stays as the CV holds it, even an id the
/// app does not know, for which the sheet shows a default. Starting from the look is not a choice, so it is not handed
/// over, and a CV opened and closed is left as it was.
///
/// All the work of a selection runs in one task that the view model owns. A new selection, or the sheet closing,
/// cancels it, and a generation number keeps a result that arrives late, from a task that was cancelled while it
/// was waiting for a service that cannot be interrupted, out of the state.
@MainActor
final class CVExportSheetViewModel: ObservableObject {
    @Published var templates: [Template] = []
    /// The template, palette, font and language chosen. While the sheet is shown, each change makes a new preview.
    @Published private(set) var selection: ExportSelection {
        didSet { selectionDidChange(from: oldValue) }
    }
    /// True until the templates are loaded, when the sheet first shows
    @Published private(set) var isLoadingTemplates = true
    /// The language automatic stands for with the CV: the one it is written in, or the app's
    let automaticDocumentLanguage: DocumentLanguage
    @Published private(set) var previewHTML: String?
    @Published private(set) var previewOptions: ExportOptions?
    @Published private(set) var isPreviewLoading = false
    @Published private(set) var isPreparingPDF = false
    @Published private(set) var sharePDF: ExportedPDF?
    /// The PDF shown full screen, while it is open: always the PDF that the share button shares
    @Published private(set) var fullPDF: ExportedPDF?
    /// Why no PDF is made for this CV, in words the user can act on; nil when the CV can be exported
    @Published private(set) var shareBlocker: String?
    /// What the PDF lacks, though it is made, in words the user can act on; nil when it lacks nothing
    @Published private(set) var shareWarning: String?
    /// How the last share of this PDF ended, when it went through
    @Published private(set) var shareOutcome: ShareOutcome?
    @Published var errorMessage: String?

    /// How a share that went through ended
    enum ShareOutcome: Equatable {
        /// The PDF was saved to Files
        case saved
        /// The PDF went anywhere else: an e-mail, a message, AirDrop, the printer
        case sent
    }

    /// The activity of the share sheet that saves a file to Files
    static let saveToFilesActivity = "com.apple.DocumentManagerUICore.SaveToFiles"

    /// How long a selection must stay put before the sheet reacts to it: it makes its preview then, and the list of CVs
    /// stores what was chosen.
    nonisolated static let selectionInterval = Duration.milliseconds(250)

    /// How the CV is exported: the page, its border, the longest CV, and what a CV needs before it is exported
    let exportPolicy: ExportPolicy
    /// The CV the sheet exports
    private let cv: CVModel
    /// The language the app is shown in, which names the language of the PDF
    private let appLocale: Locale
    private let exportService: any CVExportServiceProtocol
    private let preferencesStore: any ExportPreferencesStore
    private let documentLanguageSink: DocumentLanguageSink
    private let lookSink: LookSink
    private let previewDebounce: Duration
    private var refreshTask: Task<Void, Never>?
    private var generation = 0
    /// The sheet is on screen, from `start()` to `stop()`: a change of the selection makes its preview
    private var isShown = false
    /// The cover of the full PDF is up, from the moment it appears (`fullPDFDidAppear()`) until it has gone
    /// (`fullPDFDidDismiss()`). It follows what SwiftUI did, not what was asked: `fullPDF` is cleared at once by Done,
    /// while the cover is still on its way out and the sheet is still going on and off screen under it, and a request
    /// for the cover that is withdrawn before it is presented leaves no cover to appear and none to dismiss.
    private var isCovered = false
    /// Removes the temp PDFs, and keeps the one a share sheet is reading until that share ends
    private let files: ExportFileKeeper
    /// The selection is being set to the look the CV keeps, which is not a choice of the person
    private var isStartingFromTheCVsLook = false

    var selectedTemplateId: String? {
        get { selection.templateId }
        set { selection.templateId = newValue }
    }

    var selectedColorPalette: ColorPalette {
        get { selection.colorPalette }
        set { selection.colorPalette = newValue }
    }

    var selectedFontScheme: FontScheme {
        get { selection.fontScheme }
        set { selection.fontScheme = newValue }
    }

    /// The language chosen for the PDF; nil is automatic. It starts as the language chosen for the CV.
    var documentLanguageChoice: DocumentLanguage? {
        get { selection.documentLanguage }
        set { selection.documentLanguage = newValue }
    }

    /// The language the PDF is written in: the one chosen, or the one automatic stands for
    var documentLanguage: DocumentLanguage {
        documentLanguageChoice ?? automaticDocumentLanguage
    }

    /// What the language of the PDF changes, in the language of the app: "Headings in English"
    var documentLanguageText: String {
        String(format: String(localized: "export.language.headings"), documentLanguage.name(in: appLocale))
    }

    /// The automatic choice with the language it stands for: "Automatic (English)"
    var automaticDocumentLanguageTitle: String {
        automaticDocumentLanguage.automaticTitle
    }

    /// Says that the last share went through, and where the PDF went: "PDF saved"
    var shareConfirmationText: String? {
        switch shareOutcome {
        case .saved?:
            return String(localized: "export.confirmation.saved")
        case .sent?:
            return String(localized: "export.confirmation.sent")
        case nil:
            return nil
        }
    }

    /// The button that closes the sheet: "Cancel" until the PDF has gone somewhere, "Done" after
    var closeButtonTitle: String {
        shareOutcome == nil ? String(localized: "common.cancel") : String(localized: "common.done")
    }

    /// How many pages the PDF has, once it is rendered: the preview shows a page at a time, and a CV that is longer
    /// than the page in view should not come as a surprise
    var pageCountText: String? {
        sharePDF.map { String(format: String(localized: "export.page_count"), $0.pageCount) }
    }

    /// What the preview says to VoiceOver when it shows the pages of the PDF, which a tap opens full screen: "Show the
    /// full PDF, 2 pages"; nil until the PDF is rendered
    var fullPDFAccessibilityLabel: String? {
        sharePDF.map { String(localized: "export.preview.open \($0.pageCount)") }
    }

    var aspectRatio: CGFloat {
        let options = previewOptions ?? currentExportOptions()
        let pageSize = options.pageSize
        return CGFloat(pageSize.width) / CGFloat(pageSize.height)
    }

    /// - Parameters:
    ///   - cv: The CV to export. The sheet starts with the language chosen for it.
    ///   - exportService: Makes the preview and the PDF.
    ///   - preferencesStore: Holds the design that earlier versions chose last for every CV, read only for a CV that
    ///     keeps no look of its own.
    ///   - documentLanguageSink: Takes each language chosen in the sheet, for the CV to keep.
    ///   - lookSink: Takes the design, palette and font each time one of them is chosen in the sheet, for the CV to keep.
    ///   - exportPolicy: How the CV is exported, for the preview and the PDF alike.
    ///   - documentLanguageDetector: Reads which language the CV is written in, for the Automatic document language.
    ///   - appLocale: The language the app is shown in.
    ///   - previewDebounce: How long a selection must stay put before its preview is made, so that changing the
    ///     template, the palette and the font in quick succession makes one preview and one PDF (`selectionInterval`)
    init(
        cv: CVModel,
        exportService: any CVExportServiceProtocol,
        preferencesStore: any ExportPreferencesStore,
        documentLanguageSink: @escaping DocumentLanguageSink,
        lookSink: @escaping LookSink,
        exportPolicy: ExportPolicy,
        documentLanguageDetector: DocumentLanguageDetector,
        appLocale: Locale,
        previewDebounce: Duration = CVExportSheetViewModel.selectionInterval
    ) {
        self.cv = cv
        self.exportService = exportService
        self.preferencesStore = preferencesStore
        self.documentLanguageSink = documentLanguageSink
        self.lookSink = lookSink
        self.exportPolicy = exportPolicy
        self.appLocale = appLocale
        self.previewDebounce = previewDebounce
        selection = ExportSelection(
            templateId: nil,
            colorPalette: .professional,
            fontScheme: .classic,
            documentLanguage: cv.chosenDocumentLanguage
        )
        automaticDocumentLanguage = documentLanguageDetector.automaticLanguage(for: cv)
        files = ExportFileKeeper(service: exportService)
    }

    /// The sheet was torn down without going off screen, as when it is closed from outside while the full PDF covers it:
    /// the PDF it made is removed with it, as `stop()` does, once no share sheet reads it.
    isolated deinit {
        guard let staleFile = sharePDF?.url else { return }
        files.letGo(of: staleFile)
    }

    /// The sheet shows: the templates are loaded, which selects the CV's own design and so makes the first preview.
    /// From then on, until `stop()`, each change of the selection makes a new preview.
    func start() async {
        isShown = true
        await loadTemplates()
        isLoadingTemplates = false
    }

    func loadTemplates() async {
        do {
            let availableTemplates = try await exportService.availableTemplates()
            templates = availableTemplates
            if availableTemplates.isEmpty {
                errorMessage = String(localized: "export.error.no_templates")
            } else if selectedTemplateId == nil {
                startFromTheCVsLook(among: availableTemplates)
            }
        } catch is CancellationError {
            // The sheet went away while the templates were loading
        } catch {
            errorMessage = ExportErrorMessage.message(for: error, during: .loadingTemplates)
        }
    }

    /// Makes the preview of the current selection, and then its PDF, in place of any earlier request. Both are in the
    /// language the sheet shows, whatever the CV says.
    /// A CV without a name or an email still gets its preview, which shows what is missing, but no PDF.
    /// - Returns: The task that does the work, for a caller that wants to wait for it
    @discardableResult
    func requestPreview() -> Task<Void, Never> {
        refreshTask?.cancel()
        generation += 1
        let requestGeneration = generation
        let removal = takeSharePDF().map { files.letGo(of: $0) }

        var printedCV = cv
        printedCV.documentLanguage = documentLanguage.rawValue
        shareOutcome = nil
        let readiness = ExportReadiness(name: cv.personalInfo.name, email: cv.personalInfo.email, phone: cv.personalInfo.phone)
        shareBlocker = Self.blockerText(for: readiness)
        shareWarning = Self.warningText(for: readiness)
        isPreviewLoading = selectedTemplateId != nil
        isPreparingPDF = selectedTemplateId != nil && shareBlocker == nil

        // The displaced file goes before the new one is made, unless a share sheet is still reading it
        let task = Task { [weak self] in
            await removal?.value
            await self?.refresh(for: printedCV, generation: requestGeneration)
        }
        refreshTask = task
        return task
    }

    /// Ends the work in progress and removes the PDF, because the sheet is going away; a PDF that a share sheet is still
    /// reading is removed when that share ends.
    /// - Returns: The task that removes the file, for a caller that wants to wait for it
    @discardableResult
    func stop() -> Task<Void, Never> {
        isShown = false
        refreshTask?.cancel()
        refreshTask = nil
        generation += 1
        isPreviewLoading = false
        isPreparingPDF = false
        guard let staleFile = takeSharePDF() else { return Task {} }

        // The sheet is going away and its view model with it, so the cleanup must not depend on the view model
        return files.letGo(of: staleFile)
    }

    /// The sheet's content went off screen. While the full PDF covers the sheet it has not gone away, and its PDF stays
    /// for the full PDF to show and the button to share; otherwise the sheet is closing, as in `stop()`.
    ///
    /// The cover decides, not the PDF it shows nor the request for it: a Done before the cover is fully up clears
    /// `fullPDF` before the sheet goes off screen, and the sheet is back on screen right after. Only the cover going away
    /// ends the covering. A request that was withdrawn before the cover appeared covers nothing, so the sheet closing
    /// then stops.
    /// - Returns: The task that removes the file, for a caller that wants to wait for it
    @discardableResult
    func sheetDisappeared() -> Task<Void, Never> {
        guard !isCovered else { return Task {} }
        return stop()
    }

    /// Asks for the PDF that the button shares full screen, over the sheet; nothing opens until the PDF is rendered. The
    /// sheet is covered when the cover appears (`fullPDFDidAppear()`), not when it is asked for.
    func showFullPDF() {
        guard let pdf = sharePDF else { return }
        fullPDF = pdf
    }

    /// Closes the full PDF, back to the sheet as it was: the PDF and the choices are kept. The cover is still on screen
    /// until it tells that it has gone (`fullPDFDidDismiss()`).
    func closeFullPDF() {
        fullPDF = nil
    }

    /// The cover of the full PDF is up: the sheet is covered, and going off screen under it is not closing
    func fullPDFDidAppear() {
        isCovered = true
    }

    /// The cover of the full PDF has gone: the sheet is the one on screen again
    func fullPDFDidDismiss() {
        isCovered = false
    }

    /// The preview could not be shown by the web view; a cancelled load is not a failure
    func reportPreviewLoadFailure(_ error: Error) {
        guard !(error is CancellationError) else { return }
        errorMessage = ExportErrorMessage.message(for: error, during: .creatingPreview)
    }

    func dismissError() {
        errorMessage = nil
    }

    /// The PDF is handed to a share sheet: it stays, whatever happens to the sheet, until that share ends
    /// - Returns: The share, to end when the share sheet closes; nil until the PDF is rendered
    func beginShare() -> PDFShare? {
        guard let pdf = sharePDF else { return nil }
        return PDFShare(pdf: pdf, keeper: files)
    }

    /// The share sheet closed: a share that went through is confirmed, one that was cancelled changes nothing
    /// - Parameter activityType: The raw value of the activity the PDF went to, if any
    func shareEnded(activityType: String?, completed: Bool) {
        guard completed else { return }
        shareOutcome = activityType == Self.saveToFilesActivity ? .saved : .sent
    }

    func currentExportOptions() -> ExportOptions {
        ExportOptions(
            pageSize: PageSize(width: exportPolicy.pageWidth, height: exportPolicy.pageHeight),
            margins: .uniform(exportPolicy.margin),
            templateId: selectedTemplateId,
            customization: CustomizationOptions(
                colorPalette: selectedColorPalette,
                fontScheme: selectedFontScheme
            ),
            maxPages: exportPolicy.maxPages
        )
    }

    // MARK: - Refreshing

    /// A language, design, palette or font chosen in the sheet goes to the CV at once; any change makes a new preview
    /// while the sheet shows. A look is handed over as the parts the person changed, with the look the sheet shows.
    private func selectionDidChange(from oldValue: ExportSelection) {
        guard selection != oldValue else { return }
        if selection.documentLanguage != oldValue.documentLanguage {
            documentLanguageSink(selection.documentLanguage)
        }
        if !isStartingFromTheCVsLook, let change = selection.look.change(from: oldValue.look) {
            lookSink(change)
        }
        if isShown {
            requestPreview()
        }
    }

    private func refresh(for cv: CVModel, generation requestGeneration: Int) async {
        let options = currentExportOptions()

        guard let templateId = options.templateId else {
            previewHTML = nil
            previewOptions = nil
            isPreviewLoading = false
            isPreparingPDF = false
            return
        }

        do {
            try await Task.sleep(for: previewDebounce)
            let html = try await exportService.generatePreviewHTML(cv: cv, templateId: templateId, options: options)
            guard isCurrent(requestGeneration) else { return }
            previewOptions = options
            previewHTML = html
            isPreviewLoading = false
        } catch {
            guard isCurrent(requestGeneration) else { return }
            previewOptions = nil
            isPreviewLoading = false
            isPreparingPDF = false
            report(error, during: .creatingPreview)
            return
        }

        guard shareBlocker == nil else {
            isPreparingPDF = false
            return
        }
        await prepareSharePDF(for: cv, templateId: templateId, options: options, generation: requestGeneration)
    }

    private func prepareSharePDF(
        for cv: CVModel,
        templateId: String,
        options: ExportOptions,
        generation requestGeneration: Int
    ) async {
        do {
            let pdf = try await exportService.export(cv: cv, templateId: templateId, options: options)
            guard isCurrent(requestGeneration) else {
                await exportService.cleanupTempFile(at: pdf.url)
                return
            }
            sharePDF = pdf
            isPreparingPDF = false
        } catch {
            guard isCurrent(requestGeneration) else { return }
            isPreparingPDF = false
            report(error, during: .exporting)
        }
    }

    /// What keeps the CV from being exported, by `ExportReadiness`: the name, said beforehand, next to the preview,
    /// instead of in an alert when the sheet opens
    private static func blockerText(for readiness: ExportReadiness) -> String? {
        readiness.blockers.contains(.name) ? String(localized: "export.readiness.name_required") : nil
    }

    /// What the PDF lacks, by `ExportReadiness`: a way to reach the person, which it is still made without
    private static func warningText(for readiness: ExportReadiness) -> String? {
        switch (readiness.warnings.contains(.email), readiness.warnings.contains(.phone)) {
        case (true, true): return String(localized: "export.readiness.no_email_phone")
        case (true, false): return String(localized: "export.readiness.no_email")
        case (false, true): return String(localized: "export.readiness.no_phone")
        case (false, false): return nil
        }
    }

    /// A result belongs to the request that is current, and only while the task that made it is not cancelled
    private func isCurrent(_ requestGeneration: Int) -> Bool {
        requestGeneration == generation && !Task.isCancelled
    }

    /// Cancellation is the user moving on, not an error to tell them about
    private func report(_ error: Error, during activity: ExportErrorMessage.Activity) {
        guard !(error is CancellationError) else { return }
        errorMessage = ExportErrorMessage.message(for: error, during: activity)
    }

    /// Lets the PDF go, which closes the full PDF with it: no viewer shows a file that is about to be removed
    private func takeSharePDF() -> URL? {
        let url = sharePDF?.url
        sharePDF = nil
        fullPDF = nil
        return url
    }

    // MARK: - Starting from the CV's look

    /// Starts from the look the CV keeps, or for a CV without one from what earlier versions chose last; a part that is
    /// missing, or a design that is no longer installed, gives its default. The selection changes at once, so that it
    /// makes one preview, and it is not handed to the look sink: the CV is left as it is until the person chooses.
    private func startFromTheCVsLook(among availableTemplates: [Template]) {
        let legacy = cv.look == nil ? preferencesStore.load() : ExportPreferences()
        let look = ExportLookResolver.resolve(look: cv.look, legacy: legacy, availableTemplateIds: availableTemplates.map(\.id))
        var started = selection
        started.look = look
        isStartingFromTheCVsLook = true
        defer { isStartingFromTheCVsLook = false }
        selection = started
    }
}
