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
/// A page's box is its crop box, the part a viewer shows (PDFKit gives the media box when the page has no crop box, and
/// clips a crop box to the media box). A line's box is in page space (points, the PDF's own coordinates, so a crop box
/// need not start at the origin), as PDFKit gives it whatever the page's rotation. Text drawn wholly outside the page is not in the page's text at all, so completeness reports it.
/// A line's glyph height is the smallest size of the text the page's content shows in the line's box, read from the
/// content's own text operators: the font size through the text and graphics transforms, forms included. A line with
/// no such text, or with text whose font the content does not size, takes the smallest font size PDFKit gives for its
/// characters instead (resolving the fonts that way is slow and verbose for the system font, #562); a line with a
/// character that has no font then has none, so the geometry check rejects it. The scan does not read glyph widths, so
/// text shown right after other text, with no text positioning between them, starts where the content does not say:
/// every line it may start in is sized by PDFKit's fonts.
public struct PDFKitInspector: PDFLayoutInspecting {
    public init() {}

    public func pageCount(of data: Data) -> Int? { PDFDocument(data: data)?.pageCount }

    public func text(of data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }
        return (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }.joined(separator: "\n")
    }

    public func layout(of data: Data) -> PDFLayout? { reading(of: data)?.layout }

    /// What `layout(of:)` reads, and how: the lines sized from PDFKit's font attributes, and the forms the scan of the
    /// content read.
    struct Reading {
        let layout: PDFLayout
        let linesSizedByAttributedText: Int
        let formsRead: Int
    }

    func reading(of data: Data) -> Reading? {
        guard let document = PDFDocument(data: data) else { return nil }
        var pages: [PDFBox] = []
        var lines: [PDFTextLine] = []
        var sizedByAttributedText = 0
        var formsRead = 0
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { return nil }
            pages.append(Self.box(page.bounds(for: .cropBox)))
            let characters = page.numberOfCharacters
            guard characters > 0, let selection = page.selection(for: NSRange(location: 0, length: characters)) else { continue }
            let printed = selection.selectionsByLine().compactMap { line -> (line: PDFSelection, text: String, box: CGRect)? in
                let text = (line.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : (line, text, line.bounds(for: page))
            }
            let shown = page.pageRef.map(ShownTextScanner.reading(of:)) ?? ShownTextReading()
            formsRead += shown.formsRead
            for (line, size) in zip(printed, Self.smallestSizes(of: shown.runs, in: printed.map(\.box))) {
                var glyphHeight = size
                if glyphHeight == nil {
                    glyphHeight = Self.glyphHeight(of: line.line.attributedString)
                    sizedByAttributedText += 1
                }
                lines.append(PDFTextLine(pageIndex: index, text: line.text, box: Self.box(line.box), glyphHeight: glyphHeight))
            }
        }
        return Reading(layout: PDFLayout(pages: pages, lines: lines), linesSizedByAttributedText: sizedByAttributedText,
                       formsRead: formsRead)
    }

    /// The smallest size of the runs that start in each box, or nil for a box that no run starts in, that holds a run
    /// of unknown size, or that a run whose start is not known exactly may start in. A run starts in the box whose bottom
    /// edge lies nearest its baseline, among the boxes it lies in vertically (a point of slack on either edge) and starts
    /// at most an em, or two points, beside. A run known only to start on a text line may start in every box the line
    /// meets with the same slack, and one that may start anywhere, in every box.
    static func smallestSizes(of runs: [ShownText], in boxes: [CGRect]) -> [Double?] {
        var smallest = [Double?](repeating: nil, count: boxes.count)
        var unknown = [Bool](repeating: false, count: boxes.count)
        for run in runs {
            switch run.start {
            case .at(let x, let y):
                guard let index = box(holdingARunAt: x, y, ofSize: run.size, among: boxes) else { continue }
                if let size = run.size {
                    smallest[index] = min(smallest[index] ?? size, size)
                } else {
                    unknown[index] = true
                }
            case .onTheLine(let x, let y, let dx, let dy):
                for (index, box) in boxes.enumerated() where line(through: x, y, along: dx, dy, meets: reach(of: box, forARunOfSize: run.size)) {
                    unknown[index] = true
                }
            case .anywhere:
                unknown = unknown.map { _ in true }
            }
        }
        return zip(smallest, unknown).map { size, isUnknown in isUnknown ? nil : size }
    }

    /// The box a run of `size` that starts at (`x`, `y`) starts in, as `smallestSizes(of:in:)` matches them.
    private static func box(holdingARunAt x: Double, _ y: Double, ofSize size: Double?, among boxes: [CGRect]) -> Int? {
        var best: (index: Int, cost: Double)?
        for (index, box) in boxes.enumerated() {
            let beside = max(0, Double(box.minX) - x, x - Double(box.maxX))
            guard beside <= max(2, size ?? 0), y >= Double(box.minY) - 1, y <= Double(box.maxY) + 1 else { continue }
            let cost = beside + abs(y - Double(box.minY))
            if best.map({ cost < $0.cost }) ?? true { best = (index, cost) }
        }
        return best?.index
    }

    /// Where a run of `size` that starts in `box` may start: the box with a point of slack above and below, and an em,
    /// or two points, beside.
    private static func reach(of box: CGRect, forARunOfSize size: Double?) -> CGRect {
        box.insetBy(dx: -CGFloat(max(2, size ?? 0)), dy: -1)
    }

    /// Whether the line through (`x`, `y`) in the direction (`dx`, `dy`) meets `rect`: the rectangle's corners do not all
    /// lie on one side of it. A line with no direction meets every rectangle.
    private static func line(through x: Double, _ y: Double, along dx: Double, _ dy: Double, meets rect: CGRect) -> Bool {
        let corners = [(rect.minX, rect.minY), (rect.maxX, rect.minY), (rect.minX, rect.maxY), (rect.maxX, rect.maxY)]
        let sides = corners.map { dx * (Double($0.1) - y) - dy * (Double($0.0) - x) }
        return sides.contains { $0 <= 0 } && sides.contains { $0 >= 0 }
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
