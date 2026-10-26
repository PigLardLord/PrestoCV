#if canImport(PDFKit)
import CoreText
import Foundation
import Testing

/// A font the PDFKit tests draw with when the test runs.
enum DrawnFace: CaseIterable, CustomTestStringConvertible {
    /// A font of the base 14, which PDFKit gives back by name, with its weight.
    case helvetica
    /// A serif font of the base 14, whose strokes vary in width.
    case times
    /// The system's font. The PDF embeds a subset whose name PDFKit cannot find again: it gives every run back as Times,
    /// whatever the weight drawn (the same happens to the PDFs of generators that embed their fonts as CID fonts).
    case system

    var testDescription: String {
        switch self {
        case .helvetica: "Helvetica"
        case .times: "Times"
        case .system: "the system font"
        }
    }

    func font(_ size: CGFloat, bold: Bool) -> CTFont {
        switch self {
        case .helvetica:
            CTFontCreateWithName((bold ? "Helvetica-Bold" : "Helvetica") as CFString, size, nil)
        case .times:
            CTFontCreateWithName((bold ? "Times-Bold" : "Times-Roman") as CFString, size, nil)
        case .system:
            // The emphasized system font is a semibold; the bold trait asks for the weight a PDF's bold fonts have
            Self.system(size, bold: bold)
        }
    }

    private static func system(_ size: CGFloat, bold: Bool) -> CTFont {
        let regular = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        guard bold else { return regular }
        return CTFontCreateCopyWithSymbolicTraits(regular, size, nil, .boldTrait, .boldTrait) ?? regular
    }
}
#endif
