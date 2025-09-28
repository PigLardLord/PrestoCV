import Foundation

/// Protocol defining PDF rendering capabilities
/// Following Interface Segregation Principle - focused on single responsibility
public protocol PDFRendererProtocol: Sendable {
    /// Renders HTML content to PDF data
    /// - Parameters:
    ///   - html: The HTML string to render
    ///   - options: Export configuration options
    /// - Returns: PDF data
    /// - Throws: PDFExportError if rendering fails
    func renderToPDF(html: String, options: ExportOptions) async throws -> Data

    /// Checks if renderer is available on current platform
    var isAvailable: Bool { get }

    /// Maximum number of pages the renderer supports
    var maxPages: Int { get }
}