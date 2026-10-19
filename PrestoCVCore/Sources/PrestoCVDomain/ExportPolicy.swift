import Foundation

/// How version 1 exports a CV: on an A4 page, with a margin of 0.6 in (43 points) on every side, since the usual inch
/// leaves too little room for text on A4, on at most 10 pages, and only once the CV says who its person is and how to
/// reach them. The preview follows the same page.
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

    /// What keeps a CV from being exported; nil when nothing does. White space is not a value.
    public func blocker(name: String, email: String) -> ExportBlocker? {
        let missing = [name, email].contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return missing ? .missingNameOrEmail : nil
    }
}

/// Why a CV cannot be exported yet
public enum ExportBlocker: Hashable, Sendable {
    /// A PDF names its person and says how to reach them: the name and the e-mail are required
    case missingNameOrEmail
}
