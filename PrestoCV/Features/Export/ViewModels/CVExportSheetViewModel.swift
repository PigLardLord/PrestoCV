import SwiftUI
import PrestoCVCore
import CVPDFExporter

@MainActor
final class CVExportSheetViewModel: ObservableObject {
    @Published var templates: [Template] = []
    @Published var selectedTemplateId: String?
    @Published var selectedColorPalette: ColorPalette = .professional
    @Published var selectedFontScheme: FontScheme = .classic
    @Published var isExporting = false
    @Published var errorMessage: String?
    @Published var previewItem: ExportPreviewItem?
    @Published var previewHTML: String?
    @Published var isPreviewLoading = false
    @Published private(set) var previewOptions: ExportOptions?

    /// The longest CV the export accepts, for the preview and for the PDF alike
    static let maxPages = 10

    private let exportService: any CVExportServiceProtocol
    private let preferencesStore: any ExportPreferencesStore

    var aspectRatio: CGFloat {
        let options = previewOptions ?? currentExportOptions()
        let pageSize = options.pageSize
        return CGFloat(pageSize.width) / CGFloat(pageSize.height)
    }

    init(
        exportService: (any CVExportServiceProtocol)? = nil,
        preferencesStore: any ExportPreferencesStore = FileExportPreferencesStore()
    ) {
        self.exportService = exportService ?? CVExportService()
        self.preferencesStore = preferencesStore
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
        } catch {
            errorMessage = ExportErrorMessage.message(for: error, during: .loadingTemplates)
        }
    }

    func refreshPreview(for cv: CVModel) async {
        let options = currentExportOptions()

        guard let templateId = options.templateId else {
            previewHTML = nil
            previewOptions = nil
            return
        }

        isPreviewLoading = true
        defer { isPreviewLoading = false }

        do {
            let html = try await exportService.generatePreviewHTML(
                cv: cv,
                templateId: templateId,
                options: options
            )
            previewOptions = options
            previewHTML = html
        } catch {
            previewOptions = nil
            errorMessage = ExportErrorMessage.message(for: error, during: .creatingPreview)
        }
    }

    func export(cv: CVModel) async {
        let options = currentExportOptions()

        guard let templateId = options.templateId else {
            errorMessage = String(localized: "export.error.no_template")
            return
        }

        isExporting = true
        defer { isExporting = false }

        do {
            let url = try await exportService.export(
                cv: cv,
                templateId: templateId,
                options: options
            )
            previewItem = ExportPreviewItem(url: url)
            rememberChoice(templateId: templateId, customization: options.customization)
        } catch is CancellationError {
            // User-initiated cancellation; no need to surface error
        } catch {
            errorMessage = ExportErrorMessage.message(for: error, during: .exporting)
        }
    }

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

    func dismissError() {
        errorMessage = nil
    }

    func handlePreviewDismiss() {
        guard let previewURL = previewItem?.url else {
            previewItem = nil
            return
        }

        previewItem = nil
        Task {
            await exportService.cleanupTempFile(at: previewURL)
        }
    }

    struct ExportPreviewItem: Identifiable {
        let id = UUID()
        let url: URL
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
}
