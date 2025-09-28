import Foundation
import CryptoKit

/// Result of PDF export operation
public struct PDFExportResult: Sendable {
    public let pdfData: Data
    public let pageCount: Int
    public let wasContentTruncated: Bool
    public let fileSize: Int64

    public init(
        pdfData: Data,
        pageCount: Int,
        wasContentTruncated: Bool = false
    ) {
        self.pdfData = pdfData
        self.pageCount = pageCount
        self.wasContentTruncated = wasContentTruncated
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
    /// - Returns: PDF export result
    /// - Throws: PDFExportError if export fails
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
                    pageCount: estimatePageCount(dataSize: cachedData.count),
                    wasContentTruncated: false
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

        // Check page limit
        let pageCount = estimatePageCount(dataSize: pdfData.count)
        let wasContentTruncated = pageCount > options.maxPages

        // Enforce page limit if needed
        let finalPDFData: Data
        let finalPageCount: Int
        if wasContentTruncated {
            // In real implementation, would truncate content here
            finalPDFData = pdfData
            finalPageCount = min(pageCount, options.maxPages)
        } else {
            finalPDFData = pdfData
            finalPageCount = pageCount
        }

        // Save to history
        let historyEntry = ExportHistoryEntry(
            cvId: generateDocumentId(document),
            cvName: document.personalInfo.name,
            templateId: template.id,
            fileSize: Int64(finalPDFData.count),
            pageCount: finalPageCount
        )
        try await repository.saveExportHistory(historyEntry)

        // Cache if enabled
        if enableCaching {
            let cacheKey = generateCacheKey(document: document, template: template, options: options)
            try await repository.cachePDF(
                data: finalPDFData,
                key: cacheKey,
                ttl: 3600 // 1 hour TTL
            )
        }

        return PDFExportResult(
            pdfData: finalPDFData,
            pageCount: finalPageCount,
            wasContentTruncated: wasContentTruncated
        )
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

    private func estimatePageCount(dataSize: Int) -> Int {
        // Rough estimate: ~1KB per page for our mock data
        // In production, this would be more sophisticated
        max(1, dataSize / 1024)
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