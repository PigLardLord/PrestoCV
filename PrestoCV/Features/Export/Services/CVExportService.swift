import Foundation
import PrestoCVCore
import CVPDFExporter

/// Protocol for PDF export operations
protocol CVExportServiceProtocol: Actor {
    func availableTemplates() async throws -> [Template]
    func export(cv: CVModel, templateId: String, options: ExportOptions) async throws -> URL
    func cleanupTempFile(at url: URL) async
    func generatePreviewHTML(cv: CVModel, templateId: String, options: ExportOptions) async throws -> String
}

/// Handles PDF export operations using CVPDFExporter while remaining SwiftUI-friendly.
actor CVExportService: CVExportServiceProtocol {
    private let container: PDFExportDependencyContainer
    private let templateSelectionUseCase: TemplateSelectionUseCase
    private let templateRepository: BundledTemplateRepository
    private let templatePreviewUseCase: TemplatePreviewUseCase
    private let adapter = PrestoCVCoreAdapter()
    private let fileNames: ExportFileName
    private let temporaryDirectory: URL

    /// - Parameter temporaryDirectory: Where each export gets a folder of its own; the system's by default
    init(
        container: PDFExportDependencyContainer = PDFExportDependencyContainer(),
        fileNames: ExportFileName = ExportFileName(),
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.container = container
        self.fileNames = fileNames
        self.temporaryDirectory = temporaryDirectory
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
        options: ExportOptions
    ) async throws -> URL {
        let document = adapter.convertToCV(from: cv)
        let template = try await templateRepository.loadTemplate(id: templateId)

        let personName = cv.personalInfo.name
        let author = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        let documentOptions = options.withDocumentInfo(
            title: fileNames.title(personName: personName, cvName: cv.name),
            author: author.isEmpty ? nil : author
        )

        // The renderer lives on the main actor, so the use case is built there for each export
        let exportUseCase = await container.makeExportUseCase()
        let result = try await exportUseCase.execute(
            document: document,
            template: template,
            options: documentOptions
        )

        return try writePDF(result.pdfData, fileName: fileNames.fileName(personName: personName, cvName: cv.name))
    }

    /// Removes the exported file together with the folder made for it
    func cleanupTempFile(at url: URL) async {
        let folder = url.deletingLastPathComponent()
        let isExportFolder = folder.deletingLastPathComponent().standardizedFileURL == temporaryDirectory.standardizedFileURL
        try? FileManager.default.removeItem(at: isExportFolder ? folder : url)
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

    // MARK: - Private

    /// Writes the PDF as `<temporary directory>/<UUID>/<file name>`: the folder keeps exports apart,
    /// and the file keeps the name the user will see when sharing it.
    private func writePDF(_ data: Data, fileName: String) throws -> URL {
        let folder = temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let outputURL = folder.appendingPathComponent(fileName)
        do {
            try data.write(to: outputURL, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
        return outputURL
    }
}
