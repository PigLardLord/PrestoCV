// Composes the App Store screenshots: each caption of docs/release/store-listing.md above its screenshot, on the
// app's dark green with its accent, at the exact size the App Store asks for, plus a contact sheet per device.
//
//   swiftc -O -o compose-store-screenshots Tools/Release/compose-store-screenshots.swift
//   ./compose-store-screenshots <store-listing.md> <captures dir> <output dir> <device>[,<device>...] [<language>,...]
//
// A caption is written `Title | Line below`: the title is set large and bold, in at most two lines, and the line below it
// smaller, in at most three. <captures dir>/<device>/<language>/NN.png are the screenshots StoreScreenshotsUITests
// attached; a locale uses those of its language (en-GB those of en, pt-PT those of pt), and only the locales of the
// languages given are composed (all by default). It writes <output dir>/<locale>/<device>/NN.png and
// <output dir>/contact-sheet-<device>.png. In the iPad set the captions say "iPad" where they say "iPhone", as the
// listing asks; apostrophes are typeset as ’, and "Apple Intelligence" is kept on one line. The images have no alpha
// channel, which the App Store rejects. Tools/Release/store-screenshots.sh runs it.
//
// The iPad's status bar shows the date next to the time. store-screenshots.sh sets the simulator's clock to 9:41 on one
// fixed day, which the simulator writes with English words in every language, so the composer writes that day again in
// the language of the capture, as the device writes it, and moves the app's name after it to follow. A capture whose
// status bar is not the time, the date and the app's name on a plain background is refused, as one of the wrong size is.
//
// A locale needs exactly six captions, one for each capture, and each capture the size of the device's screen: the
// composer fails otherwise, before it writes anything of that locale. It makes the whole output aside, in
// <output dir>/.compose-staging, and puts it in place only when all of it is made: each folder <locale>/<device> and each
// contact sheet that it replaces is moved to <output dir>/.compose-previous first, and put back if a step fails. So a run
// that fails leaves the output as it was, and no image of an earlier run is left in a folder it replaces.
//
// A run cannot make the moves into place one step. Before the first of them it writes <output dir>/.compose-promoting,
// which lists the items, and it removes it after the last one (the contact sheets too), so that the file is there exactly
// while the output may hold only part of a set. A run that is killed in between leaves it, also when the output was empty
// and nothing was moved aside, and the next run refuses until it has been looked at, and says why. (.compose-previous, which
// holds what a run replaced and could not put back, is refused the same way.)
// Tools/Release/compose-store-screenshots-selftest.sh tests it, killing a run after each move with
// COMPOSE_TEST_KILL_AFTER_MOVE=<n> (the run ends with SIGKILL after its nth move into place, 0 before the first; unset, it does nothing).

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Devices

/// The screenshots of a locale. The nth caption goes on the nth capture, so a locale with another number of captions
/// would put them over the wrong screens, and is refused.
let screenshotCount = 6

/// How one part of the captions is set: the titles, or the lines below them
struct Style: Sendable {
    let isBold: Bool
    /// The largest size, in pixels. All the titles of a locale get one size, and all its lines below another
    /// (`fitCaptions`).
    let largestSize: CGFloat
    let maximumLines: Int
    let lineHeight: CGFloat
    let opacity: CGFloat
}

struct Device: Sendable {
    let width: Int
    let height: Int
    /// The device the captions name: "iPhone" in the listing, replaced in the other sets
    let name: String
    let label: String
    let title: Style
    let line: Style
    /// The corner radius of the screen, as a share of its width
    let cornerRadius: CGFloat
    /// Whether the status bar shows the date, which the composer writes again (`rewritingStatusBarDate`)
    let showsDateInStatusBar: Bool
}

func titleStyle(_ size: CGFloat) -> Style {
    Style(isBold: true, largestSize: size, maximumLines: 2, lineHeight: 1.0, opacity: 1)
}

func lineStyle(_ size: CGFloat) -> Style {
    Style(isBold: false, largestSize: size, maximumLines: 3, lineHeight: 1.08, opacity: 0.85)
}

let devices: [String: Device] = [
    "iphone": Device(width: 1320, height: 2868, name: "iPhone", label: "iPhone 6.9-inch",
                     title: titleStyle(112), line: lineStyle(62), cornerRadius: 0.13, showsDateInStatusBar: false),
    "iphone-6.3": Device(width: 1206, height: 2622, name: "iPhone", label: "iPhone 6.3-inch",
                         title: titleStyle(102), line: lineStyle(57), cornerRadius: 0.13, showsDateInStatusBar: false),
    "ipad": Device(width: 2064, height: 2752, name: "iPad", label: "iPad 13-inch",
                   title: titleStyle(132), line: lineStyle(76), cornerRadius: 0.035, showsDateInStatusBar: true),
]

// MARK: - Layout

/// Where things go on a canvas, as shares of its size: the same on every image of a device, so that the screenshots
/// do not move when the App Store pages through them. The band of the captions is as tall as the tallest caption of
/// the listing on that device.
struct Layout {
    let canvas: CGSize
    var captionHeight: CGFloat = 0
    var captionTop: CGFloat { canvas.height * 0.05 }
    var captionWidth: CGFloat { canvas.width * 0.86 }
    var screenTop: CGFloat { captionTop + captionHeight + canvas.height * 0.03 }
    var bottomMargin: CGFloat { canvas.height * 0.04 }

    init(canvas: CGSize) {
        self.canvas = canvas
    }

    /// The space between a title and the line below it
    func gap(below title: SetCaption) -> CGFloat {
        title.fontSize * 0.3
    }

    /// The screenshot's frame, top-left origin, as large as fits under the caption
    func screenFrame(for capture: CGSize, frameWidth: CGFloat) -> CGRect {
        let height = canvas.height - screenTop - bottomMargin - 2 * frameWidth
        let width = height * capture.width / capture.height
        return CGRect(x: (canvas.width - width) / 2, y: screenTop + frameWidth, width: width, height: height)
    }
}

let darkGreen = CGColor(srgbRed: 0x0A / 255, green: 0x40 / 255, blue: 0x3B / 255, alpha: 1)
let deeperGreen = CGColor(srgbRed: 0x06 / 255, green: 0x2C / 255, blue: 0x28 / 255, alpha: 1)
let accent = CGColor(srgbRed: 0x00 / 255, green: 0xDA / 255, blue: 0xC3 / 255, alpha: 1)
let frameColor = CGColor(srgbRed: 0x03 / 255, green: 0x16 / 255, blue: 0x14 / 255, alpha: 1)
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

/// A caption of the listing, `Title | Line below`. A caption without the separator is all title.
struct Caption {
    let title: String
    let line: String

    init(_ text: String) {
        let parts = text.components(separatedBy: " | ")
        title = parts[0]
        line = parts.dropFirst().joined(separator: " | ")
    }

    /// As it is shown on a device: "iPhone" becomes the device, apostrophes are typeset, and "Apple Intelligence"
    /// does not break
    func shown(on device: Device) -> Caption {
        func typeset(_ text: String) -> String {
            text.replacingOccurrences(of: "iPhone", with: device.name).replacingOccurrences(of: "'", with: "’")
                .replacingOccurrences(of: "Apple Intelligence", with: "Apple\u{00A0}Intelligence")
        }
        return Caption(title: typeset(title), line: typeset(line))
    }

    private init(title: String, line: String) {
        self.title = title
        self.line = line
    }
}

// MARK: - Captions

/// The screenshot captions of every locale of the listing, in its order: the lines of the ```text block under
/// "### Screenshot captions" of each "## <Language>, <code>" section.
func captions(in listing: String) -> [(locale: String, captions: [String])] {
    var result: [(locale: String, captions: [String])] = []
    var locale: String?
    var field: String?
    var block: [String]?
    let heading = try? NSRegularExpression(pattern: #"^## .+, ([a-z]{2}(?:-[A-Z]{2})?)$"#)
    for line in listing.components(separatedBy: "\n") {
        if var lines = block {
            if line == "```" {
                if let locale, field == "Screenshot captions" { result.append((locale, lines)) }
                block = nil
            } else {
                lines.append(line)
                block = lines
            }
        } else if line == "```text" {
            block = []
        } else if line.hasPrefix("## ") {
            let range = NSRange(line.startIndex..., in: line)
            locale = heading?.firstMatch(in: line, range: range)
                .flatMap { Range($0.range(at: 1), in: line) }
                .map { String(line[$0]) }
            field = nil
        } else if line.hasPrefix("### ") {
            field = String(line.dropFirst(4))
        }
    }
    return result
}

// MARK: - Text

func captionText(_ text: String, size: CGFloat, style: Style) -> NSAttributedString {
    let font = CTFontCreateUIFontForLanguage(style.isBold ? .emphasizedSystem : .system, size, nil)
        ?? CTFontCreateWithName((style.isBold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil)
    var alignment = CTTextAlignment.center
    var lineHeight = style.lineHeight
    let paragraph = withUnsafePointer(to: &alignment) { alignmentPointer in
        withUnsafePointer(to: &lineHeight) { lineHeightPointer in
            let settings = [
                CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size,
                                        value: alignmentPointer),
                CTParagraphStyleSetting(spec: .lineHeightMultiple, valueSize: MemoryLayout<CGFloat>.size,
                                        value: lineHeightPointer),
            ]
            return CTParagraphStyleCreate(settings, settings.count)
        }
    }
    return NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): white.copy(alpha: style.opacity) ?? white,
        NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
    ])
}

/// A title or a line below set in its lines: the text, its font size and the size the text takes.
struct SetCaption {
    let text: NSAttributedString
    let fontSize: CGFloat
    let size: CGSize
}

/// The lines a text is broken into at a width, and the size of the text
func lines(of text: NSAttributedString, width: CGFloat) -> (lines: [String], size: CGSize) {
    let setter = CTFramesetterCreateWithAttributedString(text)
    let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 100_000), transform: nil)
    let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
    let string = text.string as NSString
    let lines = (CTFrameGetLines(frame) as? [CTLine] ?? []).map { line in
        let range = CTLineGetStringRange(line)
        return string.substring(with: NSRange(location: range.location, length: range.length))
    }
    let size = CTFramesetterSuggestFrameSizeWithConstraints(
        setter, CFRange(location: 0, length: 0), nil, CGSize(width: width, height: 100_000), nil
    )
    return (lines, size)
}

func lineWidth(_ text: String, size: CGFloat, style: Style) -> CGFloat {
    let line = CTLineCreateWithAttributedString(captionText(text, size: size, style: style))
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
}

/// The widest word: a text whose widest word does not fit would be broken inside it.
func widestWord(_ text: String, size: CGFloat, style: Style) -> CGFloat {
    text.split(separator: " ").map { lineWidth(String($0), size: size, style: style) }.max() ?? 0
}

/// Whether the text fits its lines at `size`, none broken inside a word
func fits(_ text: String, size: CGFloat, style: Style, width: CGFloat) -> Bool {
    lines(of: captionText(text, size: size, style: style), width: width).lines.count <= style.maximumLines
        && widestWord(text, size: size, style: style) <= width
}

/// Short words a line should not end with (articles, prepositions, possessives) and the conjunctions a line reads well
/// starting with, in the languages of the listing: "a blank / CV" and "ce / que" read badly, "/ or from one" well.
let weakLineEnds: Set<String> = [
    "a", "an", "the", "of", "to", "in", "on", "from", "with", "your", "and", "or",
    "ein", "einem", "einen", "einer", "der", "die", "das", "den", "dem", "von", "auf", "mit", "und", "oder", "ihr",
    "ihren", "ihrem", "un", "una", "uno", "il", "lo", "la", "le", "i", "di", "da", "del", "della", "nel", "sul", "e",
    "o", "tuo", "ciò", "che", "el", "los", "las", "de", "en", "con", "y", "tu", "que", "une", "les", "du", "des", "ce",
    "et", "ou", "votre", "vos", "um", "uma", "os", "as", "do", "dos", "das", "em", "no", "na", "com", "seu", "sua",
    "for", "für", "zu", "zur", "per", "nella", "pour", "sur", "dans", "por", "para",
]
let lineStarts: Set<String> = ["or", "and", "oder", "und", "o", "y", "e", "ou", "et"]

/// What a way of breaking a caption into lines costs: uneven lines cost, a line that ends a sentence or a clause, or
/// that starts with a conjunction, saves, and a line that ends with a short word, or a last line of one word, costs.
func cost(of lines: [String], widths: [CGFloat]) -> CGFloat {
    // Unevenness is measured against the widest line, so that it does not depend on the size of the text
    let mean = widths.reduce(0, +) / CGFloat(widths.count)
    let widest = widths.max() ?? 1
    var cost = widths.map { pow(($0 - mean) / widest, 2) }.reduce(0, +)
    for line in lines.dropLast() {
        let last = line.split(separator: " ").last.map { String($0).lowercased() } ?? ""
        if let mark = line.last, ".:;!?".contains(mark) { cost -= 0.25 }
        if line.last == "," { cost -= 0.2 }
        if weakLineEnds.contains(last) { cost += 0.2 }
    }
    for line in lines.dropFirst() {
        if let first = line.split(separator: " ").first, lineStarts.contains(first.lowercased()) { cost -= 0.15 }
    }
    if lines.count > 1, lines.last?.contains(" ") == false { cost += 0.3 }
    return cost
}

/// The text at `size`, broken the cheapest of every way to break it: in as few lines as fit, or in one more, which
/// costs, where that reads much better.
func balanced(
    _ text: String, size: CGFloat, style: Style, width maximumWidth: CGFloat
) -> (set: SetCaption, cost: CGFloat) {
    let words = text.split(separator: " ").map(String.init)
    let fewest = lines(of: captionText(text, size: size, style: style), width: maximumWidth).lines.count
    let extraLineCost: CGFloat = 0.35
    var widths: [String: CGFloat] = [:]
    func width(_ line: String) -> CGFloat {
        if let known = widths[line] { return known }
        let measured = lineWidth(line, size: size, style: style)
        widths[line] = measured
        return measured
    }
    // An empty text, a caption with no line below, costs nothing and takes no room
    var best: (cost: CGFloat, lines: [String]) = (words.isEmpty ? 0 : .infinity, [text])

    /// Every way to put the words from `start` on in `remaining` lines
    func split(from start: Int, into remaining: Int, lines: [String]) {
        if remaining == 1 {
            let candidate = lines + [words[start...].joined(separator: " ")]
            let candidateWidths = candidate.map(width)
            guard candidateWidths.allSatisfy({ $0 <= maximumWidth }) else { return }
            let candidateCost = cost(of: candidate, widths: candidateWidths)
                + extraLineCost * CGFloat(candidate.count - fewest)
            if candidateCost < best.cost { best = (candidateCost, candidate) }
            return
        }
        guard start + remaining <= words.count else { return }
        for end in (start + 1)...(words.count - remaining + 1) {
            let line = words[start..<end].joined(separator: " ")
            if width(line) > maximumWidth { break }
            split(from: end, into: remaining - 1, lines: lines + [line])
        }
    }

    if !words.isEmpty {
        for count in fewest...min(fewest + 1, style.maximumLines, words.count) {
            split(from: 0, into: count, lines: [])
        }
    }
    let set = captionText(best.lines.joined(separator: "\u{2028}"), size: size, style: style)
    return (SetCaption(text: set, fontSize: size, size: lines(of: set, width: maximumWidth).size), best.cost)
}

/// Every title, or every line below, of a set at one size: the largest at which all of them fit, or a little smaller
/// where that lets them break much better. Each step down costs, so that the text stays as large as it can.
func fitCaptions(_ texts: [String], style: Style, width: CGFloat) throws -> [SetCaption] {
    var largest = style.largestSize
    while !texts.allSatisfy({ fits($0, size: largest, style: style, width: width) }) {
        largest -= 2
        guard largest >= style.largestSize * 0.55 else {
            throw Failure("these do not fit in \(style.maximumLines) lines: \(texts)")
        }
    }
    var best: (cost: CGFloat, set: [SetCaption]) = (.infinity, [])
    var size = largest
    while size >= largest * 0.9 {
        let set = texts.map { balanced($0, size: size, style: style, width: width) }
        let total = set.map(\.cost).reduce(0, +) + 4 * (largest - size) / largest
        if total < best.cost { best = (total, set.map(\.set)) }
        size -= 2
    }
    return best.set
}

/// The titles and the lines below of the captions of one locale, set for a device
func setCaptions(
    _ captions: [Caption], device: Device, layout: Layout
) throws -> [(title: SetCaption, line: SetCaption)] {
    let shown = captions.map { $0.shown(on: device) }
    let titles = try fitCaptions(shown.map(\.title), style: device.title, width: layout.captionWidth)
    let lines = try fitCaptions(shown.map(\.line), style: device.line, width: layout.captionWidth)
    return Array(zip(titles, lines))
}

/// How tall a title and its line below are, with the space between them
func height(of caption: (title: SetCaption, line: SetCaption), in layout: Layout) -> CGFloat {
    let line = caption.line.text.length > 0 ? layout.gap(below: caption.title) + caption.line.size.height : 0
    return caption.title.size.height + line
}

// MARK: - Drawing

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// A bitmap with no alpha channel, in sRGB
func makeCanvas(width: Int, height: Int) throws -> CGContext {
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
        throw Failure("could not make a \(width) x \(height) canvas")
    }
    context.interpolationQuality = .high
    return context
}

func loadImage(_ url: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw Failure("could not read \(url.path)")
    }
    return image
}

/// A screenshot the simulator took, which is the size of the device's screen: a capture of another size would be
/// stretched or cut to the frame
func loadCapture(_ url: URL, for device: Device) throws -> CGImage {
    let image = try loadImage(url)
    guard image.width == device.width, image.height == device.height else {
        throw Failure("\(url.path) is \(image.width) x \(image.height), and the \(device.label) screen is "
                      + "\(device.width) x \(device.height)")
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw Failure("could not write \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw Failure("could not write \(url.path)") }
}

/// A rectangle given with a top-left origin, in the bottom-left coordinates of Core Graphics
func flipped(_ rect: CGRect, in canvas: CGSize) -> CGRect {
    CGRect(x: rect.minX, y: canvas.height - rect.maxY, width: rect.width, height: rect.height)
}

func compose(
    caption: (title: SetCaption, line: SetCaption), capture: CGImage, device: Device, layout: Layout
) throws -> CGImage {
    let canvas = layout.canvas
    let context = try makeCanvas(width: device.width, height: device.height)
    let space = CGColorSpace(name: CGColorSpace.sRGB)

    // The background: the app's green, a little deeper towards the bottom, with the accent glowing behind the screen
    if let gradient = CGGradient(colorsSpace: space, colors: [darkGreen, deeperGreen] as CFArray, locations: [0.35, 1]) {
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: canvas.height), end: .zero, options: [])
    }
    let captureSize = CGSize(width: capture.width, height: capture.height)
    let frameWidth = canvas.width * (device.name == "iPad" ? 0.012 : 0.02)
    let screen = layout.screenFrame(for: captureSize, frameWidth: frameWidth)
    if let glow = CGGradient(colorsSpace: space,
                             colors: [accent.copy(alpha: 0.30) ?? accent, accent.copy(alpha: 0) ?? accent] as CFArray,
                             locations: [0, 1]) {
        let center = CGPoint(x: canvas.width / 2, y: canvas.height - screen.minY - screen.height * 0.18)
        context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center,
                                   endRadius: canvas.width * 0.75, options: [])
    }

    // The title at the top of the band, the line below it under it, each centred
    func draw(_ text: SetCaption, top: CGFloat) {
        let rect = CGRect(x: (canvas.width - layout.captionWidth) / 2, y: top, width: layout.captionWidth,
                          height: text.size.height + 1)
        let setter = CTFramesetterCreateWithAttributedString(text.text)
        let path = CGPath(rect: flipped(rect, in: canvas), transform: nil)
        CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil), context)
    }
    draw(caption.title, top: layout.captionTop)
    if caption.line.text.length > 0 {
        draw(caption.line, top: layout.captionTop + caption.title.size.height + layout.gap(below: caption.title))
    }

    // A plain frame around the screen, with a shadow and a thin line of the accent: no picture of a device
    let radius = screen.width * device.cornerRadius
    let outer = flipped(screen.insetBy(dx: -frameWidth, dy: -frameWidth), in: canvas)
    let outerPath = CGPath(roundedRect: outer, cornerWidth: radius + frameWidth, cornerHeight: radius + frameWidth,
                           transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -canvas.height * 0.008), blur: canvas.height * 0.025,
                      color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.45))
    context.addPath(outerPath)
    context.setFillColor(frameColor)
    context.fillPath()
    context.restoreGState()
    context.addPath(outerPath)
    context.setStrokeColor(accent.copy(alpha: 0.55) ?? accent)
    context.setLineWidth(max(2, canvas.width * 0.0025))
    context.strokePath()

    // The screenshot, with the corners of the screen
    context.saveGState()
    let inner = flipped(screen, in: canvas)
    context.addPath(CGPath(roundedRect: inner, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    context.draw(capture, in: inner)
    context.restoreGState()

    guard let image = context.makeImage() else { throw Failure("could not compose") }
    return image
}

/// Every image of a device, one row per locale, to look at them at a glance
func contactSheet(_ rows: [(locale: String, images: [CGImage])], device: Device) throws -> CGImage {
    let thumbnailWidth: CGFloat = device.name == "iPad" ? 300 : 230
    let thumbnailHeight = thumbnailWidth * CGFloat(device.height) / CGFloat(device.width)
    let gap: CGFloat = 24
    let labelWidth: CGFloat = 170
    let titleHeight: CGFloat = 110
    let columns = rows.map(\.images.count).max() ?? 0
    let width = Int(labelWidth + CGFloat(columns) * (thumbnailWidth + gap) + gap)
    let height = Int(titleHeight + CGFloat(rows.count) * (thumbnailHeight + gap) + gap)
    let canvas = CGSize(width: width, height: height)
    let context = try makeCanvas(width: width, height: height)
    context.setFillColor(CGColor(srgbRed: 0.90, green: 0.92, blue: 0.91, alpha: 1))
    context.fill(CGRect(origin: .zero, size: canvas))

    func label(_ text: String, size: CGFloat, at point: CGPoint) {
        let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): darkGreen,
        ]))
        context.textPosition = CGPoint(x: point.x, y: canvas.height - point.y)
        CTLineDraw(line, context)
    }

    label("PrestoCV · \(device.label) · \(device.width) × \(device.height)", size: 48, at: CGPoint(x: gap, y: 72))
    for (row, entry) in rows.enumerated() {
        let top = titleHeight + CGFloat(row) * (thumbnailHeight + gap)
        label(entry.locale, size: 40, at: CGPoint(x: gap, y: top + thumbnailHeight / 2))
        for (column, image) in entry.images.enumerated() {
            let rect = CGRect(x: labelWidth + CGFloat(column) * (thumbnailWidth + gap), y: top,
                              width: thumbnailWidth, height: thumbnailHeight)
            context.draw(image, in: flipped(rect, in: canvas))
        }
    }
    guard let image = context.makeImage() else { throw Failure("could not make the contact sheet") }
    return image
}

// MARK: - Status bar

/// The day the iPad's status bar shows in every screenshot: store-screenshots.sh sets the simulator's clock to 9:41 on it
/// (`status_bar_time`), and its self-test checks that the two agree
let statusBarDay = "2007-01-09"

/// That day, a Tuesday, as the iPad's status bar writes it in each language of the listing, in the device's own format.
/// A locale uses the date of its language, as it uses its captures.
let statusBarDates: [String: String] = [
    "de": "Dienstag 9. Jan.",
    "en": "Tue Jan 9",
    "es": "Martes 9 de enero",
    "fr": "Mardi 9 janvier",
    "it": "Mar 9 gen",
    "pt": "Terça-feira 9 de janeiro",
]

/// The iPad's status bar in a capture (iOS 27.0, a screen of scale 2): the time, the date and the app's name at the top
/// left, in black, the date in the system font of 14 points, medium
enum StatusBar {
    /// The rows of the bar's text, with some background above and below it, from the top: the text is in rows 21 to 42,
    /// and the corner of a sheet comes up to row 55
    static let rows = 10..<54
    /// The baseline of the text, from the top
    static let baseline = 42
    /// The share of the width, from the left, that holds the time, the date and the name
    static let searchedShare = 0.4
    static let scale: CGFloat = 2
    static let fontSize: CGFloat = 14
    static let fontWeight: CGFloat = 0.23
    /// How much darker than the background, in luminance, a pixel of text is
    static let inkContrast = 16
    /// The least space between two items of the bar, in pixels: the words of the date are closer
    static let itemGap = 16
    /// How far a pixel of the background around the date and the name may be from the plain colour, in each channel
    static let tolerance = 4
    /// The pixels on each side of the date and the name that belong to them: the soft edges of their letters
    static let margin = 3
    /// How far left of the ink of its first letter the date starts: that letter is the S of the "Sun" the simulator
    /// writes
    static let originBeforeInk = 1
    /// How far right of the date's width, in whole pixels from its start, the ink of the app's name starts
    static let nameAfterDate = 22
}

func statusBarFont() throws -> CTFont {
    guard let system = CTFontCreateUIFontForLanguage(.system, StatusBar.fontSize, nil) else {
        throw Failure("could not make the font of the status bar")
    }
    let medium = CTFontDescriptorCreateCopyWithAttributes(
        CTFontCopyFontDescriptor(system), [kCTFontTraitsAttribute: [kCTFontWeightTrait: StatusBar.fontWeight]] as CFDictionary
    )
    return CTFontCreateWithFontDescriptor(medium, StatusBar.fontSize, nil)
}

/// The capture with its status bar showing `date`: the date there is painted over with the background and written again,
/// and the app's name after it is moved to keep its space from the date, as the device places it. A capture whose bar is
/// not the time, the date and the name on a plain background, as on every screen of the app, is refused rather than
/// painted over wrong.
func rewritingStatusBarDate(of capture: CGImage, as date: String, path: String) throws -> CGImage {
    let context = try makeCanvas(width: capture.width, height: capture.height)
    context.draw(capture, in: CGRect(x: 0, y: 0, width: capture.width, height: capture.height))
    guard let data = context.data else { throw Failure("could not read the status bar of \(path)") }
    // Row 0 of the bitmap is the top of the image; its pixels are red, green, blue and a byte left unused
    let rowLength = context.bytesPerRow
    let bytes = data.bindMemory(to: UInt8.self, capacity: rowLength * capture.height)
    func channel(_ x: Int, _ y: Int, _ c: Int) -> Int { Int(bytes[y * rowLength + x * 4 + c]) }
    func luminance(_ rgb: [Int]) -> Int { (2126 * rgb[0] + 7152 * rgb[1] + 722 * rgb[2]) / 10_000 }
    func luminance(_ x: Int, _ y: Int) -> Int { luminance((0..<3).map { channel(x, y, $0) }) }
    func median(_ values: [Int]) -> Int { values.sorted()[values.count / 2] }
    let rows = Array(StatusBar.rows)
    let searched = Int(Double(capture.width) * StatusBar.searchedShare)
    let margin = StatusBar.margin

    /// The items of text in `columns`: runs of columns with a pixel darker than the background of its row, those closer
    /// than an item's gap joined
    func items(in columns: Range<Int>, background: [Int]) -> [Range<Int>] {
        var items: [Range<Int>] = []
        for x in columns
        where rows.indices.contains(where: { luminance(x, rows[$0]) < background[$0] - StatusBar.inkContrast }) {
            if let last = items.last, x - last.upperBound < StatusBar.itemGap {
                items[items.count - 1] = last.lowerBound..<(x + 1)
            } else {
                items.append(x..<(x + 1))
            }
        }
        return items
    }
    let found = items(in: 0..<searched, background: rows.map { y in median((0..<searched).map { luminance($0, y) }) })
    guard found.count == 3 else {
        throw Failure("\(path): the status bar shows \(found.count) items at the top left, where the iPad's shows three (the "
                      + "time, the date and the app's name), so its date cannot be written again")
    }
    let oldDate = found[1]
    let name = (found[2].lowerBound - margin)..<(found[2].upperBound + margin)

    // The plain colour of each row, from the date on: every pixel there that is not of the date or the name is close to it
    let repainted = (oldDate.lowerBound - margin)..<searched
    let clear = repainted.filter { x in
        !((oldDate.lowerBound - margin)..<(oldDate.upperBound + margin)).contains(x) && !name.contains(x)
    }
    let plain = rows.map { y in (0..<3).map { c in median(clear.map { channel($0, y, c) }) } }
    for (row, y) in rows.enumerated() {
        for x in clear where (0..<3).contains(where: { abs(channel(x, y, $0) - plain[row][$0]) > StatusBar.tolerance }) {
            throw Failure("\(path): the status bar is not on a plain background around its date (at x \(x), y \(y)), so "
                          + "its date cannot be written again")
        }
    }

    // The name is kept aside, the date and the name painted over, and the date written where the old one started
    let nameBlock = rows.map { y in Array(UnsafeBufferPointer(start: bytes + y * rowLength + name.lowerBound * 4,
                                                              count: name.count * 4)) }
    for (row, y) in rows.enumerated() {
        for x in repainted {
            for c in 0..<3 { bytes[y * rowLength + x * 4 + c] = UInt8(plain[row][c]) }
        }
    }
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: date, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): try statusBarFont(),
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
    ]))
    context.saveGState()
    context.setShouldSmoothFonts(false)
    context.scaleBy(x: StatusBar.scale, y: StatusBar.scale)
    context.textPosition = CGPoint(x: CGFloat(oldDate.lowerBound - StatusBar.originBeforeInk) / StatusBar.scale,
                                   y: CGFloat(capture.height - StatusBar.baseline) / StatusBar.scale)
    CTLineDraw(line, context)
    context.restoreGState()

    // The name follows the new date where the device puts it: at a fixed space after the date's width, which the device
    // rounds up to a whole pixel
    let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) * StatusBar.scale
    let nameStart = oldDate.lowerBound - StatusBar.originBeforeInk + Int(width.rounded(.up)) + StatusBar.nameAfterDate - margin
    guard nameStart + name.count <= searched else {
        throw Failure("\(path): the date \"\(date)\" leaves no room for the app's name in the status bar")
    }
    for (row, y) in rows.enumerated() {
        (bytes + y * rowLength + nameStart * 4).update(from: nameBlock[row], count: nameBlock[row].count)
    }
    guard let image = context.makeImage() else { throw Failure("could not write the status bar of \(path)") }
    return image
}

// MARK: - Output

/// Where a run makes its output before it puts it in place, where it moves what it replaces, and the file that says that a
/// run is putting the output in place, all in the output directory, so that moving is renaming
let stagingName = ".compose-staging"
let previousName = ".compose-previous"
let promotingName = ".compose-promoting"

/// The self-test's way to end a run as a kill does, with no chance to clean up: after the nth move into place (0: after the
/// marker is written, before the first move). Unset, as it is outside the self-test, it does nothing.
let killAfterMove = ProcessInfo.processInfo.environment["COMPOSE_TEST_KILL_AFTER_MOVE"].flatMap { Int($0) }

/// What a run leaves in the output directory while it puts the output in place. The file is the evidence that the output
/// may hold only part of a set, so it is written before the first move and removed after the last, and a new run refuses
/// while it exists.
func refuseWhileUnfinished(_ output: URL) throws {
    let files = FileManager.default
    let promoting = output.appendingPathComponent(promotingName)
    let previous = output.appendingPathComponent(previousName, isDirectory: true)
    guard !files.fileExists(atPath: promoting.path) else {
        throw Failure("\(promoting.path) is there: an earlier run was stopped while it put its screenshots in place, so "
                      + "\(output.path) may hold only part of that set, and \(previous.path), if it is there, what that run "
                      + "had replaced. The file lists the items. Remove them (or put back those in \(previous.path)), then "
                      + "remove the file and \(previous.path), and run again")
    }
    guard !files.fileExists(atPath: previous.path) else {
        throw Failure("\(previous.path) holds what an earlier run could not put back; move it back or remove it, then run again")
    }
}

/// Puts what a run made in staging (the paths below it are `items`) in the output directory, replacing what is there. An item
/// that exists is moved to `.compose-previous` first. If a step fails, the items already moved are put back, so that the
/// output is as it was, and the error is thrown; what could not be put back stays in `.compose-previous`, and is named.
/// `.compose-promoting` is written before the first move and removed once every item is in place, or put back.
func promote(_ items: [String], from staging: URL, to output: URL) throws {
    struct Step {
        let item: String
        var movedAside = false
        var placed = false
    }
    let files = FileManager.default
    let aside = output.appendingPathComponent(previousName, isDirectory: true)
    let promoting = output.appendingPathComponent(promotingName)
    var steps: [Step] = []
    var moves = 0
    func move(_ source: URL, to destination: URL) throws {
        try files.moveItem(at: source, to: destination)
        moves += 1
        if moves == killAfterMove { kill(getpid(), SIGKILL) }
    }

    do {
        try files.createDirectory(at: output, withIntermediateDirectories: true)
        let listing = (["a run was putting these in place; it removes this file when all are:"] + items).joined(separator: "\n")
        try Data((listing + "\n").utf8).write(to: promoting, options: .atomic)
    } catch {
        throw Failure("could not write \(promoting.path) before the screenshots were put in place (\(error.localizedDescription)); "
                      + "nothing was moved")
    }
    if killAfterMove == 0 { kill(getpid(), SIGKILL) }
    do {
        for item in items {
            let destination = output.appendingPathComponent(item)
            steps.append(Step(item: item))
            if files.fileExists(atPath: destination.path) {
                let previous = aside.appendingPathComponent(item)
                try files.createDirectory(at: previous.deletingLastPathComponent(), withIntermediateDirectories: true)
                try move(destination, to: previous)
                steps[steps.count - 1].movedAside = true
            }
            try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try move(staging.appendingPathComponent(item), to: destination)
            steps[steps.count - 1].placed = true
        }
    } catch {
        let reason = error.localizedDescription
        var notPutBack: [String] = []
        for step in steps.reversed() {
            let destination = output.appendingPathComponent(step.item)
            do {
                if step.placed { try files.removeItem(at: destination) }
                if step.movedAside { try files.moveItem(at: aside.appendingPathComponent(step.item), to: destination) }
            } catch {
                notPutBack.append(step.item)
            }
        }
        // What could not be put back stays in `.compose-previous`, and the file stays with it: the next run refuses
        guard notPutBack.isEmpty else {
            throw Failure("the screenshots could not be put in place (\(reason)), and these could not be put back; they are in "
                          + "\(aside.path), and \(promoting.path) stays until you have looked at them: \(notPutBack.joined(separator: ", "))")
        }
        try? files.removeItem(at: aside)
        do { try files.removeItem(at: promoting) } catch {
            throw Failure("the screenshots could not be put in place (\(reason)), and were put back, but \(promoting.path) could not "
                          + "be removed (\(error.localizedDescription)); remove it, or the next run refuses")
        }
        throw Failure("the screenshots could not be put in place (\(reason)); the output is as it was")
    }
    try? files.removeItem(at: aside)
    // The last step: the file is there until every item, the contact sheets too, is in place
    do { try files.removeItem(at: promoting) } catch {
        throw Failure("the screenshots are in place, but \(promoting.path) could not be removed (\(error.localizedDescription)); "
                      + "remove it, or the next run refuses")
    }
}

// MARK: - Main

func run(_ arguments: [String]) throws {
    guard arguments.count == 5 || arguments.count == 6 else {
        throw Failure("usage: compose-store-screenshots <store-listing.md> <captures dir> <output dir> <device,...> [<language>,...]")
    }
    let languages = arguments.count == 6 ? Set(arguments[5].split(separator: ",").map(String.init)) : nil
    let listing = try String(contentsOf: URL(fileURLWithPath: arguments[1]), encoding: .utf8)
    let capturesDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
    let outputDirectory = URL(fileURLWithPath: arguments[3], isDirectory: true)
    let locales = captions(in: listing)
    guard !locales.isEmpty else { throw Failure("no screenshot captions in \(arguments[1])") }
    // Every locale is checked, those not composed too, and before anything is written
    for (locale, lines) in locales where lines.count != screenshotCount {
        throw Failure("\(locale) has \(lines.count) screenshot captions and needs exactly \(screenshotCount), "
                      + "one for each screenshot")
    }

    // The output is made in `.compose-staging` and put in place at the end (`promote`). A run that was stopped while it put its
    // output in place left `.compose-promoting` (and `.compose-previous`, if it had moved something aside): the output may
    // hold only part of a set, and a new run is not to take it for a whole one, or to write over what was set aside.
    let files = FileManager.default
    let staging = outputDirectory.appendingPathComponent(stagingName, isDirectory: true)
    try refuseWhileUnfinished(outputDirectory)
    try? files.removeItem(at: staging)
    defer { try? files.removeItem(at: staging) }
    var items: [String] = []
    var report: [String] = []

    for key in arguments[4].split(separator: ",").map(String.init) {
        guard let device = devices[key] else { throw Failure("unknown device \(key); known: \(devices.keys.sorted())") }
        var layout = Layout(canvas: CGSize(width: device.width, height: device.height))
        // Every locale is set first, those not composed too, so that the band, and the screenshot under it, is the
        // same in every run
        var set: [(locale: String, captions: [(title: SetCaption, line: SetCaption)])] = []
        for (locale, captions) in locales {
            set.append((locale, try setCaptions(captions.map(Caption.init), device: device, layout: layout)))
        }
        layout.captionHeight = set.flatMap(\.captions).map { height(of: $0, in: layout) }.max() ?? 0

        var rows: [(locale: String, images: [CGImage])] = []
        for (locale, captions) in set {
            let language = String(locale.prefix(2))
            if let languages, !languages.contains(language) { continue }
            let statusBarDate = statusBarDates[language]
            guard statusBarDate != nil || !device.showsDateInStatusBar else {
                throw Failure("no status bar date for \(language): add \(statusBarDay) as the \(device.label) writes it "
                              + "in \(language) to statusBarDates")
            }
            // All the images of the locale are composed before the first is written: a capture that is missing or
            // wrong leaves nothing of the locale half written
            var images: [CGImage] = []
            for (index, caption) in captions.enumerated() {
                let number = String(format: "%02d.png", index + 1)
                let url = capturesDirectory.appendingPathComponent("\(key)/\(language)/\(number)")
                var capture = try loadCapture(url, for: device)
                if device.showsDateInStatusBar, let statusBarDate {
                    capture = try rewritingStatusBarDate(of: capture, as: statusBarDate, path: url.path)
                }
                images.append(try compose(caption: caption, capture: capture, device: device, layout: layout))
            }
            // Written aside: the folder replaces the one of an earlier run, as a whole, once the run has made everything
            let folder = staging.appendingPathComponent("\(locale)/\(key)", isDirectory: true)
            for (index, image) in images.enumerated() {
                try writePNG(image, to: folder.appendingPathComponent(String(format: "%02d.png", index + 1)))
            }
            items.append("\(locale)/\(key)")
            rows.append((locale, images))
            report.append("\(locale) \(key): \(images.count) screenshots")
        }
        let sheet = "contact-sheet-\(key).png"
        try writePNG(try contactSheet(rows, device: device), to: staging.appendingPathComponent(sheet))
        items.append(sheet)
    }
    try promote(items, from: staging, to: outputDirectory)
    for line in report { print(line) }
}

do {
    try run(CommandLine.arguments)
} catch {
    FileHandle.standardError.write(Data("compose-store-screenshots: \(error)\n".utf8))
    exit(1)
}
