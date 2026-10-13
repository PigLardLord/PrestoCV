import SwiftUI
import PrestoCVCore
import CVPDFExporter

/// What the user chose in the export sheet: the single value the sheet watches to refresh the preview.
struct ExportSelection: Equatable {
    var templateId: String?
    var colorPalette: ColorPalette
    var fontScheme: FontScheme
}

/// The PDF of the current selection, rendered and ready to share under the name the recipient will see.
struct SharePDF: Equatable {
    let url: URL

    var fileName: String { url.lastPathComponent }
}

/// Drives the export sheet: the template, palette and font the user picks, the preview of that choice, and the PDF
/// that is rendered once the preview has settled so that sharing it is a single tap.
///
/// All the work of a selection runs in one task that the view model owns. A new selection, or the sheet closing,
/// cancels it, and a generation number keeps a result that arrives late, from a task that was cancelled while it
/// was waiting for a service that cannot be interrupted, out of the state.
@MainActor
final class CVExportSheetViewModel: ObservableObject {
    @Published var templates: [Template] = []
    @Published var selectedTemplateId: String?
    @Published var selectedColorPalette: ColorPalette = .professional
    @Published var selectedFontScheme: FontScheme = .classic
    @Published private(set) var previewHTML: String?
    @Published private(set) var previewOptions: ExportOptions?
    @Published private(set) var isPreviewLoading = false
    @Published private(set) var isPreparingPDF = false
    @Published private(set) var sharePDF: SharePDF?
    /// Why no PDF is made for this CV, in words the user can act on; nil when the CV can be exported
    @Published private(set) var shareBlocker: String?
    @Published var errorMessage: String?

    /// The longest CV the export accepts, for the preview and for the PDF alike
    static let maxPages = 10

    private let exportService: any CVExportServiceProtocol
    private let preferencesStore: any ExportPreferencesStore
    private let previewDebounce: Duration
    private var refreshTask: Task<Void, Never>?
    private var generation = 0

    var selection: ExportSelection {
        ExportSelection(
            templateId: selectedTemplateId,
            colorPalette: selectedColorPalette,
            fontScheme: selectedFontScheme
        )
    }

    var aspectRatio: CGFloat {
        let options = previewOptions ?? currentExportOptions()
        let pageSize = options.pageSize
        return CGFloat(pageSize.width) / CGFloat(pageSize.height)
    }

    /// - Parameter previewDebounce: How long a selection must stay put before its preview is made, so that
    ///   changing the template, the palette and the font in quick succession makes one preview and one PDF
    init(
        exportService: (any CVExportServiceProtocol)? = nil,
        preferencesStore: any ExportPreferencesStore = FileExportPreferencesStore(),
        previewDebounce: Duration = .milliseconds(250)
    ) {
        self.exportService = exportService ?? CVExportService()
        self.preferencesStore = preferencesStore
        self.previewDebounce = previewDebounce
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

    /// Makes the preview of the current selection, and then its PDF, in place of any earlier request.
    /// A CV without a name or an email still gets its preview, which shows what is missing, but no PDF.
    /// - Returns: The task that does the work, for a caller that wants to wait for it
    @discardableResult
    func requestPreview(for cv: CVModel) -> Task<Void, Never> {
        refreshTask?.cancel()
        generation += 1
        let requestGeneration = generation
        let staleFile = takeSharePDF()

        shareBlocker = Self.shareBlocker(for: cv)
        isPreviewLoading = selectedTemplateId != nil
        isPreparingPDF = selectedTemplateId != nil && shareBlocker == nil

        // The service, not the view model, removes the displaced file: the sheet may be gone before the task runs
        let service = exportService
        let task = Task { [weak self] in
            if let staleFile {
                await service.cleanupTempFile(at: staleFile)
            }
            await self?.refresh(for: cv, generation: requestGeneration)
        }
        refreshTask = task
        return task
    }

    /// Ends the work in progress and removes the PDF, because the sheet is going away
    /// - Returns: The task that removes the file, for a caller that wants to wait for it
    @discardableResult
    func stop() -> Task<Void, Never> {
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

    func currentExportOptions() -> ExportOptions {
        ExportOptions(
            pageSize: .a4,
            margins: .default,
            templateId: selectedTemplateId,
            customization: CustomizationOptions(
                colorPalette: selectedColorPalette,
                fontScheme: selectedFontScheme
            ),
            maxPages: Self.maxPages
        )
    }

    // MARK: - Refreshing

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
            let url = try await exportService.export(cv: cv, templateId: templateId, options: options)
            guard isCurrent(requestGeneration) else {
                await exportService.cleanupTempFile(at: url)
                return
            }
            sharePDF = SharePDF(url: url)
            isPreparingPDF = false
            rememberChoice(templateId: templateId, customization: options.customization)
        } catch {
            guard isCurrent(requestGeneration) else { return }
            isPreparingPDF = false
            report(error, during: .exporting)
        }
    }

    /// The exporter refuses a document without a name or an email; say so beforehand, next to the preview,
    /// instead of in an alert when the sheet opens
    private static func shareBlocker(for cv: CVModel) -> String? {
        let hasName = !cv.personalInfo.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasEmail = !cv.personalInfo.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasName && hasEmail ? nil : String(localized: "export.error.missing_name_email")
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
    private func restoreLastChoice(among availableTemplates: [Template]) {
        let lastChoice = preferencesStore.load()
        if let lastTemplateId = lastChoice.templateId,
           availableTemplates.contains(where: { $0.id == lastTemplateId }) {
            selectedTemplateId = lastTemplateId
        } else {
            selectedTemplateId = availableTemplates.first?.id
        }
        selectedColorPalette = lastChoice.colorPalette ?? selectedColorPalette
        selectedFontScheme = lastChoice.fontScheme ?? selectedFontScheme
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
