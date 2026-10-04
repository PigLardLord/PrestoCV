import Testing
import Foundation
import CVDesignCatalog
@testable import CVRendering

/// markup-contract.md is normative (ADR 0011, ADR 0019): these tests read the letter's section and hold the code to it, as
/// `MarkupContractPageTests` does for the CV's. The letter's headings differ from the CV's `### Structure` and
/// `### Selectable by a design`, which that suite finds by name.
@Suite("markup-contract.md matches the letter's code (#187)")
struct LetterMarkupPageTests {
    @Test("the letter's tree uses exactly the letter's classes and elements")
    func tree() throws {
        let tree = try LetterPage.section(from: "### The letter's tree", to: "**The page writes")
        #expect(Set(LetterPage.matches(#"\.(letter[a-z-]*)"#, in: tree)) == LetterMarkup.classes)
        let elements = Set(LetterPage.matches(#"(?:^|[\s>─])([a-z][a-z0-9]*)(?=[.\[])"#, in: tree)).subtracting(["html"])
        #expect(elements == LetterMarkup.elements)
    }

    @Test("what the letter's stylesheet may select is the letter's vocabulary: elements and classes, no attribute selector, no pseudo-class")
    func selectable() throws {
        let rows = try LetterPage.table(after: "### Selectable by the letter's stylesheet")
        func values(_ kind: String) throws -> Set<String> { Set(LetterPage.backticked(try #require(rows[kind], "no row \(kind)"))) }
        #expect(try values("Elements") == LetterMarkup.vocabulary.elements)
        #expect(try values("Classes") == LetterMarkup.vocabulary.classes)
        #expect(rows["Attribute selectors"] == "none" && LetterMarkup.vocabulary.sectionKinds.isEmpty && LetterMarkup.vocabulary.ratings.isEmpty)
        #expect(rows["Pseudo-classes"] == "none" && LetterMarkup.vocabulary.pseudoClasses.isEmpty)
        #expect(Set(rows.keys) == ["Elements", "Classes", "Attribute selectors", "Pseudo-classes"])
    }

    @Test("the letter's fixed colours and fonts are the stylesheet's")
    func fixedValues() throws {
        let rows = try LetterPage.table(after: "### The letter's fixed values")
        let colours = LetterPage.backticked(try #require(rows["Colours"]))
        #expect(colours.filter { $0.hasPrefix("#") } == [LetterStyle.text, LetterStyle.primary, LetterStyle.background])
        #expect(colours.filter { $0.hasPrefix("--") } == ["--color-text", "--color-primary", "--color-background"])
        #expect(LetterPage.backticked(try #require(rows["Fonts"])).first == LetterStyle.fonts)
        for property in colours.filter({ $0.hasPrefix("--") }) { #expect(LetterStyle.customProperties.contains("\(property):")) }
    }

    @Test("the letter's page is the export's: A4, one page, and the margins every page keeps")
    func page() throws {
        let rows = try LetterPage.table(after: "### The letter's page")
        let paper = LetterPage.backticked(try #require(rows["Paper"])).compactMap(Double.init)
        #expect(paper == [LetterPDFExport.page.widthPoints, LetterPDFExport.page.heightPoints])
        #expect(LetterPage.backticked(try #require(rows["Pages"])).compactMap(Int.init) == [LetterPDFExport.page.maxPages])
        #expect(LetterPage.backticked(try #require(rows["Free at the top and at the bottom of the page"])).compactMap(Double.init) == [LetterPDFExport.page.verticalMarginPoints])
        #expect(Set(rows.keys) == ["Paper", "Pages", "Free at the top and at the bottom of the page"])
    }

    @Test("the golden files that the page names exist, and the page names every golden file of the letter")
    func goldenFiles() throws {
        let section = try LetterPage.section(from: "## The cover letter's structure", to: "### The letter's tree")
        let named = Set(LetterPage.matches(#"`(letter-[a-z-]+\.html)`"#, in: section))
        let directory = LetterPage.root.appendingPathComponent("CVPDFExporter/Tests/CVRenderingTests/Golden")
        let present = Set(try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix("letter-") })
        #expect(named == present && !named.isEmpty)
    }

    @Test("the CV's two headings occur once, before the letter's section, so the CV's test keeps reading the CV's tables")
    func cvHeadingsUnaffected() throws {
        let page = try LetterPage.text()
        let letter = try #require(page.range(of: "## The cover letter's structure"))
        for heading in ["### Structure", "### Selectable by a design", "**Declarations.**", "**Inline text"] {
            let ranges = page.ranges(of: heading)
            #expect(ranges.count == 1 && ranges[0].upperBound < letter.lowerBound, "\(heading)")
        }
        let letterSection = String(page[letter.lowerBound...])
        #expect(!letterSection.contains("### Structure") && !letterSection.contains("### Selectable by a design"))
    }
}

// MARK: - Reading the page

enum LetterPage {
    struct PageError: Error, CustomStringConvertible { let description: String }

    /// The repository's root: this file is CVPDFExporter/Tests/CVRenderingTests/….
    static var root: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        return root
    }

    static func text() throws -> String {
        try String(contentsOf: root.appendingPathComponent("docs/architecture/markup-contract.md"), encoding: .utf8)
    }

    static func section(from start: String, to end: String) throws -> String {
        let page = try text()
        guard let a = page.range(of: start), let b = page.range(of: end, range: a.upperBound..<page.endIndex) else {
            throw PageError(description: "no section from \(start) to \(end)")
        }
        return String(page[a.upperBound..<b.lowerBound])
    }

    /// The first table after `heading`, as its first column → second column.
    static func table(after heading: String) throws -> [String: String] {
        let page = try text()
        guard let start = page.range(of: heading) else { throw PageError(description: "no heading \(heading)") }
        let lines = page[start.upperBound...].components(separatedBy: "\n").drop { !$0.hasPrefix("|") }.prefix { $0.hasPrefix("|") }
        let rows = try lines.dropFirst(2).map { line -> [String] in
            let cells = line.split(separator: "|", omittingEmptySubsequences: false).dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }
            guard cells.count == 2 else { throw PageError(description: "a row without exactly two cells: \(line)") }
            return cells
        }
        return Dictionary(rows.map { ($0[0], $0[1]) }, uniquingKeysWith: { first, _ in first })
    }

    static func backticked(_ text: String) -> [String] { matches("`([^`]+)`", in: text) }

    /// The first capture group of every match.
    static func matches(_ pattern: String, in text: String) -> [String] {
        let regex: NSRegularExpression
        do { regex = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) } catch { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
    }
}
