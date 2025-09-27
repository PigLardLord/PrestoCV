import Foundation

// MARK: - Export Options

/// Export configuration for PDF generation
/// Sprint 1: Added template selection support
public struct ExportOptions: Sendable {
    public let pageSize: PageSize
    public let margins: PDFMargins
    public let templateId: String?

    public init(
        pageSize: PageSize = .a4,
        margins: PDFMargins = .standard,
        templateId: String? = nil
    ) {
        self.pageSize = pageSize
        self.margins = margins
        self.templateId = templateId
    }

    public static let `default` = ExportOptions()
}

// MARK: - Page Size

public struct PageSize: Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    // Predefined page sizes
    public static let a4 = PageSize(width: 595.28, height: 841.89) // Points
    public static let letter = PageSize(width: 612.0, height: 792.0) // Points
}

// MARK: - PDF Margins

public struct PDFMargins: Sendable {
    public let top: Double
    public let left: Double
    public let bottom: Double
    public let right: Double

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static func uniform(_ value: Double) -> PDFMargins {
        return PDFMargins(top: value, left: value, bottom: value, right: value)
    }

    public static let standard = PDFMargins(top: 72, left: 72, bottom: 72, right: 72) // 1 inch
}