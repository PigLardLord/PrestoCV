#if canImport(PDFKit)   // Apple-only adapter (R11): the whole file is platform-guarded
import CoreGraphics

/// One operator of a page's content that shows text: where its first glyph starts on the page (page space, the text
/// rise included) and how tall the font's em is there, the text and graphics transforms included. The size is nil when
/// the operator's font cannot be read from the content: none was set, it is missing from the resources, or it is a
/// Type 3 font, whose glyphs are sized by a matrix of their own.
struct ShownText: Equatable {
    /// Where the run's first glyph starts, as far as the content tells without the glyphs' widths, which the scan does
    /// not read: showing text moves the text position by the width of what it shows.
    enum Start: Equatable {
        /// At this point: the run is the first one since the text position was set.
        case at(x: Double, y: Double)
        /// Somewhere on the text line through this point, which runs in the direction (`dx`, `dy`): the run follows
        /// others, set in fonts that write across, with no text positioning between them.
        case onTheLine(x: Double, y: Double, dx: Double, dy: Double)
        /// Anywhere: the run, or one before it with no text positioning between them, is set in a font that may write
        /// vertically (a Type 0 font whose CMap writes vertically, or one missing from the resources).
        case anywhere
    }

    let start: Start
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
            let font = setting(of: name, in: CGPDFScannerGetContentStream(scanner))
            collector.state.fontSize = size[0]
            collector.state.fontIsReadable = font.sizedByItsEm
            collector.state.fontWritesAcross = font.writesAcross
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
            guard let collector = collecting(info), CGPDFScannerPopArray(scanner, &array), let array else { return }
            let before = adjustments(beforeTheFirstGlyphOf: array)
            if before.showsAGlyph {
                collector.show(after: before.sum)
            } else {
                collector.move(by: before.sum)
            }
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

/// How the font `name` of `stream`'s resources sets its glyphs: whether the `Tf` size scales them (any font but Type 3),
/// and whether it writes across, moving the text position along the text line (any font but a Type 0 one whose CMap
/// writes vertically). A font missing from the resources does neither.
private func setting(of name: UnsafePointer<CChar>, in stream: CGPDFContentStreamRef) -> (sizedByItsEm: Bool, writesAcross: Bool) {
    var dictionary: CGPDFDictionaryRef?
    var subtype: UnsafePointer<CChar>?
    guard let object = CGPDFContentStreamGetResource(stream, "Font", name),
          CGPDFObjectGetValue(object, .dictionary, &dictionary), let dictionary,
          CGPDFDictionaryGetName(dictionary, "Subtype", &subtype), let subtype else { return (false, false) }
    let kind = String(cString: subtype)
    return (kind != "Type3", kind != "Type0" || !writesVertically(dictionary))
}

/// Whether the Type 0 font `font` writes vertically: its CMap is a predefined one whose name ends in `-V`, or an
/// embedded one with writing mode 1.
private func writesVertically(_ font: CGPDFDictionaryRef) -> Bool {
    var name: UnsafePointer<CChar>?
    if CGPDFDictionaryGetName(font, "Encoding", &name), let name { return String(cString: name).hasSuffix("-V") }
    var cmap: CGPDFStreamRef?
    var mode: CGPDFInteger = 0
    guard CGPDFDictionaryGetStream(font, "Encoding", &cmap), let cmap, let info = CGPDFStreamGetDictionary(cmap) else { return false }
    return CGPDFDictionaryGetInteger(info, "WMode", &mode) && mode == 1
}

private func popString(_ scanner: CGPDFScannerRef) -> CGPDFStringRef? {
    var string: CGPDFStringRef?
    return CGPDFScannerPopString(scanner, &string) ? string : nil
}

private func showsAGlyph(_ string: CGPDFStringRef?) -> Bool {
    string.map { CGPDFStringGetLength($0) > 0 } ?? false
}

/// The sum of the position adjustments a `TJ` array makes before its first glyph (thousandths of the em, moving the
/// text position left when positive), and whether the array shows a glyph at all: when it does not, the sum is all the
/// array does.
private func adjustments(beforeTheFirstGlyphOf array: CGPDFArrayRef) -> (sum: CGFloat, showsAGlyph: Bool) {
    var adjustment: CGFloat = 0
    for index in 0..<CGPDFArrayGetCount(array) {
        var string: CGPDFStringRef?
        var number: CGPDFReal = 0
        if CGPDFArrayGetString(array, index, &string) {
            if showsAGlyph(string) { return (adjustment, true) }
        } else if CGPDFArrayGetNumber(array, index, &number) {
            adjustment += number
        }
    }
    return (adjustment, false)
}

/// The state the scan keeps between operators: the graphics state stack, the text matrices of the current text object,
/// and what it found.
private final class ShownTextCollector {
    struct GraphicsState {
        var ctm = CGAffineTransform.identity
        var fontSize: CGFloat?
        var fontIsReadable = false
        var fontWritesAcross = false
        var leading: CGFloat = 0
        var rise: CGFloat = 0
        var horizontalScale: CGFloat = 1
    }

    /// What the scan knows of where the next run starts: exactly, since nothing was shown after the text position was
    /// set; somewhere on the text line, after runs that moved the position along it by widths the scan does not read;
    /// or nothing, after a run whose font may write vertically or a move whose direction it cannot tell.
    enum Position { case exact, onTheLine, lost }

    var state = GraphicsState()
    private(set) var reading = ShownTextReading()
    private var position = Position.exact
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
        position = .exact
    }

    func moveLine(by tx: CGFloat, _ ty: CGFloat) {
        setTextMatrix(CGAffineTransform(translationX: tx, y: ty).concatenating(lineMatrix))
    }

    func nextLine() { moveLine(by: 0, -state.leading) }

    /// Records the run a text-showing operator starts, `adjustment` thousandths of the em left of the text position.
    func show(after adjustment: CGFloat) {
        let fontSize = state.fontSize ?? 0
        let onPage = textMatrix.concatenating(state.ctm)
        let size = state.fontSize != nil && state.fontIsReadable ? Double(abs(fontSize) * hypot(onPage.c, onPage.d)) : nil
        let start: ShownText.Start
        if position == .lost || !state.fontWritesAcross {
            start = .anywhere
            position = .lost
        } else if position == .exact {
            let point = CGPoint(x: -adjustment / 1000 * fontSize * state.horizontalScale, y: state.rise).applying(onPage)
            start = .at(x: Double(point.x), y: Double(point.y))
            position = .onTheLine
        } else {
            let point = CGPoint(x: 0, y: state.rise).applying(onPage)
            start = .onTheLine(x: Double(point.x), y: Double(point.y), dx: Double(onPage.a), dy: Double(onPage.b))
        }
        reading.runs.append(ShownText(start: start, size: size))
    }

    /// Moves the text position as a `TJ` that shows no glyph does: `adjustment` thousandths of the em left along the
    /// text line, or in a direction the scan cannot tell when the font may write vertically.
    func move(by adjustment: CGFloat) {
        guard adjustment != 0 else { return }
        guard state.fontWritesAcross else {
            position = .lost
            return
        }
        let shift = -adjustment / 1000 * (state.fontSize ?? 0) * state.horizontalScale
        textMatrix = CGAffineTransform(translationX: shift, y: 0).concatenating(textMatrix)
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
        let outer = (state, saved, textMatrix, lineMatrix, position)
        saved = []
        state.ctm = matrix.concatenating(state.ctm)
        depth += 1
        reading.formsRead += 1
        scan(form)
        depth -= 1
        (state, saved, textMatrix, lineMatrix, position) = outer
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
