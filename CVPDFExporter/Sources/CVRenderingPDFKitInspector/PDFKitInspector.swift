#if canImport(PDFKit)   // Apple-only adapter (PlatformAdapters): the whole file is platform-guarded
import Foundation
import PDFKit
import CVRendering

/// Reads what a PDF really contains, with PDFKit: its page count, and the text of every page in order. The export
/// workflow checks every export with it, and the renderer contract suite checks the renderers (ValidatingBoundary, ADR 0011).
public struct PDFKitInspector: PDFInspecting {
    public init() {}

    public func pageCount(of data: Data) -> Int? { PDFDocument(data: data)?.pageCount }

    public func text(of data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }
        return (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }.joined(separator: "\n")
    }
}
#endif
