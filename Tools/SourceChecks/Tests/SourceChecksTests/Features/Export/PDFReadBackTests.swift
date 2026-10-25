import Testing
import Foundation

// MARK: - What reading a PDF back costs in the tests

/// The suites that print PDFs with the real renderer read each PDF back with PDFKit (`PDFLayout`), and the attributed text
/// of a page is by far the dearest read, and the only dear one: PDFKit looks up each embedded font by name, fails, and logs a
/// note for every run of text. Read for every PDF, it took about a quarter of the time of the suites and left about a million
/// notes, a third of a gigabyte of log, in each run. Only the tests that compare the sizes of the fonts need them. These
/// checks keep it that way: the cost would come back with one new `attributedString`.
@Suite("PDF read-back in the tests - the fonts are read only by the code that compares their sizes")
struct PDFReadBackTests {

    // MARK: - Helpers

    /// The file of the layout that the PDF suites read back, from the root of the repository
    private static let layoutPath = "PrestoCVTests/TestSupport/PDFLayout.swift"

    /// The property that holds the attributed text of a page
    private static let attributedText = try! NSRegularExpression(pattern: #"\battributedString\b"#)

    private static func occurrences(in text: String) -> [Int] {
        text.components(separatedBy: .newlines).enumerated().compactMap { index, line in
            attributedText.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) == nil ? nil : index
        }
    }

    /// The lines of the member of `PDFLayout` that starts with `declaration`: up to the line that closes it, a lone brace at
    /// the indentation of the members
    private static func member(startingWith declaration: String, in text: String) -> (range: Range<Int>, lines: [String])? {
        let lines = text.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("    " + declaration) || $0.hasPrefix("    private " + declaration) }),
              let end = lines[start...].firstIndex(where: { $0 == "    }" }) else { return nil }
        return (start..<(end + 1), Array(lines[start...end]))
    }

    private func layoutSource() throws -> String {
        try String(contentsOf: Repository.root.appendingPathComponent(Self.layoutPath), encoding: .utf8)
    }

    // MARK: - Who reads the attributed text

    @Test("Only PDFLayout reads the attributed text of a PDF page in the app's tests")
    func onlyPDFLayoutReadsTheAttributedText() throws {
        let files = try RepositorySources.swiftFiles(in: "PrestoCVTests")
        try #require(files.contains { $0.path == Self.layoutPath }, "\(Self.layoutPath) is among the tests' sources")

        let readers = files.filter { !Self.occurrences(in: $0.text).isEmpty }.map(\.path)
        #expect(readers == [Self.layoutPath], "The attributed text of a page costs a log note per run of text: read it only in PDFLayout's font-size code, found in \(readers)")
    }

    @Test("PDFLayout reads it only in its font-size code, which finds the sizes of a document's fonts")
    func layoutReadsItOnlyForTheFontSizes() throws {
        let source = try layoutSource()
        let fontSizes = try #require(Self.member(startingWith: "static func fontSizes(of ", in: source),
                                     "The font-size code of PDFLayout is a function fontSizes(of:); if it moved, update this check")

        let reads = Self.occurrences(in: source)
        try #require(!reads.isEmpty, "The check finds the read of the attributed text in \(Self.layoutPath)")
        #expect(reads.allSatisfy { fontSizes.range.contains($0) }, "Lines \(reads.map { $0 + 1 }) read the attributed text outside fontSizes(of:)")
    }

    // MARK: - Who asks for the fonts

    @Test("Creating a PDFLayout reads no font: its init neither reads the attributed text nor asks for the sizes")
    func creatingALayoutReadsNoFont() throws {
        let initializer = try #require(Self.member(startingWith: "init?(pdf ", in: try layoutSource()),
                                       "PDFLayout is created from a PDF by init?(pdf:margins:); if it moved, update this check")

        let body = initializer.lines.joined(separator: "\n")
        #expect(!body.contains("attributedString"), "The init reads the attributed text of every page, which only the font-size tests need")
        #expect(!body.contains("fontSizes"), "The init asks for the sizes of the fonts of every PDF, which only the font-size tests need")
    }
}
