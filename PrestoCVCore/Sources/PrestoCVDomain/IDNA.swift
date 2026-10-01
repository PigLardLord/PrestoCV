import Foundation   // String normalisation only: no ambient state (R2)

/// How a domain label is written on the wire by IDNA (RFC 5890, RFC 5891), to know how long it is once encoded. A label
/// is mapped the way UTS 46 maps it for a lookup, approximated with what Foundation offers on every platform:
/// compatibility normalisation (NFKC), lowercasing and NFC, so that fullwidth letters and ligatures count as the letters
/// they stand for. The mapping table of UTS 46 itself is not applied: the characters it disallows are not refused, and
/// the deviation characters (the sharp s, the final sigma, the zero-width joiners) keep the form lowercasing leaves them,
/// as in non-transitional processing. A label that is not a label once mapped has no A-label.
enum IDNA {
    private static let hyphen: Unicode.Scalar = "-"

    /// The mapped label when it is ASCII, otherwise `xn--` and its Punycode. nil when the mapped label is not a label
    /// or the encoding overflows.
    static func aLabel(_ label: String) -> String? {
        let mapped = label.precomposedStringWithCompatibilityMapping.lowercased().precomposedStringWithCanonicalMapping
        guard isLabel(mapped.unicodeScalars) else { return nil }
        guard !mapped.unicodeScalars.allSatisfy(\.isASCII) else { return mapped }
        return Punycode.encode(mapped).map { "xn--" + $0 }
    }

    /// Letters, marks, digits and hyphens, with no hyphen at either end and no mark at the start: a label under the
    /// STD3 rules of UTS 46. Compatibility mapping can produce punctuation, as "⒈" maps to "1.".
    private static func isLabel(_ scalars: String.UnicodeScalarView) -> Bool {
        guard let first = scalars.first, let last = scalars.last, first != hyphen, last != hyphen, !isMark(first) else { return false }
        return scalars.allSatisfy { $0 == hyphen || isLetterMarkOrDigit($0) }
    }

    private static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark: true
        default: false
        }
    }

    private static func isLetterMarkOrDigit(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter,
             .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .letterNumber, .otherNumber: true
        default: false
        }
    }
}
