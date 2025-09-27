import Foundation
import CoreGraphics

// MARK: - HTML to PDF Renderer Protocol

/// Protocol for converting HTML to PDF
/// Sprint 0: Basic protocol definition
/// This protocol is platform-agnostic - implementations handle platform specifics
public protocol HTMLToPDFRenderer: Sendable {

    /// Convert HTML string to PDF data
    func renderToPDF(html: String, options: ExportOptions) async throws -> Data
}