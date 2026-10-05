import Foundation
import CVDocumentModel

/// The page the renderers print on. Every page keeps `verticalMarginPoints` free at its top and bottom, which a design's
/// padding cannot do past the first page; the left and right margins are the design's (markup-contract.md, "Pages").
public struct PageSetup: Sendable, Equatable {
    public var widthPoints: Double, heightPoints: Double, maxPages: Int, verticalMarginPoints: Double
    public static let a4 = PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 4)
    public init(widthPoints: Double, heightPoints: Double, maxPages: Int, verticalMarginPoints: Double = 36) {
        self.widthPoints = widthPoints; self.heightPoints = heightPoints; self.maxPages = maxPages
        self.verticalMarginPoints = verticalMarginPoints
    }
}

/// `pageCount` is the number of pages in `data`; `requiredPages` is how many the content needed.
/// Truncation is derived, never self-declared.
public struct RenderedPDF: Sendable, Equatable {
    public var data: Data, pageCount: Int, requiredPages: Int
    public var truncated: Bool { requiredPages > pageCount }
    public init(data: Data, pageCount: Int, requiredPages: Int) {
        self.data = data; self.pageCount = pageCount; self.requiredPages = requiredPages
    }
}

/// Outbound port: one adapter per platform (ADR 0003). Sendable, async, not actor-constrained (DIP).
public protocol PDFRendering: Sendable {
    func render(html: String, page: PageSetup) async throws -> RenderedPDF
}

/// Reads what a PDF really contains (PDFKit on Apple platforms). Used by the export workflow to check
/// every export, and by the renderer contract suite.
public protocol PDFInspecting: Sendable {
    func pageCount(of data: Data) -> Int?
    func text(of data: Data) -> String?
}
