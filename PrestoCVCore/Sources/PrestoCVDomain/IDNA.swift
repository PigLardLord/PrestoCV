import Foundation   // String normalisation only: no ambient state (R2)

/// How a domain label is written on the wire by IDNA (RFC 5890, RFC 5891), to know how long it is once encoded. A label
/// is mapped the way UTS 46 maps it for a lookup, approximated with what Foundation and the standard library offer on
/// every platform. Each scalar is mapped on its own: default-ignorable letters, marks and digits (variation selectors,
/// invisible fillers) are dropped, the lunate sigma and the mathematical final sigmas become sigma, and the scalar is
/// put in compatibility normalisation (NFKC), lowercased, decomposed, and case folded where case folding differs from
/// lowercasing (the iota subscript, the Cherokee and small Cyrillic letters). The mapped scalars are put in NFC once, at
/// the end. So fullwidth letters and ligatures count as the letters they stand for. The sharp s and the final sigma keep
/// the form lowercasing leaves them, as in non-transitional processing. A label that is not a label once mapped has no
/// A-label: it must be letters, marks, digits and hyphens, with no hyphen at either end and no mark at the start, and
/// the middle dot only between two "l" (RFC 5892 appendix A.3). The rest of the UTS 46 table is not applied: the
/// characters it disallows are not refused, nor are the bidirectional rule and the other contextual rules.
enum IDNA {
    private static let hyphen: Unicode.Scalar = "-", middleDot: Unicode.Scalar = "\u{00B7}", ell: Unicode.Scalar = "l"

    /// The mapped label when it is ASCII, otherwise `xn--` and its Punycode. nil when the mapped label is not a label
    /// or the encoding overflows.
    static func aLabel(_ label: String) -> String? {
        let mappedLabel = map(label)
        guard isLabel(Array(mappedLabel.unicodeScalars)) else { return nil }
        guard !mappedLabel.unicodeScalars.allSatisfy(\.isASCII) else { return mappedLabel }
        return Punycode.encode(mappedLabel).map { "xn--" + $0 }
    }

    private static func map(_ label: String) -> String {
        var folded = String.UnicodeScalarView()
        for scalar in label.unicodeScalars where !isIgnored(scalar) {
            var one = String.UnicodeScalarView()
            one.append(sigmaMapped(scalar))
            let lowered = String(one).precomposedStringWithCompatibilityMapping.lowercased()
            folded.append(contentsOf: lowered.decomposedStringWithCanonicalMapping.unicodeScalars.map(caseFolded))
        }
        return String(folded).precomposedStringWithCanonicalMapping
    }

    /// The default-ignorable letters, marks and digits, which UTS 46 maps to nothing. The format characters, such as the
    /// joiners, are not among them: they are not ignored, so they make the label invalid.
    private static func isIgnored(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isDefaultIgnorableCodePoint && isLetterMarkOrDigit(scalar)
    }

    /// UTS 46 maps the lunate sigma symbol and the mathematical final sigmas to sigma. Their compatibility mapping would
    /// give the final sigma, which non-transitional processing keeps only for the letter itself.
    private static func sigmaMapped(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        switch scalar.value {
        case 0x03F2, 0x1D6D3, 0x1D70D, 0x1D747, 0x1D781, 0x1D7BB: "\u{03C3}"
        default: scalar
        }
    }

    /// The scalars where case folding differs from lowercasing and UTS 46 follows case folding, from the simple and
    /// common foldings of CaseFolding.txt (Unicode 16). The combining iota subscript is a letter once folded, which is
    /// why the scalar is decomposed first. The sharp s and the final sigma are left alone: non-transitional processing
    /// keeps them.
    static func caseFolded(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        let folded: UInt32
        switch scalar.value {
        case 0x0345: folded = 0x03B9
        case 0xAB70...0xABBF: folded = scalar.value - 0xAB70 + 0x13A0
        case 0x13F8...0x13FD: folded = scalar.value - 0x13F8 + 0x13F0
        case 0x1C80: folded = 0x0432
        case 0x1C81: folded = 0x0434
        case 0x1C82: folded = 0x043E
        case 0x1C83: folded = 0x0441
        case 0x1C84, 0x1C85: folded = 0x0442
        case 0x1C86: folded = 0x044A
        case 0x1C87: folded = 0x0463
        case 0x1C88: folded = 0xA64B
        default: return scalar
        }
        return Unicode.Scalar(folded) ?? scalar
    }

    /// Letters, marks, digits and hyphens, with no hyphen at either end and no mark at the start: a label under the
    /// STD3 rules of UTS 46. Compatibility mapping can produce punctuation, as "⒈" maps to "1.". The middle dot, which
    /// "ŀ" maps to after an "l", is allowed between two "l" only.
    private static func isLabel(_ scalars: [Unicode.Scalar]) -> Bool {
        guard let first = scalars.first, let last = scalars.last, first != hyphen, last != hyphen, !isMark(first) else {
            return false
        }
        for (index, scalar) in scalars.enumerated() where scalar != hyphen && !isLetterMarkOrDigit(scalar) {
            guard scalar == middleDot, index > 0, index + 1 < scalars.count,
                  scalars[index - 1] == ell, scalars[index + 1] == ell else { return false }
        }
        return true
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
