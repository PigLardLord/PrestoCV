import Combine
import Foundation
import PrestoCVCore
import CVPDFExporter
import struct PrestoCVDomain.ExportPolicy
import struct PrestoCVDomain.ExportReadiness

/// What the user chose in the export sheet: while the sheet is shown, each change of it makes a new preview.
struct ExportSelection: Equatable {
    var templateId: String?
    var colorPalette: ColorPalette
    var fontScheme: FontScheme
    /// The language chosen for the PDF; nil is automatic
    var documentLanguage: DocumentLanguage?
}

/// Where the language chosen for a CV's PDF in its export sheet goes, for the CV to keep it; nil is automatic.
typealias DocumentLanguageSink = @MainActor (DocumentLanguage?) -> Void

/// Drives the export sheet of one CV: the template, palette, font and language the user picks, the preview of that
/// choice, and the PDF that is rendered once the preview has settled so that sharing it is a single tap.
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

    /// How the CV is exported: the page, its border, the longest CV, and what a CV needs before it is exported
    let exportPolicy: ExportPolicy
    /// The CV the sheet exports
    private let cv: CVModel
    /// The language the app is shown in, which names the language of the PDF
    private let appLocale: Locale
    private let exportService: any CVExportServiceProtocol
    private let preferencesStore: any ExportPreferencesStore
    private let documentLanguageSink: DocumentLanguageSink
    private let previewDebounce: Duration
    private var refreshTask: Task<Void, Never>?
    private var generation = 0
    /// The sheet is on screen, from `start()` to `stop()`: a change of the selection makes its preview
    private var isShown = false

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

    var aspectRatio: CGFloat {
        let options = previewOptions ?? currentExportOptions()
        let pageSize = options.pageSize
        return CGFloat(pageSize.width) / CGFloat(pageSize.height)
    }

    /// - Parameters:
    ///   - cv: The CV to export. The sheet starts with the language chosen for it.
    ///   - exportService: Makes the preview and the PDF.
    ///   - preferencesStore: Keeps the design chosen last, for the next export.
    ///   - documentLanguageSink: Takes each language chosen in the sheet, for the CV to keep.
    ///   - exportPolicy: How the CV is exported, for the preview and the PDF alike.
    ///   - documentLanguageDetector: Reads which language the CV is written in, for the Automatic document language.
    ///   - appLocale: The language the app is shown in.
    ///   - previewDebounce: How long a selection must stay put before its preview is made, so that changing the
    ///     template, the palette and the font in quick succession makes one preview and one PDF
    init(
        cv: CVModel,
        exportService: any CVExportServiceProtocol,
        preferencesStore: any ExportPreferencesStore,
        documentLanguageSink: @escaping DocumentLanguageSink,
        exportPolicy: ExportPolicy,
        documentLanguageDetector: DocumentLanguageDetector,
        appLocale: Locale,
        previewDebounce: Duration = .milliseconds(250)
    ) {
        self.cv = cv
        self.exportService = exportService
        self.preferencesStore = preferencesStore
        self.documentLanguageSink = documentLanguageSink
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
    }

    /// The sheet shows: the templates are loaded, which selects the one chosen last and so makes the first preview.
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
                restoreLastChoice(among: availableTemplates)
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
        let staleFile = takeSharePDF()

        var printedCV = cv
        printedCV.documentLanguage = documentLanguage.rawValue
        shareOutcome = nil
        let readiness = ExportReadiness(name: cv.personalInfo.name, email: cv.personalInfo.email, phone: cv.personalInfo.phone)
        shareBlocker = Self.blockerText(for: readiness)
        shareWarning = Self.warningText(for: readiness)
        isPreviewLoading = selectedTemplateId != nil
        isPreparingPDF = selectedTemplateId != nil && shareBlocker == nil

        // The service, not the view model, removes the displaced file: the sheet may be gone before the task runs
        let service = exportService
        let task = Task { [weak self] in
            if let staleFile {
                await service.cleanupTempFile(at: staleFile)
            }
            await self?.refresh(for: printedCV, generation: requestGeneration)
        }
        refreshTask = task
        return task
    }

    /// Ends the work in progress and removes the PDF, because the sheet is going away
    /// - Returns: The task that removes the file, for a caller that wants to wait for it
    @discardableResult
    func stop() -> Task<Void, Never> {
        isShown = false
        refreshTask?.cancel()
        refreshTask = nil
        generation += 1
        isPreviewLoading = false
        isPreparingPDF = false
        let staleFile = takeSharePDF()

        // The sheet is going away and its view model with it, so the cleanup must not depend on the view model
        let service = exportService
        return Task {
            if let staleFile {
                await service.cleanupTempFile(at: staleFile)
            }
        }
    }

    /// The preview could not be shown by the web view; a cancelled load is not a failure
    func reportPreviewLoadFailure(_ error: Error) {
        guard !(error is CancellationError) else { return }
        errorMessage = ExportErrorMessage.message(for: error, during: .creatingPreview)
    }

    func dismissError() {
        errorMessage = nil
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

    /// A language chosen in the sheet goes to the CV at once; any change makes a new preview while the sheet shows.
    private func selectionDidChange(from oldValue: ExportSelection) {
        guard selection != oldValue else { return }
        if selection.documentLanguage != oldValue.documentLanguage {
            documentLanguageSink(selection.documentLanguage)
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
            rememberChoice(templateId: templateId, customization: options.customization)
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

    private func takeSharePDF() -> URL? {
        let url = sharePDF?.url
        sharePDF = nil
        return url
    }

    // MARK: - Remembering the choice

    /// Starts from what the user chose last time; a template that is no longer installed gives way to the first one.
    /// The choice changes at once, so that it makes one preview.
    private func restoreLastChoice(among availableTemplates: [Template]) {
        let lastChoice = preferencesStore.load()
        var restored = selection
        if let lastTemplateId = lastChoice.templateId,
           availableTemplates.contains(where: { $0.id == lastTemplateId }) {
            restored.templateId = lastTemplateId
        } else {
            restored.templateId = availableTemplates.first?.id
        }
        restored.colorPalette = lastChoice.colorPalette ?? restored.colorPalette
        restored.fontScheme = lastChoice.fontScheme ?? restored.fontScheme
        selection = restored
    }

    private func rememberChoice(templateId: String, customization: CustomizationOptions) {
        let choice = ExportPreferences(
            templateId: templateId,
            colorPalette: customization.colorPalette,
            fontScheme: customization.fontScheme
        )
        // The PDF is already made: failing to remember the choice must not turn the export into an error.
        try? preferencesStore.save(choice)
    }
}
