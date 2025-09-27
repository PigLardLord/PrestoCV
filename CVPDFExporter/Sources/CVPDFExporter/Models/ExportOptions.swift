import Foundation

// MARK: - Export Options

/// Export configuration for PDF generation
/// Sprint 0: Minimal options for MVP
public struct ExportOptions: Sendable {
    public let pageSize: PageSize
    public let margins: EdgeInsets

    public init(
        pageSize: PageSize = .a4,
        margins: EdgeInsets = .default
    ) {
        self.pageSize = pageSize
        self.margins = margins
    }

    public static let `default` = ExportOptions()
}

// MARK: - Page Size

public enum PageSize: Sendable {
    case a4
    case letter

    public var dimensions: (width: Double, height: Double) {
        switch self {
        case .a4:
            return (595.28, 841.89) // Points
        case .letter:
            return (612.0, 792.0) // Points
        }
    }
}

// MARK: - Edge Insets

public struct EdgeInsets: Sendable {
    public let top: Double
    public let right: Double
    public let bottom: Double
    public let left: Double

    public init(top: Double, right: Double, bottom: Double, left: Double) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }

    public init(all: Double) {
        self.init(top: all, right: all, bottom: all, left: all)
    }

    public static let `default` = EdgeInsets(all: 36.0) // 0.5 inch
}