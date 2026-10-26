import Testing
import Foundation

// MARK: - What reading a PDF back costs in the tests

/// The suites that print PDFs with the real renderer read each PDF back with PDFKit (`PDFLayout`), and the attributed text
/// of a page is by far the dearest read, and the only dear one: PDFKit looks up each embedded font by name, fails, and logs a
/// note for every run of text. Read for every PDF, it took about a quarter of the time of the suites and left about a million
/// notes, a third of a gigabyte of log, in each run. Only the tests that compare the sizes of the fonts need them, so the
/// layout reads them on the first ask and keeps them (`Fonts`). These checks keep it that way: the cost would come back
/// with one new `attributedString`, or with a read of the sizes in the init of the layout or in the init of `Fonts`, or in a
/// helper of another test file that an init calls.
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

    /// A call of the function that reads the fonts of a document: its name and `of`, with a line break allowed between them
    private static let readerCall = try! NSRegularExpression(pattern: #"\bfontSizes\s*\(\s*of\b"#)

    /// The name of the property, and of the functions, that find, ask for and compare the sizes of the fonts
    private static let fontSizesName = try! NSRegularExpression(pattern: #"\bfontSizes\b"#)

    /// The name of the sizes that `Fonts` keeps, and of the set that the reader fills
    private static let sizesName = try! NSRegularExpression(pattern: #"\bsizes\b"#)

    /// What is wrong in the source of `PDFLayout`: where the reading of the fonts is outside the code that is made for it.
    ///
    /// The reading is lazy when four members are the only code that names it, and the rest of the file, the init of the
    /// layout and the init of `Fonts` among it, names none of it:
    /// - `static func fontSizes(of:)` reads the attributed text of the pages and finds the sizes;
    /// - the `sizes` of `Fonts` is the only call of it, and keeps the result;
    /// - `var fontSizes` of the layout asks `Fonts`;
    /// - `func fontSizes(matching:)` compares the sizes of two layouts.
    ///
    /// The members are the only ranges that allow a name, so a member that is not found, or found shorter than it is, makes a
    /// problem rather than a gap.
    static func problems(in source: String) -> [String] {
        let code = SwiftCode(source)
        guard let property = code.member(startingWith: "var fontSizes:"),
              let comparison = code.member(startingWith: "func fontSizes(matching "),
              let reader = code.member(startingWith: "static func fontSizes(of "),
              let holder = code.member(startingWith: "final class Fonts"),
              let lazyRead = code.member(startingWith: "var sizes:", within: holder) else {
            return ["PDFLayout has var fontSizes:, func fontSizes(matching:), static func fontSizes(of:) and a class Fonts with a var sizes; if one moved, update this check"]
        }

        let rules: [(word: String, pattern: NSRegularExpression, allowed: [Range<Int>], allowedNames: String)] = [
            ("the attributed text", attributedText, [reader], "fontSizes(of:)"),
            ("a call of fontSizes(of:)", readerCall, [reader, lazyRead], "the sizes of Fonts"),
            ("fontSizes", fontSizesName, [property, comparison, reader, lazyRead], "fontSizes, fontSizes(of:), fontSizes(matching:) and the sizes of Fonts"),
            ("sizes", sizesName, [property, reader, lazyRead], "fontSizes, fontSizes(of:) and the sizes of Fonts"),
        ]
        var problems: [String] = []
        for rule in rules {
            let lines = code.lines(matching: rule.pattern)
            let outside = lines.filter { line in !rule.allowed.contains { $0.contains(line) } }
            if !outside.isEmpty {
                problems.append("Lines \(outside.map { $0 + 1 }) name \(rule.word) outside \(rule.allowedNames), where the fonts may be read for every PDF")
            }
            if lines.isEmpty {
                problems.append("The check finds no \(rule.word) in the source")
            }
        }
        if !code.lines(matching: readerCall).contains(where: lazyRead.contains) {
            problems.append("The sizes of Fonts do not call fontSizes(of:), the one reader of the fonts")
        }
        return problems
    }

    /// The tests that ask a layout for the sizes of its fonts, and the member of each where it does: the one that compares
    /// what the printed PDF is set in with what the design says
    private static let askers: [(path: String, member: String)] = [
        ("PrestoCVTests/Features/Export/OnePagePDFTests.swift", "func expectReadable("),
    ]

    /// What is wrong in the sources of the app's tests, the layout aside: where they name `fontSizes`.
    ///
    /// The name is the only way to the fonts from another file: the `Fonts` holder, the reader and the memo of the layout
    /// are private. An init can call anything, in any file, so a helper that names it, an extension of the layout or a
    /// function of its own, would read the fonts every time a layout is made and the layout would look as lazy as before.
    /// A test asks for the sizes in the member of `askers` and nowhere else; a member that is not found, or that no longer
    /// asks, is a problem, so that the list cannot go stale.
    static func problems(inTests files: [RepositorySources.File]) -> [String] {
        var problems: [String] = []
        for file in files where file.path != layoutPath {
            let code = SwiftCode(file.text)
            let member = askers.first { $0.path == file.path }.flatMap { code.member(startingWith: $0.member) }
            let outside = code.lines(matching: fontSizesName).filter { line in !(member?.contains(line) ?? false) }
            if !outside.isEmpty {
                problems.append("\(file.path): lines \(outside.map { $0 + 1 }) name fontSizes, which only \(askers.map(\.member)) may, so that making a layout reads no fonts")
            }
        }
        for asker in askers {
            let code = files.first { $0.path == asker.path }.map { SwiftCode($0.text) }
            guard let member = code?.member(startingWith: asker.member) else {
                problems.append("\(asker.path) has no \(asker.member); if it moved or was renamed, update this check")
                continue
            }
            if !(code?.lines(matching: fontSizesName).contains(where: member.contains) ?? false) {
                problems.append("\(asker.member) in \(asker.path) no longer asks for the sizes of the fonts: take it out of the list of this check")
            }
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

    @Test("No other test source names the sizes of the fonts than the one that compares them: no helper asks for them when a layout is made")
    func onlyTheComparisonAsksForTheFontSizes() throws {
        let files = try RepositorySources.swiftFiles(in: "PrestoCVTests")
        let problems = Self.problems(inTests: files)

        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }

    @Test("PDFLayout names the reading of the fonts only in the code that finds, keeps, asks for and compares their sizes: creating a layout reads none")
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
    private static let initOfFonts = "        init(pdf: Data) { self.pdf = pdf }\n"
    private static let beforeComparison = "    func fontSizes(matching other: PDFLayout) -> Bool {\n"
    private static let readInInit = "        _ = PDFDocument(data: data)?.page(at: 0)?.attributedString\n"
    private static let signature = "    init?(pdf url: URL, margins: Int) {\n"
    private static let guardOfInit = "        guard let data = try? Data(contentsOf: url) else { return nil }\n"

    static let accepted = [
        Change(name: "a line comment naming the read in the init",
               old: afterFontsAreSet,
               new: "        self.fonts = Fonts(pdf: data) // not attributedString, not fontSizes\n"),
        Change(name: "a doc comment naming the read in the init",
               old: signature,
               new: "    /// Reads no attributedString and asks for no fontSizes\n" + signature),
        Change(name: "a block comment naming the read in the init",
               old: afterFontsAreSet,
               new: "        /* attributedString\n           fontSizes */\n" + afterFontsAreSet),
        Change(name: "a comment naming the sizes in the init of Fonts",
               old: initOfFonts,
               new: initOfFonts + "        // the sizes are found in fontSizes(of:), when fonts.sizes is asked for\n"),
        Change(name: "a comment naming the read in another member",
               old: beforeComparison,
               new: "    /// attributedString is dear\n" + beforeComparison),
        Change(name: "an init whose signature runs over two lines",
               old: signature,
               new: "    init?(pdf url: URL,\n          margins: Int) {\n"),
    ]

    static let refused = [
        // The attributed text
        Change(name: "the read of the attributed text in the init",
               old: afterFontsAreSet,
               new: afterFontsAreSet + readInInit),
        Change(name: "the read of the attributed text in another member",
               old: beforeComparison,
               new: "    func warm(_ document: PDFDocument) { _ = document.page(at: 0)?.attributedString }\n" + beforeComparison),
        Change(name: "the read of the attributed text in the init of Fonts",
               old: initOfFonts,
               new: "        init(pdf: Data) {\n            self.pdf = pdf\n            _ = PDFDocument(data: pdf)?.page(at: 0)?.attributedString\n        }\n"),
        // The sizes, asked for or found when the layout is made
        Change(name: "the sizes asked for in the init",
               old: afterFontsAreSet,
               new: afterFontsAreSet + "        _ = fontSizes\n"),
        Change(name: "the sizes of Fonts asked for in the init",
               old: afterFontsAreSet,
               new: afterFontsAreSet + "        _ = fonts.sizes\n"),
        Change(name: "the sizes of Fonts asked for in the init, on a line of their own",
               old: afterFontsAreSet,
               new: afterFontsAreSet + "        _ = self.fonts\n            .sizes\n"),
        Change(name: "the sizes asked for in the init through a key path",
               old: afterFontsAreSet,
               new: afterFontsAreSet + "        _ = self[keyPath: \\.fontSizes]\n"),
        Change(name: "the sizes found in the init",
               old: afterFontsAreSet,
               new: afterFontsAreSet + "        _ = Self.fontSizes(of: PDFDocument(data: data)!)\n"),
        Change(name: "the sizes found in the init, with the call cut after its parenthesis",
               old: afterFontsAreSet,
               new: afterFontsAreSet + "        _ = Self.fontSizes(\n            of: PDFDocument(data: data)!)\n"),
        Change(name: "the sizes asked for in the init whose signature runs over two lines",
               old: signature + guardOfInit,
               new: "    init?(pdf url: URL,\n          margins: Int) {\n" + guardOfInit + "        _ = PDFDocument(data: Data())?.page(at: 0)?.attributedString\n"),
        Change(name: "the sizes found in the init of Fonts",
               old: initOfFonts,
               new: "        init(pdf: Data) {\n            self.pdf = pdf\n            _ = PDFLayout.fontSizes(of: PDFDocument(data: pdf)!)\n        }\n"),
        Change(name: "the sizes found by a stored property",
               old: "    private let fonts: Fonts\n",
               new: "    private let fonts: Fonts\n    private let eager = PDFLayout.fontSizes(of: PDFDocument())\n"),
        Change(name: "the sizes asked for by another member",
               old: beforeComparison,
               new: "    func warm() { _ = fonts.sizes }\n" + beforeComparison),
        Change(name: "the sizes found by the property on every ask",
               old: "    var fontSizes: Set<Double> { fonts.sizes }\n",
               new: "    var fontSizes: Set<Double> { PDFLayout.fontSizes(of: PDFDocument()!) }\n"),
        Change(name: "the sizes of Fonts not found by calling the reader",
               old: "found = PDFLayout.fontSizes(of: document)",
               new: "found = []"),
        // Code that a comment or a string must not hide, and a check that must not go blind
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
        Change(name: "no class that keeps the sizes",
               old: "private final class Fonts: Sendable {",
               new: "private final class FontHolder: Sendable {"),
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

    @Test("Code that reads the fonts when a layout is made, or reads them outside the code made for it, is refused", arguments: refused)
    func earlyReadsAreRefused(change: Change) throws {
        let source = try change.applied(to: Self.model)

        #expect(!Self.problems(in: source).isEmpty, "\(change.name) goes unseen")
    }

    // MARK: - The check of the tests' sources itself

    /// The sources of a few tests, as the check reads them
    struct Tree: CustomTestStringConvertible, Sendable {
        let name: String
        let files: [RepositorySources.File]
        var testDescription: String { name }
    }

    private static let askerPath = "PrestoCVTests/Features/Export/OnePagePDFTests.swift"

    /// The tests that compare the sizes, small enough to change one thing in
    private static let asker = """
        struct OnePagePDFTests {
            func other(_ layout: PDFLayout) {
                _ = layout.pageCount
            }

            private func expectReadable(_ printed: PDFLayout, comparedTo own: PDFLayout) {
                #expect(!printed.fontSizes.isEmpty)
                #expect(printed.fontSizes(matching: own), "became \\(printed.fontSizes.sorted())")
            }
        }
        """

    private static func tree(_ name: String, asker: String = asker, adding extra: [(path: String, text: String)] = []) -> Tree {
        Tree(name: name, files: ([(askerPath, asker)] + extra).map { RepositorySources.File(path: $0.0, text: $0.1) })
    }

    static let acceptedTrees = [
        tree("the tests that compare the sizes, and a test that does not"),
        tree("a comment naming the sizes in another file", adding: [("PrestoCVTests/TestSupport/Other.swift", "// the layout asks fontSizes on demand\nstruct Other {}")]),
        tree("the layout itself, which has its own check", adding: [(layoutPath, "var fontSizes: Set<Double> { fonts.sizes }")]),
    ]

    static let refusedTrees = [
        tree("an extension of the layout in another file that asks for the sizes",
             adding: [("PrestoCVTests/TestSupport/Warm.swift", "extension PDFLayout {\n    func warm() { _ = fontSizes }\n}")]),
        tree("a function in another file that asks a layout for its sizes",
             adding: [("PrestoCVTests/TestSupport/Touch.swift", "func touch(_ layout: PDFLayout) { _ = layout.fontSizes }")]),
        tree("a key path to the sizes in another file",
             adding: [("PrestoCVTests/TestSupport/Path.swift", "let sizes = \\PDFLayout.fontSizes")]),
        tree("a comparison of the sizes in another file",
             adding: [("PrestoCVTests/TestSupport/Same.swift", "func same(_ a: PDFLayout, _ b: PDFLayout) -> Bool { a.fontSizes(matching: b) }")]),
        tree("the sizes asked for by another member of the tests that compare them",
             asker: asker.replacing("_ = layout.pageCount", with: "_ = layout.fontSizes")),
        tree("the tests that compare the sizes no longer ask for them",
             asker: asker.replacing("#expect(!printed.fontSizes.isEmpty)", with: "#expect(printed.pageCount > 0)")
                         .replacing("#expect(printed.fontSizes(matching: own), \"became \\(printed.fontSizes.sorted())\")", with: "#expect(printed.pageCount == own.pageCount)")),
        tree("the member that compares the sizes was renamed",
             asker: asker.replacing("func expectReadable(", with: "func expectLegible(")),
        Tree(name: "the file of the tests that compare the sizes is gone",
             files: [RepositorySources.File(path: "PrestoCVTests/TestSupport/Other.swift", text: "struct Other {}")]),
    ]

    @Test("Only the member that compares the sizes of the fonts may name them in the tests' sources", arguments: acceptedTrees)
    func comparisonsAreAccepted(tree: Tree) {
        #expect(Self.problems(inTests: tree.files) == [])
    }

    @Test("A helper that names the sizes of the fonts in any other place is refused: it could ask for them when a layout is made", arguments: refusedTrees)
    func helpersAreRefused(tree: Tree) {
        #expect(!Self.problems(inTests: tree.files).isEmpty, "\(tree.name) goes unseen")
    }
}
