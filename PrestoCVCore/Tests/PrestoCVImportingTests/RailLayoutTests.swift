import Foundation
import Testing
@testable import PrestoCVImporting

/// The layout where each section's heading stands right-aligned in a narrow column on the left and the section's lines
/// beside it, a few points off the heading's right edge (#287). The gap is narrower than the one that tells two cells
/// of a table apart, so the heading and the section's first line were read as one cell and the section had no heading.
/// Every CV here is invented.
@Suite("Reading the headings in a column beside the sections")
struct RailLayoutTests {

    /// Where the headings' column ends and the sections' column starts, in points: a gap of ten between them.
    private static let railEdge = 162.0
    private static let bodyStart = 172.0
    private static let headingSize = 9.5

    private func analyze(_ pages: [ExtractedPage]) throws -> LayoutAnalyzer.Analysis {
        var work = AnalysisWork(budget: ImportLimits.standard.maximumAnalysisSteps)
        return try LayoutAnalyzer.analyze(pages, limits: .standard, work: &work)
    }

    private func importLayout(_ pages: ExtractedPage...) async throws -> ImportResult {
        try await ImportCV(pdfReader: ScriptedPDFReader(layout: .pages(pages)), limits: .standard).importPDF(Data([1]))
    }

    /// A section's heading, bold unless said otherwise, ending at the headings' column's right edge.
    private func put(
        heading: String, y: Double, size: Double = headingSize, bold: Bool = true, edge: Double = railEdge, into sketch: inout PageSketch
    ) {
        let words = heading.split(separator: " ")
        let width = words.reduce(0.0) { $0 + Double($1.count) * size * 0.5 } + Double(words.count - 1) * size * 0.28
        sketch.put(heading, x: edge - width, y: y, size: size, bold: bold)
    }

    /// The job of `titleOfAJob`: a bold title with a gap of ten points between its two words, as a justified line has.
    private func putJob(into sketch: inout PageSketch) {
        sketch.put("Alex Example", x: 46, y: 40, size: 24, bold: true)
        sketch.put("Work Experience", x: 60, y: 100, size: 12, bold: true)
        sketch.put("Education", x: 60, y: 130, bold: true)
        sketch.put("Consultant", x: 60 + 9 * 10 * 0.5 + 10, y: 130, bold: true)
        sketch.put("Example Ltd", x: 60, y: 146)
        sketch.put("2019 – 2024", x: 60, y: 160)
    }

    /// A CV drawn in the layout: the skills (a label and its items on each row) before the experience or after it.
    private func page(
        skillsHeading: String, experienceHeading: String = "Work Experience", skillsFirst: Bool, languages: Bool = true
    ) -> ExtractedPage {
        var sketch = PageSketch()
        sketch.put("Alex Example", x: 46, y: 40, size: 24, bold: true)
        sketch.put("Software Engineer", x: 46, y: 74, size: 12, bold: true)
        sketch.put("alex.example@example.org · Leeds, United Kingdom", x: 46, y: 94, size: 9)
        var y = 130.0
        func skills() {
            put(heading: skillsHeading, y: y, into: &sketch)
            sketch.put("Languages", x: Self.bodyStart, y: y, size: 9.3, bold: true)
            sketch.put("Swift, Kotlin", x: 314, y: y, size: 9.3)
            sketch.put("Frameworks", x: Self.bodyStart, y: y + 24, size: 9.3, bold: true)
            sketch.put("SwiftUI, Combine", x: 314, y: y + 24, size: 9.3)
            sketch.put("Platforms", x: Self.bodyStart, y: y + 48, size: 9.3, bold: true)
            sketch.put("Docker, AWS", x: 314, y: y + 48, size: 9.3)
            y += 90
        }
        func experience() {
            put(heading: experienceHeading, y: y, into: &sketch)
            sketch.put("Software Engineer", x: Self.bodyStart, y: y, size: 11.5, bold: true)
            sketch.put("Example Ltd · Leeds", x: Self.bodyStart, y: y + 18, size: 9.5, bold: true)
            sketch.put("03/2019 – 05/2024", x: Self.bodyStart, y: y + 34, size: 9)
            sketch.put("Built the billing service for retail customers.", x: Self.bodyStart, y: y + 52, size: 9.3)
            y += 90
        }
        if skillsFirst {
            skills()
            experience()
        } else {
            experience()
            skills()
        }
        put(heading: "Education", y: y, into: &sketch)
        sketch.put("BSc Computer Science", x: Self.bodyStart, y: y, size: 9.3, bold: true)
        sketch.put("University of Example · 2012 – 2016", x: Self.bodyStart, y: y + 16, size: 9)
        y += 56
        guard languages else { return sketch.page }
        put(heading: "Languages", y: y, into: &sketch)
        sketch.put("English: C1", x: Self.bodyStart, y: y, size: 9.3, bold: true)
        sketch.put("German: B2", x: Self.bodyStart, y: y + 18, size: 9.3, bold: true)
        return sketch.page
    }

    private func expectWholeCV(_ result: ImportResult, _ label: String) {
        #expect(result.cv.skills.map(\.value) == ["Swift", "Kotlin", "SwiftUI", "Combine", "Docker", "AWS"], "\(label): \(result.cv.skills.map(\.value))")
        #expect(result.cv.experience.map { $0.role?.value } == ["Software Engineer"], "\(label)")
        #expect(result.cv.experience.first?.employer?.value == "Example Ltd", "\(label)")
        #expect(result.cv.education.count == 1, "\(label): \(result.cv.education.count)")
        #expect(result.cv.languages.map(\.name.value) == ["English", "German"], "\(label): \(result.cv.languages.map(\.name.value))")
        #expect(result.unplaced.isEmpty, "\(label): text not imported: \(result.unplaced.map(\.text))")
        #expect(result.ungrounded.isEmpty, "\(label)")
    }

    @Test("A heading and the first line of its section, ten points apart, are two cells")
    func cells() throws {
        var sketch = PageSketch()
        put(heading: "Core Technologies", y: 100, into: &sketch)
        sketch.put("Languages", x: Self.bodyStart, y: 100, size: 9.3, bold: true)
        sketch.put("Swift, Kotlin", x: 314, y: 100, size: 9.3)
        sketch.put("Frameworks", x: Self.bodyStart, y: 116, size: 9.3, bold: true)
        sketch.put("SwiftUI, Combine", x: 314, y: 116, size: 9.3)
        put(heading: "Education", y: 140, into: &sketch)
        sketch.put("BSc Computer Science", x: Self.bodyStart, y: 140, size: 9.3, bold: true)
        sketch.put("University of Example · 2012 – 2016", x: Self.bodyStart, y: 156, size: 9)
        #expect(try analyze([sketch.page]).lines.map(\.text) == [
            "Core Technologies\tLanguages\tSwift, Kotlin", "Frameworks\tSwiftUI, Combine",
            "Education\tBSc Computer Science", "University of Example · 2012 – 2016",
        ])
    }

    @Test("A heading read by its parts is a cell of its own too: a bracketed qualifier, a generic word, alternatives", arguments: [
        "Technical Skills (Hard Skills)", "Education and credentials", "Weiterbildung / Kurse",
    ])
    func headingsByTheirParts(heading: String) throws {
        var sketch = PageSketch()
        put(heading: heading, y: 100, into: &sketch)
        sketch.put("Languages", x: Self.bodyStart, y: 100, size: 9.3, bold: true)
        sketch.put("Swift, Kotlin", x: 314, y: 100, size: 9.3)
        sketch.put("Frameworks", x: Self.bodyStart, y: 116, size: 9.3, bold: true)
        sketch.put("SwiftUI, Combine", x: 314, y: 116, size: 9.3)
        // A row of another section: one of the same section is no evidence of a column
        put(heading: "Languages", y: 140, into: &sketch)
        sketch.put("English: C1", x: Self.bodyStart, y: 140, size: 9.3, bold: true)
        #expect(try analyze([sketch.page]).lines.map(\.text) == [
            "\(heading)\tLanguages\tSwift, Kotlin", "Frameworks\tSwiftUI, Combine", "Languages\tEnglish: C1",
        ])
    }

    @Test("Two headings of different sections, right-aligned in a column with their text at one edge, are a column: no other line is needed")
    func twoHeadingsAlone() throws {
        var sketch = PageSketch()
        put(heading: "Core Technologies", y: 100, into: &sketch)
        sketch.put("Languages", x: Self.bodyStart, y: 100, size: 9.3, bold: true)
        put(heading: "Education", y: 140, into: &sketch)
        sketch.put("BSc Computer Science", x: Self.bodyStart, y: 140, size: 9.3, bold: true)
        #expect(try analyze([sketch.page]).lines.map(\.text) == [
            "Core Technologies\tLanguages", "Education\tBSc Computer Science",
        ])
    }

    @Test("Headings of different sections that start at one margin, their text at one edge, are a table's labels: the lines stay whole")
    func labelsAtOneMargin() throws {
        var sketch = PageSketch()
        sketch.put("Alex Example", x: 46, y: 40, size: 24, bold: true)
        // Two labels of the same width, ten points before their values, and a line at the values' edge
        sketch.put("Languages", x: 60, y: 100, bold: true)
        sketch.put("Swift, Kotlin", x: 115, y: 100)
        sketch.put("Education", x: 60, y: 116, bold: true)
        sketch.put("BSc Computer Science", x: 115, y: 116)
        sketch.put("University of Example", x: 115, y: 132)
        let lines = try analyze([sketch.page]).lines.map(\.text)
        #expect(lines.contains("Languages Swift, Kotlin"), "\(lines)")
        #expect(lines.contains("Education BSc Computer Science"), "\(lines)")
    }

    @Test("A heading whose gap is a cell's vouches for one whose gap is narrower: both are rows of the column")
    func cellGapEvidence() throws {
        var sketch = PageSketch()
        // Fifteen points: narrower than a cell's gap beside a large job title, wider beside small text
        put(heading: "Work Experience", y: 100, into: &sketch)
        sketch.put("Software Engineer", x: Self.railEdge + 15, y: 100, size: 11.5, bold: true)
        put(heading: "Education", y: 140, into: &sketch)
        sketch.put("BSc Computer Science", x: Self.railEdge + 15, y: 140, size: 9)
        #expect(try analyze([sketch.page]).lines.map(\.text) == [
            "Work Experience\tSoftware Engineer", "Education\tBSc Computer Science",
        ])
    }

    @Test("A heading in capitals, or one that is large and not bold, is a cell of its own too")
    func capitalsAndLarge() throws {
        var sketch = PageSketch()
        sketch.put("Alex Example", x: 46, y: 40, size: 9.3)
        put(heading: "CORE TECHNOLOGIES", y: 100, into: &sketch)
        sketch.put("Languages", x: Self.bodyStart, y: 100, size: 9.3, bold: true)
        sketch.put("Frameworks", x: Self.bodyStart, y: 116, size: 9.3, bold: true)
        put(heading: "Education", y: 140, size: 13, bold: false, into: &sketch)
        sketch.put("BSc Computer Science", x: Self.bodyStart, y: 140, size: 9.3, bold: true)
        #expect(try analyze([sketch.page]).lines.map(\.text) == [
            "Alex Example", "CORE TECHNOLOGIES\tLanguages", "Frameworks", "Education\tBSc Computer Science",
        ])
    }

    @Test("Two jobs with the same bold title, a gap at the same place in both, do not vouch for each other's heading", arguments: [false, true])
    func repeatedTitles(linesAtTheEdge: Bool) async throws {
        var sketch = PageSketch()
        sketch.put("Alex Example", x: 46, y: 40, size: 24, bold: true)
        sketch.put("Work Experience", x: 60, y: 100, size: 12, bold: true)
        for (index, job) in [("Example Ltd", "2019 – 2024"), ("Sample GmbH", "2015 – 2019")].enumerated() {
            let y = 130 + Double(index) * 60
            sketch.put("Education", x: 60, y: y, bold: true)
            sketch.put("Consultant", x: 60 + 9 * 10 * 0.5 + 10, y: y, bold: true)
            sketch.put(job.0, x: 60, y: y + 16)
            sketch.put(job.1, x: 60, y: y + 30)
            // An accomplishment indented to where the title's second word starts
            if linesAtTheEdge { sketch.put("Ran workshops for local schools", x: 115, y: y + 44) }
        }
        let lines = try analyze([sketch.page]).lines.map(\.text)
        let whole = lines.count { $0 == "Education Consultant" }
        #expect(whole == 2, "\(lines)")

        let result = try await importLayout(sketch.page)
        #expect(result.cv.education.isEmpty, "\(result.cv.education.count) education entries")
        #expect(result.cv.experience.map { $0.role?.value } == ["Education Consultant", "Education Consultant"])
        #expect(result.cv.experience.map { $0.employer?.value } == ["Example Ltd", "Sample GmbH"])
    }

    @Test("A section of one line on a page of its own has its heading read: the rows of the other pages share its edges")
    func continuationPage() async throws {
        var last = PageSketch()
        put(heading: "Languages", y: 100, into: &last)
        last.put("English: C1", x: Self.bodyStart, y: 100, size: 9.3, bold: true)
        let first = page(skillsHeading: "Core Technologies", skillsFirst: true, languages: false)
        #expect(try analyze([first, last.page]).lines.map(\.text).last == "Languages\tEnglish: C1")

        let result = try await importLayout(first, last.page)
        #expect(result.cv.languages.map(\.name.value) == ["English"], "\(result.cv.languages.map(\.name.value))")
        #expect(result.cv.education.count == 1)
    }

    @Test("A page of another size takes no column from the others: its section of one line keeps its heading in the line")
    func otherPageSize() throws {
        var last = PageSketch()
        put(heading: "Languages", y: 100, into: &last)
        last.put("English: C1", x: Self.bodyStart, y: 100, size: 9.3, bold: true)
        let first = page(skillsHeading: "Core Technologies", skillsFirst: true, languages: false)
        let letter = ExtractedPage(width: 612, height: 792, words: last.words)
        #expect(try analyze([first, letter]).lines.map(\.text).last == "Languages English: C1")
    }

    @Test("A page with a name and one section of one line has its heading read when the next pages hold the column")
    func namePage() async throws {
        var first = PageSketch()
        first.put("Alex Example", x: 46, y: 40, size: 24, bold: true)
        first.put("alex.example@example.org · Leeds, United Kingdom", x: 46, y: 74, size: 9)
        put(heading: "Core Technologies", y: 110, into: &first)
        first.put("Languages", x: Self.bodyStart, y: 110, size: 9.3, bold: true)
        first.put("Swift, Kotlin", x: 314, y: 110, size: 9.3)
        var next = PageSketch()
        put(heading: "Work Experience", y: 100, into: &next)
        next.put("Software Engineer", x: Self.bodyStart, y: 100, size: 11.5, bold: true)
        next.put("Example Ltd · Leeds", x: Self.bodyStart, y: 118, size: 9.5, bold: true)
        next.put("03/2019 – 05/2024", x: Self.bodyStart, y: 134, size: 9)
        next.put("Built the billing service for retail customers.", x: Self.bodyStart, y: 152, size: 9.3)

        let result = try await importLayout(first.page, next.page)
        #expect(result.cv.skills.map(\.value) == ["Swift", "Kotlin"], "\(result.cv.skills.map(\.value))")
        #expect(result.cv.experience.map { $0.role?.value } == ["Software Engineer"])
    }

    @Test("A section whose lines are all list items has its heading read when its first item's mark starts at the column's edge")
    func listSection() throws {
        var sketch = PageSketch()
        sketch.put("Alex Example", x: 46, y: 40, size: 24, bold: true)
        put(heading: "Skills", y: 100, into: &sketch)
        for (index, item) in ["Swift and Kotlin", "SwiftUI and Combine", "Docker and AWS"].enumerated() {
            sketch.put("•", x: Self.bodyStart, y: 100 + Double(index) * 16, size: 9.3)
            sketch.put(item, x: Self.bodyStart + 8, y: 100 + Double(index) * 16, size: 9.3)
        }
        put(heading: "Education", y: 160, into: &sketch)
        sketch.put("BSc Computer Science", x: Self.bodyStart, y: 160, size: 9.3, bold: true)
        let lines = try analyze([sketch.page]).lines.map(\.text)
        #expect(lines.contains("Skills\t• Swift and Kotlin"), "\(lines)")
        #expect(lines.contains("Education\tBSc Computer Science"), "\(lines)")
    }

    @Test("A line that only starts with the word of a heading is one cell, whatever the gap after it")
    func notAHeading() throws {
        var sketch = PageSketch()
        // Regular weight: a heading is bold or large
        put(heading: "Education", y: 100, into: &sketch)
        sketch.put("Education", x: 60, y: 120, size: 9.5)
        sketch.put("BSc Computer Science", x: 60 + 9 * 9.5 * 0.5 + 10, y: 120, size: 9.5)
        // Bold, but the words before the gap are not a heading
        sketch.put("Education tools", x: 60, y: 140, size: 9.5, bold: true)
        sketch.put("for retail", x: 60 + 15 * 9.5 * 0.5 + 10, y: 140, size: 9.5, bold: true)
        let lines = try analyze([sketch.page]).lines.map(\.text)
        #expect(lines.contains("Education BSc Computer Science"), "\(lines)")
        #expect(lines.contains("Education tools for retail"), "\(lines)")
    }

    @Test("A bold title that starts with the word of a heading stays whole when no row of another section shares its edges")
    func titleOfAJob() async throws {
        var sketch = PageSketch()
        putJob(into: &sketch)
        #expect(try analyze([sketch.page]).lines.map(\.text).contains("Education Consultant"))

        let result = try await importLayout(sketch.page)
        #expect(result.cv.education.isEmpty, "\(result.cv.education.count) education entries")
        #expect(result.cv.experience.map { $0.role?.value } == ["Education Consultant"])
        #expect(result.cv.experience.first?.employer?.value == "Example Ltd")
    }

    @Test("A line that starts where a bold title's second word does, on its page or another, does not make the title a heading", arguments: [false, true])
    func unrelatedLine(onTheSamePage: Bool) async throws {
        var sketch = PageSketch()
        putJob(into: &sketch)
        var next = PageSketch()
        next.put("Project Manager", x: 60, y: 100, bold: true)
        next.put("Sample GmbH", x: 60, y: 116)
        next.put("2015 – 2019", x: 60, y: 130)
        // An accomplishment indented to where the title's second word starts
        if onTheSamePage {
            sketch.put("Ran workshops for local schools", x: 115, y: 174)
        } else {
            next.put("Ran workshops for local schools", x: 115, y: 144)
        }
        #expect(try analyze([sketch.page, next.page]).lines.map(\.text).contains("Education Consultant"))

        let result = try await importLayout(sketch.page, next.page)
        #expect(result.cv.education.isEmpty, "\(result.cv.education.count) education entries")
        #expect(result.cv.experience.first?.role?.value == "Education Consultant", "\(result.cv.experience.map { $0.role?.value })")
        #expect(result.cv.experience.first?.employer?.value == "Example Ltd")
    }

    @Test("A skills table whose longest label is the word of a heading keeps that row whole")
    func tableLabel() async throws {
        var sketch = PageSketch()
        sketch.put("Alex Example", x: 46, y: 40, size: 24, bold: true)
        sketch.put("Skills", x: 46, y: 100, size: 12, bold: true)
        // The values start at x = 115: ten points past the longest label, and where no line of text starts
        let rows = [("Languages", "Swift, Kotlin"), ("Tools", "Docker, AWS"), ("Methods", "Agile, TDD")]
        for (index, row) in rows.enumerated() {
            sketch.put(row.0, x: 60, y: 124 + Double(index) * 16, bold: true)
            sketch.put(row.1, x: 115, y: 124 + Double(index) * 16)
        }
        let lines = try analyze([sketch.page]).lines.map(\.text)
        #expect(lines.contains("Languages Swift, Kotlin"), "\(lines)")

        let result = try await importLayout(sketch.page)
        #expect(result.cv.languages.isEmpty, "\(result.cv.languages.map(\.name.value))")
        #expect(Set(result.cv.skills.map(\.value)).isSuperset(of: ["Kotlin", "Docker", "AWS", "Agile", "TDD"]), "\(result.cv.skills.map(\.value))")
    }

    @Test("The headings end at one edge, and the text of the sections starts at another, to within the ink of their first letters")
    func inkOffsets() throws {
        var sketch = PageSketch()
        let offsets: [(heading: Double, text: Double)] = [(0, 0), (0.8, 1.2), (-1.3, -1.1), (0.6, -2), (2, 5)]
        for (index, offset) in offsets.enumerated() {
            let y = 100 + Double(index) * 40
            put(heading: index.isMultiple(of: 2) ? "Core Technologies" : "Education", y: y, edge: Self.railEdge + offset.heading, into: &sketch)
            sketch.put("Languages", x: Self.bodyStart + offset.text, y: y, size: 9.3, bold: true)
        }
        // The last text starts more than three points past the text of every heading of another section, its gap still
        // narrower than a cell's: it is no column's
        #expect(try analyze([sketch.page]).lines.map(\.text) == [
            "Core Technologies\tLanguages", "Education\tLanguages", "Core Technologies\tLanguages", "Education\tLanguages",
            "Core Technologies Languages",
        ])
    }

    @Test("A line of bold headings' words, many times over, is analysed within the budget of a sort: wide gaps, then narrow", arguments: [45.0, 50.0])
    func hostileHeadingGaps(wordWidth: Double) throws {
        var words: [ExtractedWord] = []
        for line in 0..<1_000 {
            for column in 0..<10 {
                // Every other line is the heading of another section, starting elsewhere and ending at the same edge
                let text = line.isMultiple(of: 2) ? "Education" : "Skills"
                let start = column > 0 || line.isMultiple(of: 2) ? 20.0 : 10.0
                words.append(ExtractedWord(
                    text: text, frame: Rect(x: start + Double(column) * 55, y: Double(line) * 0.8, width: wordWidth + 20 - start, height: 0.6),
                    fontSize: 0.5, isBold: true
                ))
            }
        }
        let page = ExtractedPage(width: 595, height: 842, words: words)
        let limits = ImportLimits(
            maximumPDFBytes: 1_000_000, maximumPages: 10, maximumCharacters: 1_000_000,
            maximumWords: 20_000, maximumLines: 2_000, maximumCells: 20_000,
            maximumAnalysisSteps: 16 * AnalysisWork.sortSteps(words.count)
        )
        var work = AnalysisWork(budget: limits.maximumAnalysisSteps)
        _ = try LayoutAnalyzer.analyze([page], limits: limits, work: &work)
    }

    /// A seeded stream of numbers in 0..<1, the same on every run.
    private struct Dice {
        var state: UInt64

        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
    }

    @Test("The sweep splits the rows the rule names: a row of another section at both edges, its heading starting elsewhere", arguments: [
        UInt64(1), 2, 3, 4,
    ])
    func sweepFollowsTheRule(seed: UInt64) throws {
        struct Drawn {
            let page: Int, line: Int, section: SectionKind
            let start: Double, end: Double, text: Double
            let isCandidate: Bool
        }
        var dice = Dice(state: seed)
        let headings = ["Education", "Skills", "Languages", "Experience", "Interests"]
        // Two pages of one size and one of another
        let pages = [(595.0, 842.0), (595, 842), (612, 792)].map { ExtractedPage(width: $0.0, height: $0.1, words: []) }
        var drawn: [Drawn] = []
        var lines: [[[ExtractedWord]]] = []
        for page in pages.indices {
            var pageLines: [[ExtractedWord]] = []
            for line in 0..<40 {
                let y = Double(line) * 14
                let end = 100 + dice.next() * 40
                let heading = headings[min(Int(dice.next() * 5), 4)]
                let width = Double(heading.count) * 5
                let isCandidate = dice.next() < 0.7
                // Narrower than a cell's gap, or wider
                let gap = isCandidate ? 7.5 + dice.next() * 7 : 16 + dice.next() * 4
                let isRow = dice.next() < 0.9
                pageLines.append([
                    ExtractedWord(text: isRow ? heading : "Ran", frame: Rect(x: end - width, y: y, width: width, height: 10), fontSize: 10, isBold: true),
                    ExtractedWord(text: "text", frame: Rect(x: end + gap, y: y, width: 20, height: 10), fontSize: 10, isBold: false),
                ])
                guard isRow else { continue }
                let section = try #require(SectionVocabulary.kind(ofHeading: heading)?.kind)
                drawn.append(Drawn(
                    page: page, line: line, section: section, start: end - width, end: end, text: end + gap, isCandidate: isCandidate
                ))
            }
            lines.append(pageLines)
        }
        var work = AnalysisWork(budget: ImportLimits.standard.maximumAnalysisSteps)
        let rails = try LayoutAnalyzer.HeadingRails(lines: lines, of: pages, bodySize: 10, work: &work)

        var split = 0
        var whole = 0
        for row in drawn {
            let vouched = row.isCandidate && drawn.contains { other in
                pages[other.page].width == pages[row.page].width && pages[other.page].height == pages[row.page].height
                    && other.section != row.section && abs(other.end - row.end) <= 3 && abs(other.text - row.text) <= 3
                    && abs(other.start - row.start) > 3
            }
            #expect(rails.headingEnds[row.page][row.line] == (vouched ? 1 : nil), "page \(row.page), line \(row.line)")
            if row.isCandidate { if vouched { split += 1 } else { whole += 1 } }
        }
        let rowLines = Set(drawn.map { [$0.page, $0.line] })
        for page in pages.indices {
            for line in 0..<40 where !rowLines.contains([page, line]) { #expect(rails.headingEnds[page][line] == nil) }
        }
        // Both answers are drawn, so the check is not a trivial one
        #expect(split > 0, "\(split) split")
        #expect(whole > 0, "\(whole) whole")
    }

    @Test("A CV with its headings in a column beside the sections has every section read", arguments: [true, false])
    func wholeCV(skillsFirst: Bool) async throws {
        expectWholeCV(try await importLayout(page(skillsHeading: "Core Technologies", skillsFirst: skillsFirst)), "skills first: \(skillsFirst)")
    }

    @Test("Every heading of the skills, in a column beside the sections, has the skills read", arguments: SkillsHeadings.all)
    func everySkillsHeading(language: CVLanguage, heading: String) async throws {
        let experience = try #require(SkillsHeadings.experience[language])
        for skillsFirst in [true, false] {
            let result = try await importLayout(page(skillsHeading: heading, experienceHeading: experience, skillsFirst: skillsFirst))
            expectWholeCV(result, "\(language) \(heading) skills first: \(skillsFirst)")
        }
    }
}
