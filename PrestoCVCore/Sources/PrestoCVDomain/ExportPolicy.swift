import Foundation

/// The page version 1 exports a CV on: A4, with a margin of 0.6 in (43 points) on every side, since the usual inch leaves
/// too little room for text on A4, and at most 10 pages. The preview follows the same page. What a CV needs before it is
/// exported is `ExportReadiness`.
public struct ExportPolicy: Hashable, Sendable {
    /// The page, in points
    public let pageWidth: Double, pageHeight: Double
    /// The white border of every page, in points
    public let margin: Double
    /// The longest CV the export accepts, for the preview and the PDF alike
    public let maxPages: Int

    public init(pageWidth: Double, pageHeight: Double, margin: Double, maxPages: Int) {
        self.pageWidth = pageWidth; self.pageHeight = pageHeight; self.margin = margin; self.maxPages = maxPages
    }

    public static let standard = ExportPolicy(pageWidth: 595.28, pageHeight: 841.89, margin: 43, maxPages: 10)
}
