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

    private func importLayout(_ page: ExtractedPage) async throws -> ImportResult {
        try await ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([page])), limits: .standard).importPDF(Data([1]))
    }

    /// A section's heading, bold unless said otherwise, ending at the headings' column's right edge.
    private func put(heading: String, y: Double, size: Double = headingSize, bold: Bool = true, into sketch: inout PageSketch) {
        let words = heading.split(separator: " ")
        let width = words.reduce(0.0) { $0 + Double($1.count) * size * 0.5 } + Double(words.count - 1) * size * 0.28
        sketch.put(heading, x: Self.railEdge - width, y: y, size: size, bold: bold)
    }

    /// A CV drawn in the layout: the skills (a label and its items on each row) before the experience or after it.
    private func page(skillsHeading: String, experienceHeading: String = "Work Experience", skillsFirst: Bool) -> ExtractedPage {
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
        put(heading: "Education", y: 140, into: &sketch)
        sketch.put("BSc Computer Science", x: Self.bodyStart, y: 140, size: 9.3, bold: true)
        #expect(try analyze([sketch.page]).lines.map(\.text) == [
            "Core Technologies\tLanguages\tSwift, Kotlin", "Education\tBSc Computer Science",
        ])
    }

    @Test("A heading in capitals, or one that is large and not bold, is a cell of its own too")
    func capitalsAndLarge() throws {
        var sketch = PageSketch()
        sketch.put("Alex Example", x: 46, y: 40, size: 9.3)
        put(heading: "CORE TECHNOLOGIES", y: 100, into: &sketch)
        sketch.put("Languages", x: Self.bodyStart, y: 100, size: 9.3, bold: true)
        put(heading: "Education", y: 140, size: 13, bold: false, into: &sketch)
        sketch.put("BSc Computer Science", x: Self.bodyStart, y: 140, size: 9.3, bold: true)
        #expect(try analyze([sketch.page]).lines.map(\.text) == [
            "Alex Example", "CORE TECHNOLOGIES\tLanguages", "Education\tBSc Computer Science",
        ])
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

    @Test("A bold title that starts with the word of a heading stays whole when no section's text starts after it")
    func titleOfAJob() async throws {
        var sketch = PageSketch()
        sketch.put("Alex Example", x: 46, y: 40, size: 24, bold: true)
        sketch.put("Work Experience", x: 60, y: 100, size: 12, bold: true)
        // A gap of ten points between the two words of the title, as a justified bold line has
        sketch.put("Education", x: 60, y: 130, bold: true)
        sketch.put("Consultant", x: 60 + 9 * 10 * 0.5 + 10, y: 130, bold: true)
        sketch.put("Example Ltd", x: 60, y: 146)
        sketch.put("2019 – 2024", x: 60, y: 160)
        #expect(try analyze([sketch.page]).lines.map(\.text).contains("Education Consultant"))

        let result = try await importLayout(sketch.page)
        #expect(result.cv.education.isEmpty, "\(result.cv.education.count) education entries")
        #expect(result.cv.experience.map { $0.role?.value } == ["Education Consultant"])
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

    @Test("The text of the sections starts at one edge to within the ink of its first letters")
    func inkOffsets() throws {
        var sketch = PageSketch()
        for (index, offset) in [0.0, 1.2, -1.1, 2.4].enumerated() {
            let y = 100 + Double(index) * 40
            put(heading: index.isMultiple(of: 2) ? "Core Technologies" : "Education", y: y, into: &sketch)
            sketch.put("Languages", x: Self.bodyStart + offset, y: y, size: 9.3, bold: true)
        }
        #expect(try analyze([sketch.page]).lines.map(\.text) == [
            "Core Technologies\tLanguages", "Education\tLanguages", "Core Technologies\tLanguages", "Education\tLanguages",
        ])
    }

    @Test("A line of bold headings' words with wide gaps, many times over, is analysed within the budget of a sort")
    func hostileHeadingGaps() throws {
        var words: [ExtractedWord] = []
        for line in 0..<1_000 {
            for column in 0..<10 {
                words.append(ExtractedWord(
                    text: "Education", frame: Rect(x: 20 + Double(column) * 55, y: Double(line) * 0.8, width: 45, height: 0.6),
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
