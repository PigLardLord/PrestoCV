import Foundation
import CoreGraphics

// MARK: - PDF Export Engine Protocol

/// Main entry point for PDF export functionality
/// Sprint 0: Basic implementation with static template
/// Platform-agnostic - renderer is injected
public protocol PDFExportEngine: Sendable {

    /// Export CV to PDF using static template
    func exportToPDF(document: CVDocument, options: ExportOptions) async throws -> Data
}

/// PDF export errors
public enum PDFExportError: LocalizedError {
    case renderingFailed(String)
    case invalidContent(String)

    public var errorDescription: String? {
        switch self {
        case .renderingFailed(let reason):
            return "PDF rendering failed: \(reason)"
        case .invalidContent(let reason):
            return "Invalid content: \(reason)"
        }
    }
}