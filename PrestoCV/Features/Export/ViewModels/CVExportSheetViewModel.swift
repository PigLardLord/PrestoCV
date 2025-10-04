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

    func export(cv: CVModel) async {
        guard let templateId = selectedTemplateId else {
            errorMessage = String(localized: "export.error.no_template")
            return
        }

        isExporting = true
        defer { isExporting = false }

        let customization = CustomizationOptions(
            colorPalette: selectedColorPalette,
            fontScheme: selectedFontScheme
        )

        do {
            let url = try await exportService.export(
                cv: cv,
                templateId: templateId,
                customization: customization
            )
            previewItem = ExportPreviewItem(url: url)
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
}
