#if canImport(PDFKit)   // Apple-only adapter (R11): the whole file is platform-guarded
import CoreGraphics
import Foundation

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
        /// vertically (a Type 0 font whose CMap may write vertically, or one missing from the resources).
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
    /// Whether the scan read the whole content: false when it met a form it could not read, an operand it could not
    /// read, or content it could not scan to its end, any of which may show or place text that then has no run, or a
    /// run where the text is not.
    var isComplete = true
}

enum ShownTextScanner {
    /// The text `page` shows, in content order. A form the scan cannot read (nested deeper than `formDepthLimit`, with
    /// no resources or an unreadable matrix, or an XObject it cannot resolve), an operand it cannot read (not of the type
    /// its operator takes), or content it cannot scan to its end, makes the reading incomplete: the text there may have
    /// no run, or a run where it is not, so the inspector sizes every line of the page by PDFKit's fonts.
    static func reading(of page: CGPDFPage) -> ShownTextReading {
        guard let table = operatorTable() else { return ShownTextReading(isComplete: false) }
        defer { CGPDFOperatorTableRelease(table) }
        let collector = ShownTextCollector(table: table)
        let stream = CGPDFContentStreamCreateWithPage(page)
        defer { CGPDFContentStreamRelease(stream) }
        collector.scan(stream)
        return collector.reading
    }

    static let formDepthLimit = 8
    /// How many embedded CMaps, each built on the next (`/UseCMap`), the scan reads to learn a font's writing mode.
    static let cmapDepthLimit = 4

    // MARK: Operators

    private static func operatorTable() -> CGPDFOperatorTableRef? {
        guard let table = CGPDFOperatorTableCreate() else { return nil }
        CGPDFOperatorTableSetCallback(table, "q") { _, info in collecting(info)?.save() }
        CGPDFOperatorTableSetCallback(table, "Q") { _, info in collecting(info)?.restore() }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, info in
            guard let collector = collecting(info), let m = collector.numbers(6, from: scanner) else { return }
            collector.state.ctm = CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5])
                .concatenating(collector.state.ctm)
        }
        CGPDFOperatorTableSetCallback(table, "BT") { _, info in collecting(info)?.beginText() }
        CGPDFOperatorTableSetCallback(table, "Tf") { scanner, info in
            guard let collector = collecting(info), let size = collector.numbers(1, from: scanner),
                  let name = collector.name(from: scanner) else { return }
            collector.setFont(font(named: name, in: CGPDFScannerGetContentStream(scanner)), size: size[0])
        }
        CGPDFOperatorTableSetCallback(table, "gs") { scanner, info in
            guard let collector = collecting(info), let name = collector.name(from: scanner),
                  let set = font(setBy: name, in: CGPDFScannerGetContentStream(scanner)) else { return }
            collector.setFont(set.font, size: set.size)
        }
        CGPDFOperatorTableSetCallback(table, "TL") { scanner, info in
            guard let collector = collecting(info), let leading = collector.numbers(1, from: scanner) else { return }
            collector.state.leading = leading[0]
        }
        CGPDFOperatorTableSetCallback(table, "Ts") { scanner, info in
            guard let collector = collecting(info), let rise = collector.numbers(1, from: scanner) else { return }
            collector.state.rise = rise[0]
        }
        CGPDFOperatorTableSetCallback(table, "Tz") { scanner, info in
            guard let collector = collecting(info), let scale = collector.numbers(1, from: scanner) else { return }
            collector.state.horizontalScale = scale[0] / 100
        }
        CGPDFOperatorTableSetCallback(table, "Td") { scanner, info in
            guard let collector = collecting(info), let offset = collector.numbers(2, from: scanner) else { return }
            collector.moveLine(by: offset[0], offset[1])
        }
        CGPDFOperatorTableSetCallback(table, "TD") { scanner, info in
            guard let collector = collecting(info), let offset = collector.numbers(2, from: scanner) else { return }
            collector.state.leading = -offset[1]
            collector.moveLine(by: offset[0], offset[1])
        }
        CGPDFOperatorTableSetCallback(table, "Tm") { scanner, info in
            guard let collector = collecting(info), let m = collector.numbers(6, from: scanner) else { return }
            collector.setTextMatrix(CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5]))
        }
        CGPDFOperatorTableSetCallback(table, "T*") { _, info in collecting(info)?.nextLine() }
        CGPDFOperatorTableSetCallback(table, "Tj") { scanner, info in
            guard let collector = collecting(info), showsAGlyph(collector.string(from: scanner)) else { return }
            collector.show(after: 0)
        }
        CGPDFOperatorTableSetCallback(table, "'") { scanner, info in
            guard let collector = collecting(info) else { return }
            let shows = showsAGlyph(collector.string(from: scanner))
            collector.nextLine()
            if shows { collector.show(after: 0) }
        }
        CGPDFOperatorTableSetCallback(table, "\"") { scanner, info in
            guard let collector = collecting(info) else { return }
            let shows = showsAGlyph(collector.string(from: scanner))
            collector.nextLine()
            if shows { collector.show(after: 0) }
        }
        CGPDFOperatorTableSetCallback(table, "TJ") { scanner, info in
            guard let collector = collecting(info), let array = collector.array(from: scanner) else { return }
            guard let before = adjustments(beforeTheFirstGlyphOf: array) else { return collector.unreadable() }
            if before.showsAGlyph {
                collector.show(after: before.sum)
            } else {
                collector.move(by: before.sum)
            }
        }
        CGPDFOperatorTableSetCallback(table, "Do") { scanner, info in
            guard let collector = collecting(info), let name = collector.name(from: scanner) else { return }
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

/// The font `name` of `stream`'s resources, or nil when the resources have no font dictionary of that name.
private func font(named name: UnsafePointer<CChar>, in stream: CGPDFContentStreamRef) -> CGPDFDictionaryRef? {
    var dictionary: CGPDFDictionaryRef?
    guard let object = CGPDFContentStreamGetResource(stream, "Font", name),
          CGPDFObjectGetValue(object, .dictionary, &dictionary) else { return nil }
    return dictionary
}

/// The font and size the graphics state parameters `name` of `stream`'s resources set, as `Tf` does, when `gs` applies
/// them: nil when they set no font (they have no `/Font` entry). Both are nil when the scan cannot read one of them: the
/// parameters are missing from the resources, or their entry is not `[font size]`, a font and a number. A readable font
/// of unknown size would place the text after it at the wrong position, so it counts as a font the scan does not know.
private func font(setBy name: UnsafePointer<CChar>,
                  in stream: CGPDFContentStreamRef) -> (font: CGPDFDictionaryRef?, size: CGFloat?)? {
    var parameters: CGPDFDictionaryRef?
    guard let object = CGPDFContentStreamGetResource(stream, "ExtGState", name),
          CGPDFObjectGetValue(object, .dictionary, &parameters), let parameters else { return (nil, nil) }
    var entry: CGPDFObjectRef?
    guard CGPDFDictionaryGetObject(parameters, "Font", &entry) else { return nil }
    var array: CGPDFArrayRef?
    guard let entry, CGPDFObjectGetValue(entry, .array, &array), let array, CGPDFArrayGetCount(array) == 2 else {
        return (nil, nil)
    }
    var font: CGPDFDictionaryRef?
    var size: CGPDFReal = 0
    guard CGPDFArrayGetDictionary(array, 0, &font), let font, CGPDFArrayGetNumber(array, 1, &size) else {
        return (nil, nil)
    }
    return (font, size)
}

/// How `font` sets its glyphs: whether the `Tf` size scales them (any font but Type 3), and whether it writes across,
/// moving the text position along the text line (any font but a Type 0 one whose CMap may write vertically). A font
/// with no subtype does neither.
private func setting(of font: CGPDFDictionaryRef,
                     cmaps: inout [CGPDFStreamRef: Bool]) -> (sizedByItsEm: Bool, writesAcross: Bool) {
    var subtype: UnsafePointer<CChar>?
    guard CGPDFDictionaryGetName(font, "Subtype", &subtype), let subtype else { return (false, false) }
    let kind = String(cString: subtype)
    return (kind != "Type3", kind != "Type0" || !mayWriteVertically(font, cmaps: &cmaps))
}

/// Whether the Type 0 font `font` may write vertically: its CMap is named, by a name `writesAcross(cmapNamed:)` does
/// not know as horizontal, or it is an embedded one that may. `cmaps` keeps the answer for each embedded CMap, which a
/// page's content sets again and again.
private func mayWriteVertically(_ font: CGPDFDictionaryRef, cmaps: inout [CGPDFStreamRef: Bool]) -> Bool {
    var name: UnsafePointer<CChar>?
    if CGPDFDictionaryGetName(font, "Encoding", &name), let name { return !writesAcross(cmapNamed: String(cString: name)) }
    var cmap: CGPDFStreamRef?
    guard CGPDFDictionaryGetStream(font, "Encoding", &cmap), let cmap else { return false }
    if let known = cmaps[cmap] { return known }
    let answer = mayWriteVertically(cmap, within: ShownTextScanner.cmapDepthLimit)
    cmaps[cmap] = answer
    return answer
}

/// Whether the embedded CMap `cmap` may write vertically: its dictionary gives a writing mode other than 0, its
/// program may set one (`CMapProgram`), or it is built on (`/UseCMap`) a named CMap not known as horizontal or an
/// embedded one that may. A CMap whose program the scan cannot read, or a chain of CMaps longer than `depth`, may.
private func mayWriteVertically(_ cmap: CGPDFStreamRef, within depth: Int) -> Bool {
    guard depth > 0, let info = CGPDFStreamGetDictionary(cmap) else { return true }
    var mode: CGPDFObjectRef?
    var value: CGPDFInteger = 0
    if CGPDFDictionaryGetObject(info, "WMode", &mode), !(CGPDFDictionaryGetInteger(info, "WMode", &value) && value == 0) { return true }
    var baseName: UnsafePointer<CChar>?
    if CGPDFDictionaryGetName(info, "UseCMap", &baseName), let baseName, !writesAcross(cmapNamed: String(cString: baseName)) {
        return true
    }
    var base: CGPDFStreamRef?
    if CGPDFDictionaryGetStream(info, "UseCMap", &base), let base, mayWriteVertically(base, within: depth - 1) { return true }
    var format = CGPDFDataFormat.raw
    guard let program = CGPDFStreamCopyData(cmap, &format), format == .raw else { return true }
    return CMapProgram(program as Data).mayWriteVertically
}

/// Whether the CMap named `name` writes across for sure: it is one of the predefined horizontal CMaps. Any other name
/// may write vertically: a predefined vertical CMap, or one the scan does not know, which a renderer may still find and
/// which may set writing mode 1 whatever its name says (`Custom-H` too).
private func writesAcross(cmapNamed name: String) -> Bool {
    predefinedHorizontalCMaps.contains(name)
}

/// The predefined CMaps that write across, by their names in ISO 32000-1, table 118
private let predefinedHorizontalCMaps: Set<String> = [
    "GB-EUC-H", "GBpc-EUC-H", "GBK-EUC-H", "GBKp-EUC-H", "GBK2K-H", "UniGB-UCS2-H", "UniGB-UTF16-H",
    "B5pc-H", "HKscs-B5-H", "ETen-B5-H", "ETenms-B5-H", "CNS-EUC-H", "UniCNS-UCS2-H", "UniCNS-UTF16-H",
    "83pv-RKSJ-H", "90ms-RKSJ-H", "90msp-RKSJ-H", "90pv-RKSJ-H", "Add-RKSJ-H", "EUC-H", "Ext-RKSJ-H", "H",
    "UniJIS-UCS2-H", "UniJIS-UCS2-HW-H", "UniJIS-UTF16-H",
    "KSC-EUC-H", "KSCms-UHC-H", "KSCms-UHC-HW-H", "KSCpc-EUC-H", "UniKS-UCS2-H", "UniKS-UTF16-H",
    "Identity-H",
]

/// The words of a CMap program, which is PostScript, split at white space and delimiters. A comment (from `%` to the
/// end of its line) gives no word, a string (`(…)`, `<…>`, `<~…~>`) gives one word that starts with its delimiter,
/// and `<<`, `>>`, `[`, `]`, `{` and `}` are words of their own. A name's `#` and two hex digits are read as the byte
/// they stand for, as in a PDF name, so `/Identity#2DV` is `/Identity-V` and `/#57Mode` is `/WMode`.
struct CMapProgram {
    let words: [String]
    /// Whether every string the program opens is closed. One left open hides the rest of the program.
    let isWhole: Bool

    init(_ program: Data) {
        let bytes = [UInt8](program)
        var words: [String] = []
        var word = ""
        var index = bytes.startIndex
        var isWhole = true
        func endWord() {
            if !word.isEmpty { words.append(word.hasPrefix("/") ? Self.decoded(name: word) : word) }
            word = ""
        }
        while index < bytes.endIndex {
            let byte = bytes[index]
            switch byte {
            case 0, 9, 10, 12, 13, 32:
                endWord()
            case UInt8(ascii: "%"):
                endWord()
                while index + 1 < bytes.endIndex, ![10, 12, 13].contains(bytes[index + 1]) { index += 1 }
            case UInt8(ascii: "("):
                endWord()
                words.append("(")
                index = Self.end(ofStringFrom: index, in: bytes)
                isWhole = isWhole && index < bytes.endIndex
            case UInt8(ascii: "<"):
                endWord()
                if index + 1 < bytes.endIndex, bytes[index + 1] == UInt8(ascii: "<") {
                    words.append("<<")
                    index += 1
                } else {
                    let ascii85 = index + 1 < bytes.endIndex && bytes[index + 1] == UInt8(ascii: "~")
                    words.append(ascii85 ? "<~" : "<")
                    index = Self.end(ofHexOrASCII85StringFrom: index, ascii85: ascii85, in: bytes)
                    isWhole = isWhole && index < bytes.endIndex
                }
            case UInt8(ascii: ">"):
                endWord()
                let pair = index + 1 < bytes.endIndex && bytes[index + 1] == UInt8(ascii: ">")
                words.append(pair ? ">>" : ">")
                if pair { index += 1 }
            case UInt8(ascii: ")"), UInt8(ascii: "["), UInt8(ascii: "]"), UInt8(ascii: "{"), UInt8(ascii: "}"):
                endWord()
                words.append(String(UnicodeScalar(byte)))
            case UInt8(ascii: "/"):
                endWord()
                word = "/"
            default:
                word.unicodeScalars.append(UnicodeScalar(byte))
            }
            index += 1
        }
        endWord()
        self.words = words
        self.isWhole = isWhole
    }

    /// `name` with each `#` and two hex digits read as the byte they stand for; a `#` without two hex digits stays.
    private static func decoded(name: String) -> String {
        let scalars = Array(name.unicodeScalars)
        var decoded = String.UnicodeScalarView()
        var index = scalars.startIndex
        while index < scalars.endIndex {
            if scalars[index] == "#", index + 2 < scalars.endIndex,
               scalars[index + 1...index + 2].allSatisfy(\.properties.isASCIIHexDigit),
               let byte = UInt8(String(String.UnicodeScalarView(scalars[index + 1...index + 2])), radix: 16) {
                decoded.append(UnicodeScalar(byte))
                index += 3
            } else {
                decoded.append(scalars[index])
                index += 1
            }
        }
        return String(decoded)
    }

    /// The index of the `)` that closes the string opened at `open`, past nested parentheses and backslash escapes,
    /// or the end of `bytes` when none does.
    private static func end(ofStringFrom open: Int, in bytes: [UInt8]) -> Int {
        var depth = 0
        var index = open
        while index < bytes.endIndex {
            switch bytes[index] {
            case UInt8(ascii: "\\"): index += 1
            case UInt8(ascii: "("): depth += 1
            case UInt8(ascii: ")"):
                depth -= 1
                if depth == 0 { return index }
            default: break
            }
            index += 1
        }
        return bytes.endIndex
    }

    /// The index of the last byte of the hex string (`<…>`) or ASCII85 string (`<~…~>`) opened at `open`, or the end
    /// of `bytes` when it is not closed.
    private static func end(ofHexOrASCII85StringFrom open: Int, ascii85: Bool, in bytes: [UInt8]) -> Int {
        var index = open + (ascii85 ? 2 : 1)
        while index < bytes.endIndex {
            if bytes[index] == UInt8(ascii: ">"), !ascii85 || bytes[index - 1] == UInt8(ascii: "~") { return index }
            index += 1
        }
        return bytes.endIndex
    }

    /// Whether the program may set writing mode 1: a string it opens is never closed, a `/WMode` it holds is followed
    /// by anything but `0`, or a `usecmap` it holds is not right after a name, or is after one that
    /// `writesAcross(cmapNamed:)` does not know as horizontal.
    var mayWriteVertically: Bool {
        !isWhole || words.indices.contains { index in
            switch words[index] {
            case "/WMode": index + 1 == words.endIndex || words[index + 1] != "0"
            case "usecmap":
                index == words.startIndex || !words[index - 1].hasPrefix("/")
                    || !writesAcross(cmapNamed: String(words[index - 1].dropFirst()))
            default: false
            }
        }
    }
}

private func showsAGlyph(_ string: CGPDFStringRef?) -> Bool {
    string.map { CGPDFStringGetLength($0) > 0 } ?? false
}

/// The sum of the position adjustments a `TJ` array makes before its first glyph (thousandths of the em, moving the
/// text position left when positive), and whether the array shows a glyph at all: when it does not, the sum is all the
/// array does. Nil when an element before the first glyph is neither a string nor a number.
private func adjustments(beforeTheFirstGlyphOf array: CGPDFArrayRef) -> (sum: CGFloat, showsAGlyph: Bool)? {
    var adjustment: CGFloat = 0
    for index in 0..<CGPDFArrayGetCount(array) {
        var string: CGPDFStringRef?
        var number: CGPDFReal = 0
        if CGPDFArrayGetString(array, index, &string) {
            if showsAGlyph(string) { return (adjustment, true) }
        } else if CGPDFArrayGetNumber(array, index, &number) {
            adjustment += number
        } else {
            return nil
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
    /// Whether each embedded CMap the content's fonts use may write vertically.
    private var verticalCMaps: [CGPDFStreamRef: Bool] = [:]
    private let table: CGPDFOperatorTableRef

    init(table: CGPDFOperatorTableRef) { self.table = table }

    func scan(_ stream: CGPDFContentStreamRef) {
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(self).toOpaque())
        defer { CGPDFScannerRelease(scanner) }
        if !CGPDFScannerScan(scanner) { reading.isComplete = false }
    }

    // MARK: Reading operands

    /// The last `count` operands, in the order the content wrote them. These read every operand the scan uses: one it
    /// cannot read (missing, or not of the type its operator takes) makes the reading incomplete, since its operator
    /// may show or place text the runs then miss.
    func numbers(_ count: Int, from scanner: CGPDFScannerRef) -> [CGFloat]? { readable(popNumbers(scanner, count)) }

    func name(from scanner: CGPDFScannerRef) -> UnsafePointer<CChar>? {
        var name: UnsafePointer<CChar>?
        return readable(CGPDFScannerPopName(scanner, &name) ? name : nil)
    }

    func string(from scanner: CGPDFScannerRef) -> CGPDFStringRef? {
        var string: CGPDFStringRef?
        return readable(CGPDFScannerPopString(scanner, &string) ? string : nil)
    }

    func array(from scanner: CGPDFScannerRef) -> CGPDFArrayRef? {
        var array: CGPDFArrayRef?
        return readable(CGPDFScannerPopArray(scanner, &array) ? array : nil)
    }

    /// Makes the reading incomplete: the content holds an operand the scan cannot read.
    func unreadable() { reading.isComplete = false }

    private func readable<Operand>(_ operand: Operand?) -> Operand? {
        if operand == nil { unreadable() }
        return operand
    }

    // MARK: Graphics and text state

    func save() { saved.append(state) }

    func restore() { if let last = saved.popLast() { state = last } }

    func beginText() { setTextMatrix(.identity) }

    /// Sets the font of the runs that follow, as `Tf` or `gs` does: `font` nil when the content names one the scan
    /// cannot read, which neither scales its glyphs by the size nor writes across; `size` nil when it cannot read that.
    func setFont(_ font: CGPDFDictionaryRef?, size: CGFloat?) {
        var glyphs = (sizedByItsEm: false, writesAcross: false)
        if let font { glyphs = setting(of: font, cmaps: &verticalCMaps) }
        state.fontSize = size
        state.fontIsReadable = glyphs.sizedByItsEm
        state.fontWritesAcross = glyphs.writesAcross
    }

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
    /// matrix concatenated to the current transform. Images and every other kind of XObject show no text. An XObject
    /// the scan cannot resolve, or a form it cannot read, makes the reading incomplete.
    func drawForm(named name: UnsafePointer<CChar>, from parent: CGPDFContentStreamRef) {
        var stream: CGPDFStreamRef?
        var subtype: UnsafePointer<CChar>?
        guard let object = CGPDFContentStreamGetResource(parent, "XObject", name),
              CGPDFObjectGetValue(object, .stream, &stream), let stream, let dictionary = CGPDFStreamGetDictionary(stream),
              CGPDFDictionaryGetName(dictionary, "Subtype", &subtype), let subtype else {
            reading.isComplete = false
            return
        }
        guard String(cString: subtype) == "Form" else { return }
        var resources: CGPDFDictionaryRef?
        guard depth < ShownTextScanner.formDepthLimit, CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources),
              let resources, let matrix = Self.matrix(of: dictionary) else {
            reading.isComplete = false
            return
        }
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
