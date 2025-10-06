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

    private let exportService: CVExportService

    init(exportService: CVExportService = CVExportService()) {
        self.exportService = exportService
    }

    func loadTemplates() async {
        do {
            let availableTemplates = try await exportService.availableTemplates()
            templates = availableTemplates
            if selectedTemplateId == nil {
                selectedTemplateId = availableTemplates.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    func export(
        cv: CVModel,
        pdfProducer: () async throws -> Data
    ) async {
        guard let templateId = selectedTemplateId else {
            errorMessage = String(localized: "export.error.no_template")
            return
        }

        isExporting = true
        defer { isExporting = false }

        do {
            let pdfData = try await pdfProducer()
            let url = try await exportService.savePDF(pdfData)
            previewItem = ExportPreviewItem(url: url)
        } catch is CancellationError {
            // User-initiated cancellation; no need to surface error
        } catch {
            errorMessage = error.localizedDescription
        }
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
            maxPages: 10
        )
    }
}
