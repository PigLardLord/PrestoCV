import Foundation
import PrestoCVCore
import CVPDFExporter

/// Handles PDF export operations using CVPDFExporter while remaining SwiftUI-friendly.
actor CVExportService {
    private let container: PDFExportDependencyContainer
    private let exportUseCase: PDFExportUseCase
    private let templateSelectionUseCase: TemplateSelectionUseCase
    private let templateRepository: BundledTemplateRepository
    private let templatePreviewUseCase: TemplatePreviewUseCase
    private let adapter = PrestoCVCoreAdapter()

    init(container: PDFExportDependencyContainer = PDFExportDependencyContainer()) {
        self.container = container
        self.exportUseCase = container.makeExportUseCase()
        self.templateSelectionUseCase = container.makeTemplateSelectionUseCase()
        self.templateRepository = container.makeTemplateRepository()
        self.templatePreviewUseCase = container.makeTemplatePreviewUseCase()
    }

    func availableTemplates() async throws -> [Template] {
        try await templateSelectionUseCase.getAvailableTemplates()
    }

    func export(
        cv: CVModel,
        templateId: String,
        customization: CustomizationOptions
    ) async throws -> URL {
        let document = adapter.convertToCV(from: cv)
        let template = try templateRepository.loadTemplate(id: templateId)
        let options = ExportOptions(templateId: templateId, customization: customization)

        let result = try await exportUseCase.execute(
            document: document,
            template: template,
            options: options
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportedCV-\(UUID().uuidString).pdf")
        try result.pdfData.write(to: outputURL, options: .atomic)
        return outputURL
    }

    func cleanupTempFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    func generatePreviewHTML(
        cv: CVModel,
        templateId: String,
        options: ExportOptions
    ) async throws -> String {
        let document = adapter.convertToCV(from: cv)
        let preview = try await templatePreviewUseCase.generatePreview(
            templateId: templateId,
            cv: document,
            customization: options.customization,
            pageSize: options.pageSize
        )
        return preview.html
    }

    func savePDF(_ data: Data) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportedCV-\(UUID().uuidString).pdf")
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }
}
