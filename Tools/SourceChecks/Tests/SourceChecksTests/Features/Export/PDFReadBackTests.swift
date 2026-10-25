import Testing
import Foundation

// MARK: - What reading a PDF back costs in the tests

/// The suites that print PDFs with the real renderer read each PDF back with PDFKit (`PDFLayout`), and the attributed text
/// of a page is by far the dearest read, and the only dear one: PDFKit looks up each embedded font by name, fails, and logs a
/// note for every run of text. Read for every PDF, it took about a quarter of the time of the suites and left about a million
/// notes, a third of a gigabyte of log, in each run. Only the tests that compare the sizes of the fonts need them. These
/// checks keep it that way: the cost would come back with one new `attributedString`.
///
/// The checks read the code of the files, not their comments: a comment may name what it explains, and code may not hide
/// behind one (`SwiftCode`).
@Suite("PDF read-back in the tests - the fonts are read only by the code that compares their sizes")
struct PDFReadBackTests {

    // MARK: - Helpers

    /// The file of the layout that the PDF suites read back, from the root of the repository
    private static let layoutPath = "PrestoCVTests/TestSupport/PDFLayout.swift"

    /// The property that holds the attributed text of a page
    private static let attributedText = try! NSRegularExpression(pattern: #"\battributedString\b"#)

    /// What the init of the layout may not name: the read of the fonts, and the sizes it finds
    private static let fontWords = try! NSRegularExpression(pattern: #"\b(attributedString|fontSizes)\b"#)

    /// What is wrong in the source of `PDFLayout`: where it reads the attributed text of a page outside the code that finds
    /// the sizes of the fonts, and where its init asks for them
    static func problems(in source: String) -> [String] {
        let code = SwiftCode(source)
        guard let reader = code.member(startingWith: "static func fontSizes(of "),
              let initializer = code.member(startingWith: "init?(pdf ") else {
            return ["PDFLayout has a function fontSizes(of:) and an init?(pdf:margins:); if one moved, update this check"]
        }

        var problems: [String] = []
        let reads = code.lines(matching: attributedText)
        if reads.isEmpty {
            problems.append("The check finds no read of the attributed text in the source")
        }
        let outside = reads.filter { !reader.contains($0) }
        if !outside.isEmpty {
            problems.append("Lines \(outside.map { $0 + 1 }) read the attributed text outside fontSizes(of:)")
        }
        let early = code.lines(matching: fontWords).filter { initializer.contains($0) }
        if !early.isEmpty {
            problems.append("Lines \(early.map { $0 + 1 }) of the init read the fonts, which only the font-size tests need")
        }
        return problems
    }

    private func layoutSource() throws -> String {
        try String(contentsOf: Repository.root.appendingPathComponent(Self.layoutPath), encoding: .utf8)
    }

    // MARK: - The tests' sources

    @Test("Only PDFLayout reads the attributed text of a PDF page in the app's tests")
    func onlyPDFLayoutReadsTheAttributedText() throws {
        let files = try RepositorySources.swiftFiles(in: "PrestoCVTests")
        try #require(files.contains { $0.path == Self.layoutPath }, "\(Self.layoutPath) is among the tests' sources")

        let readers = files.filter { !SwiftCode($0.text).lines(matching: Self.attributedText).isEmpty }.map(\.path)
        #expect(readers == [Self.layoutPath], "The attributed text of a page costs a log note per run of text: read it only in PDFLayout's font-size code, found in \(readers)")
    }

    @Test("PDFLayout reads the attributed text only in its font-size code, and creating a layout reads no font")
    func layoutReadsTheFontsOnlyForTheirSizes() throws {
        let problems = Self.problems(in: try layoutSource())

        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }

    // MARK: - The check itself

    /// A layout as `PDFLayout` is made, small enough to change one thing in
    private static let model = """
        import Foundation
        import PDFKit

        struct PDFLayout {
            var fontSizes: Set<Double> { fonts.sizes }

            private let fonts: Fonts

            init?(pdf url: URL, margins: Int) {
                guard let data = try? Data(contentsOf: url) else { return nil }
                self.fonts = Fonts(pdf: data)
            }

            private final class Fonts: Sendable {
                private let pdf: Data
                init(pdf: Data) { self.pdf = pdf }

                var sizes: Set<Double> {
                    var found = Set<Double>()
                    if let document = PDFDocument(data: pdf) { found = PDFLayout.fontSizes(of: document) }
                    return found
                }
            }

            private static func fontSizes(of document: PDFDocument) -> Set<Double> {
                var sizes = Set<Double>()
                for index in 0..<document.pageCount {
                    guard let text = document.page(at: index)?.attributedString else { continue }
                    sizes.insert(Double(text.length))
                }
                return sizes
            }

            func fontSizes(matching other: PDFLayout) -> Bool {
                fontSizes == other.fontSizes
            }
        }
        """

    /// A change to the model: `old` is in it once
    struct Change: CustomTestStringConvertible, Sendable {
        let name: String
        let old: String
        let new: String
        var testDescription: String { name }

        func applied(to source: String) throws -> String {
            try #require(source.components(separatedBy: old).count == 2, "\(old) is once in the model")
            return source.replacing(old, with: new)
        }
    }

    private static let afterFontsAreSet = "        self.fonts = Fonts(pdf: data)\n"
    private static let beforeComparison = "    func fontSizes(matching other: PDFLayout) -> Bool {\n"
    private static let readInInit = "        _ = PDFDocument(data: data)?.page(at: 0)?.attributedString\n"

    static let accepted = [
        Change(name: "a line comment naming the read in the init",
               old: afterFontsAreSet,
               new: "        self.fonts = Fonts(pdf: data) // not attributedString, not fontSizes\n"),
        Change(name: "a doc comment naming the read in the init",
               old: "    init?(pdf url: URL, margins: Int) {\n",
               new: "    /// Reads no attributedString and asks for no fontSizes\n    init?(pdf url: URL, margins: Int) {\n"),
        Change(name: "a block comment naming the read in the init",
               old: afterFontsAreSet,
               new: "        /* attributedString\n           fontSizes */\n" + afterFontsAreSet),
        Change(name: "a comment naming the read in another member",
               old: beforeComparison,
               new: "    /// attributedString is dear\n" + beforeComparison),
    ]

    static let refused = [
        Change(name: "the read of the attributed text in the init",
               old: afterFontsAreSet,
               new: afterFontsAreSet + readInInit),
        Change(name: "the read of the attributed text in another member",
               old: beforeComparison,
               new: "    func warm(_ document: PDFDocument) { _ = document.page(at: 0)?.attributedString }\n" + beforeComparison),
        Change(name: "the sizes asked for in the init",
               old: afterFontsAreSet,
               new: afterFontsAreSet + "        _ = fontSizes\n"),
        Change(name: "code after a block comment on its line",
               old: afterFontsAreSet,
               new: afterFontsAreSet + "        /* a */ _ = PDFDocument(data: data)?.page(at: 0)?.attributedString\n"),
        Change(name: "code after a line comment mark in a string",
               old: afterFontsAreSet,
               new: afterFontsAreSet + "        let url = \"http://example.com\"; _ = PDFDocument(data: data)?.page(at: 0)?.attributedString\n"),
        Change(name: "the read of the attributed text named in a string",
               old: afterFontsAreSet,
               new: afterFontsAreSet + "        _ = \"attributedString\"\n"),
        Change(name: "no function that finds the sizes",
               old: "private static func fontSizes(of document: PDFDocument)",
               new: "private static func sizesOfFonts(in document: PDFDocument)"),
    ]

    @Test("A comment may name what it explains", arguments: accepted)
    func commentsAreAccepted(change: Change) throws {
        let source = try change.applied(to: Self.model)

        #expect(Self.problems(in: source) == [], "A comment is not code")
    }

    @Test("The model is accepted")
    func modelIsAccepted() {
        #expect(Self.problems(in: Self.model) == [])
    }

    @Test("Code that reads the fonts early is refused, wherever the comments and the strings leave it", arguments: refused)
    func earlyReadsAreRefused(change: Change) throws {
        let source = try change.applied(to: Self.model)

        #expect(!Self.problems(in: source).isEmpty, "\(change.name) goes unseen")
    }
}
