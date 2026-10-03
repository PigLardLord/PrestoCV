import Foundation

/// The one normalisation every word-list match uses, so a language is added as data and not as a rule: case and
/// accents are dropped, runs of white space are one space, and the ends are trimmed.
///
/// Compatibility decomposition splits a letter from its diacritics and expands ligatures, and the combining marks
/// U+0300 to U+036F are then dropped, so "à", "ä" and "é" fold without a rule of their own. "ß" is the exception no
/// normalisation form covers, because it decomposes to itself, so it becomes "ss". It is a port of cv-giovanni's
/// `domain/fold.js` (licence ISC, commit 6e28147) and returns what that function returns, down to a capital sharp s
/// ("ẞ") that lowercases to "ß" and stays one, and a capital sigma that is a final sigma ("ς") at the end of a word.
public enum TextFold {
    public static func fold(_ text: String) -> String {
        var scalars: [Unicode.Scalar] = []
        for scalar in text.decomposedStringWithCompatibilityMapping.unicodeScalars where !combiningMarks.contains(scalar.value) {
            if scalar == "\u{00DF}" {
                scalars.append("s")
                scalars.append("s")
            } else {
                scalars.append(scalar)
            }
        }
        return squeezed(lowercased(scalars))
    }

    private static let combiningMarks: ClosedRange<UInt32> = 0x0300...0x036F

    /// Lowercase by the full Unicode mapping. A capital sigma is "ς" at the end of a word and "σ" elsewhere: the one
    /// mapping that depends on its neighbours.
    private static func lowercased(_ scalars: [Unicode.Scalar]) -> [Unicode.Scalar] {
        var result: [Unicode.Scalar] = []
        for (index, scalar) in scalars.enumerated() {
            if scalar == "\u{03A3}" {
                result.append(endsWord(at: index, in: scalars) ? "\u{03C2}" : "\u{03C3}")
            } else {
                result.append(contentsOf: scalar.properties.lowercaseMapping.unicodeScalars)
            }
        }
        return result
    }

    /// A sigma that follows a cased letter, ignoring case-ignorable characters, and is not followed by one.
    private static func endsWord(at index: Int, in scalars: [Unicode.Scalar]) -> Bool {
        let before = scalars[..<index].last { !$0.properties.isCaseIgnorable }
        let after = scalars[(index + 1)...].first { !$0.properties.isCaseIgnorable }
        return before?.properties.isCased == true && after?.properties.isCased != true
    }

    /// Each run of white space is one space, and none starts or ends the result.
    private static func squeezed(_ scalars: [Unicode.Scalar]) -> String {
        var result = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in scalars {
            if isWhiteSpace(scalar) {
                pendingSpace = !result.isEmpty
            } else {
                if pendingSpace { result.append(" ") }
                pendingSpace = false
                result.append(scalar)
            }
        }
        return String(result)
    }

    /// What `\s` matches in the source: the white space and the line terminators of ECMAScript.
    /// U+0085 and U+180E are not among them.
    private static func isWhiteSpace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0009...0x000D, 0x0020, 0x00A0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF: true
        default: false
        }
    }
}
