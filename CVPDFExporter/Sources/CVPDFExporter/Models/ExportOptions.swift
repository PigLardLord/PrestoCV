import Foundation

// MARK: - Export Options

/// Export configuration for PDF generation
/// Sprint 1: Added template selection support
/// Sprint 2: Added customization options and page limit
public struct ExportOptions: Sendable {
    public let pageSize: PageSize
    public let margins: EdgeInsets
    public let templateId: String?
    public let customization: CustomizationOptions
    public let maxPages: Int

    public init(
        pageSize: PageSize = .a4,
        margins: EdgeInsets = .default,
        templateId: String? = nil,
        customization: CustomizationOptions = CustomizationOptions(),
        maxPages: Int = 4
    ) {
        self.pageSize = pageSize
        self.margins = margins
        self.templateId = templateId
        self.customization = customization
        self.maxPages = maxPages
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

// MARK: - Edge Insets

public struct EdgeInsets: Sendable {
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

    public static func uniform(_ value: Double) -> EdgeInsets {
        return EdgeInsets(top: value, left: value, bottom: value, right: value)
    }

    public static let `default` = EdgeInsets(top: 72, left: 72, bottom: 72, right: 72) // 1 inch
}
