import Foundation

/// Names an exported CV: the title stored in the PDF and the name of the file the person shares, in the language of
/// the PDF: "<Full name> – CV" and "<Full name> – CV.pdf" in English, "<Full name> – Lebenslauf.pdf" in German.
///
/// The name comes from the CV's person, or from the CV's own name when the person has none, and ends up in a file
/// system path, so it is cleaned: no path separators or other characters file systems reject, no control characters,
/// one space between words, at most `maxNameLength` characters, and a whole file name of at most `maxFileNameBytes`
/// bytes, cut between characters, never inside one.
public struct PDFFileName: Sendable {

    public static let pathExtension = "pdf"
    public static let maxNameLength = 100
    public static let fallbackTitle = "CV"

    /// The longest file name, with its pattern and extension, counted in UTF-8 bytes. A path component is limited
    /// to 255 bytes, and the atomic write of the file adds a suffix to the name while it works, so this stays well
    /// below. A name never has more UTF-16 units than UTF-8 bytes, so this bounds both encodings.
    public static let maxFileNameBytes = 200

    /// Where the name goes in a pattern
    public static let placeholder = "%@"

    /// The scalars that file systems reject in a name, or read as a path separator
    private static let forbiddenScalars: Set<Unicode.Scalar> = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]

    /// The scalars that reorder text on screen, so that a name can look like another one: bidirectional controls
    private static let bidirectionalControls: ClosedRange<Unicode.Scalar> = "\u{202A}"..."\u{202E}"
    private static let bidirectionalIsolates: ClosedRange<Unicode.Scalar> = "\u{2066}"..."\u{2069}"

    /// The pattern of the title in the language of the PDF, with `placeholder` where the name goes
    private let titlePattern: String

    /// - Parameter titlePattern: The pattern of the title in the language of the PDF: "%@ – CV" in English.
    public init(titlePattern: String) {
        self.titlePattern = titlePattern
    }

    /// "<Full name> – CV", or just "CV" when neither name is usable
    public func title(personName: String, cvName: String) -> String {
        let nameBudget = Self.maxFileNameBytes - titleOverheadBytes
        guard let name = [personName, cvName].lazy.map({ Self.fitted(Self.cleaned($0), toBytes: nameBudget) })
            .first(where: { !$0.isEmpty }) else {
            return Self.fallbackTitle
        }
        return titlePattern.replacingOccurrences(of: Self.placeholder, with: name)
    }

    /// The title with the PDF extension: "<Full name> – CV.pdf"
    public func fileName(personName: String, cvName: String) -> String {
        "\(title(personName: personName, cvName: cvName)).\(Self.pathExtension)"
    }

    /// The bytes of the file name that do not belong to the person's name: the pattern around it and the extension
    private var titleOverheadBytes: Int {
        titlePattern.replacingOccurrences(of: Self.placeholder, with: "").utf8.count + ".".utf8.count + Self.pathExtension.utf8.count
    }

    // MARK: - Cleaning

    private static func cleaned(_ name: String) -> String {
        let withoutForbidden = name.precomposedStringWithCanonicalMapping.filter { character in
            !holdsForbiddenScalar(character) && !character.unicodeScalars.contains(where: isInvisibleControl)
        }
        let singleSpaced = withoutForbidden.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(singleSpaced.drop(while: { $0.unicodeScalars.first == "." }))
    }

    /// Whether a character holds a scalar that file systems reject, in either canonical form: the marks that combine
    /// with a slash do not make it harmless, and "≮" is "<" with a mark once decomposed. Such a character goes whole,
    /// with its marks.
    private static func holdsForbiddenScalar(_ character: Character) -> Bool {
        String(character).decomposedStringWithCanonicalMapping.unicodeScalars.contains(where: forbiddenScalars.contains)
    }

    /// The longest start of the name that has at most `maxNameLength` characters and `budget` bytes in UTF-8.
    /// It ends between characters: a character that does not fit, however long its sequence of code points is, is
    /// left out whole.
    private static func fitted(_ name: String, toBytes budget: Int) -> String {
        var result = ""
        var bytes = 0
        for character in name.prefix(maxNameLength) {
            let size = String(character).utf8.count
            guard bytes + size <= budget else { break }
            result.append(character)
            bytes += size
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Control characters other than the whitespace ones, which separate words instead
    private static func isInvisibleControl(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.isWhitespace {
            return false
        }
        return scalar.properties.generalCategory == .control
            || bidirectionalControls.contains(scalar)
            || bidirectionalIsolates.contains(scalar)
    }
}
