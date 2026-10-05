#if os(macOS)   // macOS-only adapter (PlatformAdapters): the whole file is platform-guarded
import AppKit
import CVRendering

/// Keeps the first pages of a PDF, off the main actor.
enum PDFFirstPages {
    /// Reads the page count from the PDF and keeps the first pages up to the limit, checking for cancellation on every
    /// page. `limit` is at least 1.
    static func keep(of full: Data, upTo limit: Int) async throws -> RenderedPDF {
        let document = try openDocument(full)
        let required = document.numberOfPages
        let kept = min(required, limit)
        guard kept < required else { return RenderedPDF(data: full, pageCount: kept, requiredPages: required) }
        return RenderedPDF(data: try copyPages(kept, of: document), pageCount: kept, requiredPages: required)
    }

    private static func openDocument(_ data: Data) throws -> CGPDFDocument {
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider), document.numberOfPages > 0 else {
            throw MacPDFRenderer.Failure.unreadableOutput
        }
        return document
    }

    private static func copyPages(_ count: Int, of document: CGPDFDocument) throws -> Data {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData), let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw MacPDFRenderer.Failure.unreadableOutput
        }
        for number in 1...count {
            try Task.checkCancellation()
            try copyPage(number, of: document, to: context)
        }
        context.closePDF()
        return output as Data
    }

    private static func copyPage(_ number: Int, of document: CGPDFDocument, to context: CGContext) throws {
        guard let page = document.page(at: number) else { throw MacPDFRenderer.Failure.unreadableOutput }
        var box = page.getBoxRect(.mediaBox)
        context.beginPage(mediaBox: &box)
        context.drawPDFPage(page)
        context.endPage()
    }
}
#endif
