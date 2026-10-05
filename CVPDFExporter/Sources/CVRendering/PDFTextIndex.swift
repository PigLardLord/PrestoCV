import Foundation

/// The text of a PDF, lower-cased and without white space, with where the PDF text broke: whether white space (or the
/// start of the text) comes before each scalar, and whether white space (or the end) comes after it.
struct PDFTextIndex {
    let scalars: [Unicode.Scalar]
    private let startsAfterBreak: [Bool]
    private let endsBeforeBreak: [Bool]

    init(_ pdfText: String) {
        var kept: [Unicode.Scalar] = [], afterBreak: [Bool] = []
        var sawBreak = true
        for scalar in Self.lowercasedScalars(pdfText) {
            if Self.isBreak(scalar) { sawBreak = true; continue }
            kept.append(scalar)
            afterBreak.append(sawBreak)
            sawBreak = false
        }
        scalars = kept
        startsAfterBreak = afterBreak
        endsBeforeBreak = kept.indices.map { $0 + 1 == kept.count || afterBreak[$0 + 1] }
    }

    /// The one rule for comparing text with the PDF's: case and white space do not count, since designs may use
    /// text-transform and PDF text extraction does not preserve spacing.
    static func lowercasedScalars(_ text: String) -> String.UnicodeScalarView { text.lowercased().unicodeScalars }

    static func isBreak(_ scalar: Unicode.Scalar) -> Bool { scalar.properties.isWhitespace }

    /// The scalars of a text node as the index holds the PDF's: lower-cased, with no white space.
    static func comparableScalars(of text: String) -> [Unicode.Scalar] {
        lowercasedScalars(text).filter { !isBreak($0) }
    }

    /// The positions where `needle` occurs, best first: the spans that start and end where the PDF text breaks, then
    /// those that do at one end only, then the rest, each group in order of position. `needle` is not empty.
    func occurrences(of needle: [Unicode.Scalar]) -> [Int] {
        guard needle.count <= scalars.count else { return [] }
        let starts = (0...(scalars.count - needle.count)).filter { matches(needle, at: $0) }
        return starts.sorted { (breakCount($0, needle.count), $0) < (breakCount($1, needle.count), $1) }
    }

    private func matches(_ needle: [Unicode.Scalar], at start: Int) -> Bool {
        scalars[start] == needle[0] && scalars[start..<start + needle.count].elementsEqual(needle)
    }

    /// 0 for a span that starts and ends at a break, 2 for one that does neither.
    private func breakCount(_ start: Int, _ length: Int) -> Int {
        (startsAfterBreak[start] ? 0 : 1) + (endsBeforeBreak[start + length - 1] ? 0 : 1)
    }
}
