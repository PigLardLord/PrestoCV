#if canImport(PDFKit)   // Apple-only adapter (R11): the whole file is platform-guarded
import Foundation
import PDFKit
import CVRendering
#if os(macOS)
import AppKit
private typealias PlatformFont = NSFont
#else
import UIKit
private typealias PlatformFont = UIFont
#endif

/// Reads what a PDF really contains, with PDFKit: its page count, the text of every page in order, and where each line
/// of text lies and how big it is printed. The export workflow checks every export with it, and the renderer contract
/// suite and the native renderer tests check the renderers (R8, ADR 0011).
///
/// A line's box is in page space (points, origin at the lower left of the media box), as PDFKit gives it whatever the
/// page's rotation. Text drawn wholly outside the page is not in the page's text at all, so completeness reports it.
/// A line's glyph height is the smallest font size PDFKit gives for its characters, the page's transform included; a
/// line with a character that has no font has none, so the geometry check rejects it.
public struct PDFKitInspector: PDFLayoutInspecting {
    public init() {}

    public func pageCount(of data: Data) -> Int? { PDFDocument(data: data)?.pageCount }

    public func text(of data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }
        return (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }.joined(separator: "\n")
    }

    public func layout(of data: Data) -> PDFLayout? {
        guard let document = PDFDocument(data: data) else { return nil }
        var pages: [PDFBox] = []
        var lines: [PDFTextLine] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { return nil }
            pages.append(Self.box(page.bounds(for: .mediaBox)))
            let characters = page.numberOfCharacters
            guard characters > 0, let selection = page.selection(for: NSRange(location: 0, length: characters)) else { continue }
            for line in selection.selectionsByLine() {
                let text = (line.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                lines.append(PDFTextLine(pageIndex: index, text: text, box: Self.box(line.bounds(for: page)),
                                         glyphHeight: Self.glyphHeight(of: line.attributedString)))
            }
        }
        return PDFLayout(pages: pages, lines: lines)
    }

    /// The smallest font size in `text`, or nil when `text` is empty or any of its characters has no font.
    static func glyphHeight(of text: NSAttributedString?) -> Double? {
        guard let text, text.length > 0 else { return nil }
        var smallest = Double.infinity
        var everyCharacterHasAFont = true
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, _, stop in
            guard let font = value as? PlatformFont else {
                everyCharacterHasAFont = false
                stop.pointee = true
                return
            }
            smallest = min(smallest, Double(font.pointSize))
        }
        return everyCharacterHasAFont ? smallest : nil
    }

    private static func box(_ rect: CGRect) -> PDFBox {
        PDFBox(x: Double(rect.minX), y: Double(rect.minY), width: Double(rect.width), height: Double(rect.height))
    }
}
#endif
