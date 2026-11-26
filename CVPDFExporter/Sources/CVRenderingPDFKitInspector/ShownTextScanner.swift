#if canImport(PDFKit)   // Apple-only adapter (R11): the whole file is platform-guarded
import CoreGraphics

/// One operator of a page's content that shows text: where its first glyph starts on the page (page space, the text
/// rise included) and how tall the font's em is there, the text and graphics transforms included. The size is nil when
/// the operator's font cannot be read from the content: none was set, it is missing from the resources, or it is a
/// Type 3 font, whose glyphs are sized by a matrix of their own.
struct ShownText: Equatable {
    let x: Double
    let y: Double
    let size: Double?
}

/// The text a page's content shows, read from the content stream's own operators rather than from PDFKit's font
/// attributes, which resolve every embedded font by name (slow and verbose for the system font; #562).
struct ShownTextReading {
    var runs: [ShownText] = []
    /// The form XObjects the content drew and the scan read.
    var formsRead = 0
}

enum ShownTextScanner {
    /// The text `page` shows, in content order. A form nested deeper than `formDepthLimit`, or one with no resources or
    /// an unreadable matrix, is not read: the lines it shows then have no run, and the inspector sizes them as before.
    static func reading(of page: CGPDFPage) -> ShownTextReading {
        guard let table = operatorTable() else { return ShownTextReading() }
        defer { CGPDFOperatorTableRelease(table) }
        let collector = ShownTextCollector(table: table)
        let stream = CGPDFContentStreamCreateWithPage(page)
        defer { CGPDFContentStreamRelease(stream) }
        collector.scan(stream)
        return collector.reading
    }

    static let formDepthLimit = 8

    // MARK: Operators

    private static func operatorTable() -> CGPDFOperatorTableRef? {
        guard let table = CGPDFOperatorTableCreate() else { return nil }
        CGPDFOperatorTableSetCallback(table, "q") { _, info in collecting(info)?.save() }
        CGPDFOperatorTableSetCallback(table, "Q") { _, info in collecting(info)?.restore() }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, info in
            guard let collector = collecting(info), let m = popNumbers(scanner, 6) else { return }
            collector.state.ctm = CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5])
                .concatenating(collector.state.ctm)
        }
        CGPDFOperatorTableSetCallback(table, "BT") { _, info in collecting(info)?.beginText() }
        CGPDFOperatorTableSetCallback(table, "Tf") { scanner, info in
            var name: UnsafePointer<CChar>?
            guard let collector = collecting(info), let size = popNumbers(scanner, 1),
                  CGPDFScannerPopName(scanner, &name), let name else { return }
            collector.state.fontSize = size[0]
            collector.state.fontIsReadable = isSizedByItsEm(font: name, in: CGPDFScannerGetContentStream(scanner))
        }
        CGPDFOperatorTableSetCallback(table, "TL") { scanner, info in
            guard let collector = collecting(info), let leading = popNumbers(scanner, 1) else { return }
            collector.state.leading = leading[0]
        }
        CGPDFOperatorTableSetCallback(table, "Ts") { scanner, info in
            guard let collector = collecting(info), let rise = popNumbers(scanner, 1) else { return }
            collector.state.rise = rise[0]
        }
        CGPDFOperatorTableSetCallback(table, "Tz") { scanner, info in
            guard let collector = collecting(info), let scale = popNumbers(scanner, 1) else { return }
            collector.state.horizontalScale = scale[0] / 100
        }
        CGPDFOperatorTableSetCallback(table, "Td") { scanner, info in
            guard let collector = collecting(info), let offset = popNumbers(scanner, 2) else { return }
            collector.moveLine(by: offset[0], offset[1])
        }
        CGPDFOperatorTableSetCallback(table, "TD") { scanner, info in
            guard let collector = collecting(info), let offset = popNumbers(scanner, 2) else { return }
            collector.state.leading = -offset[1]
            collector.moveLine(by: offset[0], offset[1])
        }
        CGPDFOperatorTableSetCallback(table, "Tm") { scanner, info in
            guard let collector = collecting(info), let m = popNumbers(scanner, 6) else { return }
            collector.setTextMatrix(CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5]))
        }
        CGPDFOperatorTableSetCallback(table, "T*") { _, info in collecting(info)?.nextLine() }
        CGPDFOperatorTableSetCallback(table, "Tj") { scanner, info in
            guard let collector = collecting(info), showsAGlyph(popString(scanner)) else { return }
            collector.show(after: 0)
        }
        CGPDFOperatorTableSetCallback(table, "'") { scanner, info in
            guard let collector = collecting(info) else { return }
            let shows = showsAGlyph(popString(scanner))
            collector.nextLine()
            if shows { collector.show(after: 0) }
        }
        CGPDFOperatorTableSetCallback(table, "\"") { scanner, info in
            guard let collector = collecting(info) else { return }
            let shows = showsAGlyph(popString(scanner))
            collector.nextLine()
            if shows { collector.show(after: 0) }
        }
        CGPDFOperatorTableSetCallback(table, "TJ") { scanner, info in
            var array: CGPDFArrayRef?
            guard let collector = collecting(info), CGPDFScannerPopArray(scanner, &array), let array,
                  let adjustment = adjustmentBeforeTheFirstGlyph(array) else { return }
            collector.show(after: adjustment)
        }
        CGPDFOperatorTableSetCallback(table, "Do") { scanner, info in
            var name: UnsafePointer<CChar>?
            guard let collector = collecting(info), CGPDFScannerPopName(scanner, &name), let name else { return }
            collector.drawForm(named: name, from: CGPDFScannerGetContentStream(scanner))
        }
        return table
    }
}

// MARK: Operands

private func collecting(_ info: UnsafeMutableRawPointer?) -> ShownTextCollector? {
    info.map { Unmanaged<ShownTextCollector>.fromOpaque($0).takeUnretainedValue() }
}

/// The last `count` operands, in the order the content wrote them, or nil when one of them is not a number.
private func popNumbers(_ scanner: CGPDFScannerRef, _ count: Int) -> [CGFloat]? {
    var values: [CGFloat] = []
    for _ in 0..<count {
        var value: CGPDFReal = 0
        guard CGPDFScannerPopNumber(scanner, &value) else { return nil }
        values.append(value)
    }
    return values.reversed()
}

/// Whether the font `name` of `stream`'s resources is one whose glyphs the `Tf` size scales: any font but Type 3.
private func isSizedByItsEm(font name: UnsafePointer<CChar>, in stream: CGPDFContentStreamRef) -> Bool {
    var dictionary: CGPDFDictionaryRef?
    var subtype: UnsafePointer<CChar>?
    guard let object = CGPDFContentStreamGetResource(stream, "Font", name),
          CGPDFObjectGetValue(object, .dictionary, &dictionary), let dictionary,
          CGPDFDictionaryGetName(dictionary, "Subtype", &subtype), let subtype else { return false }
    return String(cString: subtype) != "Type3"
}

private func popString(_ scanner: CGPDFScannerRef) -> CGPDFStringRef? {
    var string: CGPDFStringRef?
    return CGPDFScannerPopString(scanner, &string) ? string : nil
}

private func showsAGlyph(_ string: CGPDFStringRef?) -> Bool {
    string.map { CGPDFStringGetLength($0) > 0 } ?? false
}

/// The sum of the position adjustments a `TJ` array makes before its first glyph (thousandths of the em, moving the
/// glyph left when positive), or nil when the array shows no glyph.
private func adjustmentBeforeTheFirstGlyph(_ array: CGPDFArrayRef) -> CGFloat? {
    var adjustment: CGFloat = 0
    for index in 0..<CGPDFArrayGetCount(array) {
        var string: CGPDFStringRef?
        var number: CGPDFReal = 0
        if CGPDFArrayGetString(array, index, &string) {
            if showsAGlyph(string) { return adjustment }
        } else if CGPDFArrayGetNumber(array, index, &number) {
            adjustment += number
        }
    }
    return nil
}

/// The state the scan keeps between operators: the graphics state stack, the text matrices of the current text object,
/// and what it found.
private final class ShownTextCollector {
    struct GraphicsState {
        var ctm = CGAffineTransform.identity
        var fontSize: CGFloat?
        var fontIsReadable = false
        var leading: CGFloat = 0
        var rise: CGFloat = 0
        var horizontalScale: CGFloat = 1
    }

    var state = GraphicsState()
    private(set) var reading = ShownTextReading()
    private var saved: [GraphicsState] = []
    private var textMatrix = CGAffineTransform.identity
    private var lineMatrix = CGAffineTransform.identity
    private var depth = 0
    private let table: CGPDFOperatorTableRef

    init(table: CGPDFOperatorTableRef) { self.table = table }

    func scan(_ stream: CGPDFContentStreamRef) {
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(self).toOpaque())
        defer { CGPDFScannerRelease(scanner) }
        _ = CGPDFScannerScan(scanner)
    }

    func save() { saved.append(state) }

    func restore() { if let last = saved.popLast() { state = last } }

    func beginText() { setTextMatrix(.identity) }

    func setTextMatrix(_ matrix: CGAffineTransform) {
        textMatrix = matrix
        lineMatrix = matrix
    }

    func moveLine(by tx: CGFloat, _ ty: CGFloat) {
        setTextMatrix(CGAffineTransform(translationX: tx, y: ty).concatenating(lineMatrix))
    }

    func nextLine() { moveLine(by: 0, -state.leading) }

    /// Records the run a text-showing operator starts, `adjustment` thousandths of the em left of the text matrix's
    /// origin.
    func show(after adjustment: CGFloat) {
        let fontSize = state.fontSize ?? 0
        let onPage = textMatrix.concatenating(state.ctm)
        let start = CGPoint(x: -adjustment / 1000 * fontSize * state.horizontalScale, y: state.rise).applying(onPage)
        let size = state.fontSize != nil && state.fontIsReadable ? Double(abs(fontSize) * hypot(onPage.c, onPage.d)) : nil
        reading.runs.append(ShownText(x: Double(start.x), y: Double(start.y), size: size))
    }

    /// Reads the form XObject `name` of `parent`'s resources as the content draws it: in its own graphics state, its
    /// matrix concatenated to the current transform. Images and every other kind of XObject show no text.
    func drawForm(named name: UnsafePointer<CChar>, from parent: CGPDFContentStreamRef) {
        guard depth < ShownTextScanner.formDepthLimit, let object = CGPDFContentStreamGetResource(parent, "XObject", name) else { return }
        var stream: CGPDFStreamRef?
        var subtype: UnsafePointer<CChar>?
        var resources: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(object, .stream, &stream), let stream, let dictionary = CGPDFStreamGetDictionary(stream),
              CGPDFDictionaryGetName(dictionary, "Subtype", &subtype), let subtype, String(cString: subtype) == "Form",
              CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources), let resources,
              let matrix = Self.matrix(of: dictionary) else { return }
        let form = CGPDFContentStreamCreateWithStream(stream, resources, parent)
        defer { CGPDFContentStreamRelease(form) }
        let outer = (state, saved, textMatrix, lineMatrix)
        saved = []
        state.ctm = matrix.concatenating(state.ctm)
        depth += 1
        reading.formsRead += 1
        scan(form)
        depth -= 1
        (state, saved, textMatrix, lineMatrix) = outer
    }

    /// A form's `/Matrix`: the identity when it has none, nil when it is not six numbers.
    private static func matrix(of dictionary: CGPDFDictionaryRef) -> CGAffineTransform? {
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dictionary, "Matrix", &array), let array else { return .identity }
        guard CGPDFArrayGetCount(array) == 6 else { return nil }
        var m: [CGFloat] = []
        for index in 0..<6 {
            var value: CGPDFReal = 0
            guard CGPDFArrayGetNumber(array, index, &value) else { return nil }
            m.append(value)
        }
        return CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5])
    }
}
#endif
