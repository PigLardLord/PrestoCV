import Foundation
import CryptoKit
import PDFKit

/// Result of PDF export operation
public struct PDFExportResult: Sendable {
    public let pdfData: Data
    public let pageCount: Int
    public let fileSize: Int64

    public init(pdfData: Data, pageCount: Int) {
        self.pdfData = pdfData
        self.pageCount = pageCount
        self.fileSize = Int64(pdfData.count)
    }
}

/// Use case for exporting CV to PDF
/// Single Responsibility: Orchestrates PDF export process
public actor PDFExportUseCase {
    private let renderer: PDFRendererProtocol
    private let repository: ExportRepositoryProtocol
    private let templateEngine: TemplateEngine
    private let enableCaching: Bool

    public init(
        renderer: PDFRendererProtocol,
        repository: ExportRepositoryProtocol,
        templateEngine: TemplateEngine,
        enableCaching: Bool = false
    ) {
        self.renderer = renderer
        self.repository = repository
        self.templateEngine = templateEngine
        self.enableCaching = enableCaching
    }

    /// Executes PDF export
    /// - Parameters:
    ///   - document: CV document to export
    ///   - template: Template to use for rendering
    ///   - options: Export configuration options
    /// - Returns: PDF export result, with the number of pages the PDF really has
    /// - Throws: PDFExportError if export fails, or `tooManyPages` if the PDF is longer than `options.maxPages`
    public func execute(
        document: CVDocument,
        template: Template,
        options: ExportOptions
    ) async throws -> PDFExportResult {
        // Validate document
        try validateDocument(document)

        // Check cache if enabled
        if enableCaching {
            let cacheKey = generateCacheKey(document: document, template: template, options: options)
            if let cachedData = await repository.getCachedPDF(key: cacheKey) {
                return PDFExportResult(
                    pdfData: cachedData,
                    pageCount: try checkedPageCount(of: cachedData, limit: options.maxPages)
                )
            }
        }

        // Generate HTML from template
        let html = try await templateEngine.render(
            template: template,
            data: document,
            customization: options.customization
        )

        // Render PDF
        let pdfData = try await renderer.renderToPDF(html: html, options: options)

        let pageCount = try checkedPageCount(of: pdfData, limit: options.maxPages)

        // Save to history
        let historyEntry = ExportHistoryEntry(
            cvId: generateDocumentId(document),
            cvName: document.personalInfo.name,
            templateId: template.id,
            fileSize: Int64(pdfData.count),
            pageCount: pageCount
        )
        try await repository.saveExportHistory(historyEntry)

        // Cache if enabled
        if enableCaching {
            let cacheKey = generateCacheKey(document: document, template: template, options: options)
            try await repository.cachePDF(
                data: pdfData,
                key: cacheKey,
                ttl: 3600 // 1 hour TTL
            )
        }

        return PDFExportResult(pdfData: pdfData, pageCount: pageCount)
    }

    // MARK: - Private Methods

    private func validateDocument(_ document: CVDocument) throws {
        guard !document.personalInfo.name.isEmpty else {
            throw PDFExportError.invalidContent("Document must have a name")
        }
        guard !document.personalInfo.email.isEmpty else {
            throw PDFExportError.invalidContent("Document must have an email")
        }
    }

    /// The number of pages the PDF has, read from the document itself
    private func checkedPageCount(of pdfData: Data, limit: Int) throws -> Int {
        guard let document = PDFDocument(data: pdfData), document.pageCount > 0 else {
            throw PDFExportError.renderingFailed("The renderer did not produce a readable PDF")
        }
        guard document.pageCount <= limit else {
            throw PDFExportError.tooManyPages(count: document.pageCount, limit: limit)
        }
        return document.pageCount
    }

    private func generateCacheKey(
        document: CVDocument,
        template: Template,
        options: ExportOptions
    ) -> String {
        let docId = generateDocumentId(document)
        let customizationString = "\(options.customization.colorPalette.rawValue)_\(options.customization.fontScheme.rawValue)"
        let input = "\(docId)_\(template.id)_\(customizationString)"
        let inputData = Data(input.utf8)
        let hash = SHA256.hash(data: inputData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func generateDocumentId(_ document: CVDocument) -> String {
        let input = "\(document.personalInfo.name)_\(document.personalInfo.email)"
        let inputData = Data(input.utf8)
        let hash = SHA256.hash(data: inputData)
        return hash.prefix(8).compactMap { String(format: "%02x", $0) }.joined()
    }
}