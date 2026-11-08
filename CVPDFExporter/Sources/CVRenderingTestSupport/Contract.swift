import Foundation
import CVRendering
import CVDesignCatalog

/// Linux inspector for the uncompressed PDFs written by `FakePDFRenderer`, whose text is UTF-8.
/// Apple platforms use PDFKit.
public struct MinimalPDFInspector: PDFLayoutInspecting {
    public init() {}
    public func pageCount(of data: Data) -> Int? {
        guard let s = String(data: data, encoding: .utf8), s.hasPrefix("%PDF-"), s.contains("%%EOF") else { return nil }
        return s.components(separatedBy: "/Type /Page\n").count - 1
    }
    public func text(of data: Data) -> String? {
        guard pageCount(of: data) != nil, let s = String(data: data, encoding: .utf8) else { return nil }
        return Self.shownStrings(in: s[...]).joined(separator: "\n")
    }

    /// Reads the layout `FakePDFRenderer` wrote: each page's media box, and each line at its text position, one
    /// leading below the last, as high as its font size. The fake writes no glyph widths, so a box is 0 wide.
    public func layout(of data: Data) -> PDFLayout? {
        guard pageCount(of: data) != nil, let s = String(data: data, encoding: .utf8) else { return nil }
        let pageDictionary = /\/Type \/Page\n\/Parent 2 0 R \/MediaBox \[(\S+) (\S+) (\S+) (\S+)\] \/Contents (\d+) 0 R/
        let textState = /BT \/F1 (\S+) Tf (\S+) TL (\S+) (\S+) Td\n/
        var pages: [PDFBox] = [], lines: [PDFTextLine] = []
        for match in s.matches(of: pageDictionary) {
            guard let left = Double(match.output.1), let bottom = Double(match.output.2),
                  let right = Double(match.output.3), let top = Double(match.output.4),
                  let stream = s.range(of: "\n\(match.output.5) 0 obj\n"),
                  let end = s.range(of: "\nendstream", range: stream.upperBound..<s.endIndex),
                  let state = s[stream.upperBound..<end.lowerBound].firstMatch(of: textState),
                  let size = Double(state.output.1), let leading = Double(state.output.2),
                  let x = Double(state.output.3), let y = Double(state.output.4) else { return nil }
            let page = pages.count
            pages.append(PDFBox(x: left, y: bottom, width: right - left, height: top - bottom))
            for (row, text) in Self.shownStrings(in: s[state.range.upperBound..<end.lowerBound]).enumerated() {
                let box = PDFBox(x: x, y: y - leading * Double(row), width: 0, height: size)
                lines.append(PDFTextLine(pageIndex: page, text: text, box: box, glyphHeight: size))
            }
        }
        return PDFLayout(pages: pages, lines: lines)
    }

    /// The strings shown with `Tj`, unescaped, in order.
    static func shownStrings(in s: Substring) -> [String] {
        var out: [String] = []
        var range = s.startIndex..<s.endIndex
        while let r = s.range(of: #"\((?:\\.|[^\\)])*\) Tj"#, options: .regularExpression, range: range) {
            let literal = s[s.index(after: r.lowerBound)..<s.index(r.upperBound, offsetBy: -4)]
            out.append(literal.replacingOccurrences(of: #"\\(.)"#, with: "$1", options: .regularExpression))
            range = r.upperBound..<s.endIndex
        }
        return out
    }
}

/// Fake renderer that writes a real (uncompressed, text-only) PDF: 40 lines per page, placed as `placement` says.
public struct FakePDFRenderer: PDFRendering {
    /// Where the text goes and how big it is, in points: the first line's origin, the font size, and the distance
    /// from one line to the next. A placement off the page or below the minimum glyph height makes a PDF that the
    /// geometric check rejects.
    public struct TextPlacement: Sendable, Equatable {
        public var fontSize: Double, leading: Double, x: Double, y: Double
        public static let regular = TextPlacement(fontSize: 10, leading: 12, x: 40, y: 800)
        public init(fontSize: Double, leading: Double, x: Double, y: Double) {
            self.fontSize = fontSize; self.leading = leading; self.x = x; self.y = y
        }
    }
    let placement: TextPlacement
    public init() { placement = .regular }
    public init(placement: TextPlacement) { self.placement = placement }
    public func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        try Task.checkCancellation()
        let text = html.replacingOccurrences(of: #"<[^>]+>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"").replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
        let lines = text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let pages = stride(from: 0, to: max(lines.count, 1), by: 40).map { Array(lines[$0..<min($0 + 40, lines.count)]) }
        let kept = Array(pages.prefix(page.maxPages))
        for _ in kept { await Task.yield(); try Task.checkCancellation() }   // in-flight cancellation point
        return RenderedPDF(data: Self.pdf(pages: kept, placement: placement), pageCount: kept.count, requiredPages: pages.count)
    }

    static func pdf(pages: [[String]], placement: TextPlacement) -> Data {
        var objects: [String] = ["<< /Type /Catalog /Pages 2 0 R >>", ""]
        var kids: [String] = []
        for lines in pages {
            let body = lines.map { "(" + $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "(", with: "\\(")
                .replacingOccurrences(of: ")", with: "\\)") + ") Tj T*" }.joined(separator: "\n")
            let p = placement
            let stream = "BT /F1 \(number(p.fontSize)) Tf \(number(p.leading)) TL \(number(p.x)) \(number(p.y)) Td\n\(body)\nET"
            objects.append("<< /Length \(stream.utf8.count) >>\nstream\n\(stream)\nendstream")
            let contentRef = objects.count
            objects.append("<< /Type /Page\n/Parent 2 0 R /MediaBox [0 0 595 842] /Contents \(contentRef) 0 R /Resources << /Font << /F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> >> >> >>")
            kids.append("\(objects.count) 0 R")
        }
        objects[1] = "<< /Type /Pages /Kids [\(kids.joined(separator: " "))] /Count \(kids.count) >>"
        var out = "%PDF-1.4\n", offsets: [Int] = []
        for (i, o) in objects.enumerated() { offsets.append(out.utf8.count); out += "\(i + 1) 0 obj\n\(o)\nendobj\n" }
        let xref = out.utf8.count
        out += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n" + offsets.map { String(format: "%010d 00000 n \n", $0) }.joined()
        out += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(xref)\n%%EOF\n"
        return Data(out.utf8)
    }

    /// A PDF number: whole values without a decimal point, others as Swift prints them.
    static func number(_ value: Double) -> String {
        value.rounded() == value && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }
}

public enum PDFRenderingContractFailure: Error, Equatable {
    case notAPDF, fixtureTruncated, requiredPagesMisreported(reported: Int, actual: Int), pageCountMismatch(reported: Int, actual: Int), contentMissing(String),
         truncationNotReported, cancellationIgnored
}

/// Contract every PDFRendering adapter must pass (R10, ADR 0003). It checks what the PDF contains,
/// through an inspector, not what the renderer says about it.
public enum PDFRenderingContract {
    public static func verify(_ renderer: some PDFRendering, inspector: some PDFInspecting,
                              html: String, expectedText: [String]) async throws {
        // expectedText: the builder's text nodes; checked occurrence by occurrence (DocumentCompleteness).
        let full = try await renderer.render(html: html, page: .a4)
        guard let pages = inspector.pageCount(of: full.data), let text = inspector.text(of: full.data) else {
            throw PDFRenderingContractFailure.notAPDF
        }
        guard pages == full.pageCount else { throw PDFRenderingContractFailure.pageCountMismatch(reported: full.pageCount, actual: pages) }
        // A truncated fixture is a failure, never a reason to skip the content check (security review C4).
        guard !full.truncated else { throw PDFRenderingContractFailure.fixtureTruncated }
        if let first = DocumentCompleteness.missing(in: text, expected: expectedText).first { throw PDFRenderingContractFailure.contentMissing(first) }

        let long = html + String(repeating: "<p>line</p>", count: 400)
        let limited = try await renderer.render(html: long, page: PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 1))
        guard inspector.pageCount(of: limited.data) == 1, limited.pageCount == 1 else {
            throw PDFRenderingContractFailure.pageCountMismatch(reported: limited.pageCount, actual: inspector.pageCount(of: limited.data) ?? -1)
        }
        guard limited.truncated else { throw PDFRenderingContractFailure.truncationNotReported }
        // requiredPages is checked against an unlimited render, so a renderer cannot declare truncation it did not do.
        let unlimited = try await renderer.render(html: long, page: PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 10_000))
        let actual = inspector.pageCount(of: unlimited.data) ?? -1
        guard !unlimited.truncated, actual == unlimited.pageCount, limited.requiredPages == actual else {
            throw PDFRenderingContractFailure.requiredPagesMisreported(reported: limited.requiredPages, actual: actual)
        }

        // Pre-start cancellation, deterministic: the task is created inside an already-cancelled group.
        let cancelled: Bool = await withTaskGroup(of: Bool.self) { group in
            group.cancelAll()
            group.addTask {
                do { _ = try await renderer.render(html: long, page: .a4); return false } catch is CancellationError { return true } catch { return false }
            }
            return await group.next() ?? false
        }
        guard cancelled else { throw PDFRenderingContractFailure.cancellationIgnored }
    }
}
