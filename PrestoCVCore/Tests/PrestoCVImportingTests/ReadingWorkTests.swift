import Foundation
import Testing
@testable import PrestoCVImporting

/// A CV's text is untrusted input (R8), pasted or read from a PDF: the work of reading it grows with its size, and what
/// it takes past the budget it is refused for, before the costly loop starts. The tests count work, not seconds: a
/// section's reading is refused over the budget however fast the machine is.
@Suite("Reading a hostile text")
struct ReadingWorkTests {

    private func limits(steps: Int) -> ImportLimits {
        ImportLimits(
            maximumPDFBytes: 1_000_000, maximumPages: 10, maximumCharacters: 100_000,
            maximumWords: 20_000, maximumLines: 2_000, maximumCells: 4_000, maximumAnalysisSteps: steps
        )
    }

    private func importer(steps: Int = ImportLimits.standard.maximumAnalysisSteps) -> ImportCV {
        ImportCV(pdfReader: ScriptedPDFReader(), limits: limits(steps: steps))
    }

    /// The error a call fails with, if it fails: a failed expectation prints the result of a call that was to fail, which
    /// for an import is the whole text.
    private func failure(of call: () throws -> ImportResult) -> (any Error)? {
        do { _ = try call(); return nil } catch { return error }
    }

    /// What a call ended with, without its value.
    private struct Outcome: Sendable {
        let failure: (any Error)?
        init(_ call: () throws -> ImportResult) {
            do { _ = try call(); failure = nil } catch { failure = error }
        }
    }

    /// A section of one-letter lines on each side of a date, each side `lines` long: the lines above the second date may
    /// be its entry's head or the first one's description, and every number of them is a choice to be scored against
    /// every number of the lines above the first.
    private func linesAroundDates(_ lines: Int, heading: String = "Experience") -> String {
        let letters = String(repeating: "a\n", count: lines)
        return "\(heading)\n" + letters + "2020 – 2021\n" + letters + "2019 – 2020\n"
    }

    @Test("A section of a hundred thousand characters whose dates are far from each other is refused, not searched")
    func theLongestSectionIsRefused() {
        // 24,980 lines on each side of a date: the readings of the dates after their heads number 624 million
        let text = linesAroundDates(24_980)
        #expect(text.unicodeScalars.count <= ImportLimits.standard.maximumCharacters)

        #expect(failure(of: { try importer().importText(text) }) as? ImportError == .tooLarge)
    }

    @Test("The choices of a date are counted before they are scored, and a section over the budget is refused")
    func choicesAreCountedBeforeTheyAreScored() throws {
        // 1,000 lines on each side: a million readings of the second date against the first
        let text = linesAroundDates(1_000)

        #expect(failure(of: { try importer(steps: 500_000).importText(text) }) as? ImportError == .tooLarge)
        let imported = try importer(steps: 5_000_000).importText(text)
        #expect(imported.cv.experience.count == 2)
    }

    @Test("A section of the same size that reads fast is within the budget, whichever section it is")
    func educationIsCountedToo() throws {
        let text = linesAroundDates(1_000, heading: "Education")

        #expect(failure(of: { try importer(steps: 500_000).importText(text) }) as? ImportError == .tooLarge)
        #expect(try importer(steps: 5_000_000).importText(text).cv.education.count == 2)
    }

    @Test("A task that is cancelled stops the reading of a pasted text with the cancellation")
    func cancelled() async {
        let text = linesAroundDates(100)
        let reading = importer()
        let imported = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return Outcome { try reading.importText(text) }
        }
        let outcome = await imported.value
        #expect(outcome.failure is CancellationError)
    }

    // MARK: What is read again for each line, and what is read again for each match in a line

    /// Expects the reading of a text of `units` units of a shape to cost no more than its share of the reading of a
    /// quarter of it, and the reading to end as it should: in a CV, or in `refusal`. A text of nothing but numbers says
    /// nothing and is refused for that after it is read: what counts is that it is read.
    private func expectLinearReading(
        _ shape: String, units: Int, refusal: ImportError? = nil,
        sourceLocation: SourceLocation = #_sourceLocation, text: (Int) -> String
    ) {
        let reading = importer()
        expectLinear(shape, whole: units, cost: { size in
            let pasted = text(size)
            var failure: (any Error)?
            let seconds = cpuSeconds { do { _ = try reading.importText(pasted) } catch { failure = error } }
            #expect(failure == nil || (refusal != nil && failure as? ImportError == refusal), "\(shape): the reading ended with \(String(describing: failure))", sourceLocation: sourceLocation)
            return seconds
        })
    }

    @Test("A head that holds many headings in the shape of a name reads each of its blocks once, not once for each heading")
    func headingsThatCouldBeTheNameAreReadOnce() {
        // Each heading looks again at the head, which the headings before it have grown: 125 thousand looks at a block
        expectLinearReading("headings", units: 500) { String(repeating: "# John Smith\n", count: $0) }
    }

    @Test("A text of nothing but headings in the shape of a name is refused, once the looks at the head pass the budget")
    func manyHeadingsThatCouldBeTheNameAreRefused() {
        let text = String(repeating: "# John Smith\n", count: 7_000)
        #expect(text.unicodeScalars.count <= ImportLimits.standard.maximumCharacters)
        #expect(failure(of: { try importer().importText(text) }) as? ImportError == .tooLarge)
    }

    @Test("The dates of a line of certifications are put in or out of their brackets in one pass over the line")
    func certificationDatesInBracketsAreOnePass() {
        expectLinearReading("brackets", units: 4_000) { "Certifications\n" + String(repeating: "AWS (2020), ", count: $0) }
    }

    @Test("A line of dates read as one cell of a certification is read in one pass")
    func certificationDatesInALineAreOnePass() {
        expectLinearReading("dates", units: 4_000) { "Certifications\n" + String(repeating: "x 2020 y ", count: $0) }
    }

    @Test("The label before each number of a line is found by looking back a few words, not over the line")
    func labelsBeforeNumbersAreFoundLocally() {
        expectLinearReading("labels", units: 2_000) { String(repeating: "x 2020 – 2021 y ", count: $0) }
    }

    @Test("A line of many addresses and numbers is read in one pass over the line", arguments: [
        "john@example.com ", "http://a.b ", "+44 20 7946 0958 | ", "Leeds, ", "+ ",
    ])
    func contactsInALineAreOnePass(unit: String) {
        expectLinearReading(unit, units: ImportLimits.standard.maximumCharacters / unit.count, refusal: .empty) {
            String(repeating: unit, count: $0)
        }
    }

    @Test("Many levels in one item of a language are taken out of the item in one pass, not by counting from its start for each")
    func manyLevelsInAnItemAreRemovedInOnePass() {
        // 31 thousand levels in the item of one language: each one is found at its place in the item
        #expect(("Languages\nEnglish " + String(repeating: "B2 ", count: 31_000)).unicodeScalars.count <= ImportLimits.standard.maximumCharacters)
        expectLinearReading("levels", units: 31_000) { "Languages\nEnglish " + String(repeating: "B2 ", count: $0) }
    }

    @Test("The section of each passage that nothing placed is found by its place in the text, not by looking through the blocks of every section")
    func theSectionOfALostLineIsFoundByItsPlace() {
        // 45 thousand one-letter lines in one section, none of them placed by any reader: each one is looked up
        expectLinear("lost lines", whole: 45_000, cost: { lines in
            let text = "Experience\n" + String(repeating: "a\n", count: lines)
            let (document, leftOut) = DocumentBuilder.build(lines: PlainTextReader.lines(of: text).map { RawLine(text: $0) }, format: .pastedText)
            let sections = SectionSegmenter.sections(of: document)
            let result = ImportResult(document: document, cv: ImportedCV(), language: nil, unplaced: [], leftOut: leftOut)
            var swept = result
            let seconds = cpuSeconds { swept = Remainder.swept(result, sections: sections) }
            #expect(swept.unplaced.count > lines * 8 / 10)
            #expect(swept.unplaced.allSatisfy { $0.section == .experience })
            return seconds
        })
    }

    @Test("A check of growth tells a pass over a text from a pass over it for each of its parts")
    func theCheckOfGrowthTellsTheTwoApart() {
        func pass(_ size: Int) -> Double {
            cpuSeconds { var sum = 0; for index in 0..<size * 4_000 { sum &+= index ^ (sum >> 3) }; #expect(sum != 1) }
        }
        func passForEachPart(_ size: Int) -> Double {
            cpuSeconds { var sum = 0; for part in 0..<size { for index in 0..<size { sum &+= index ^ part } }; #expect(sum != 1) }
        }
        let linear = growth(whole: 4_000, cost: pass)
        let quadratic = growth(whole: 4_000, cost: passForEachPart)
        #expect(linear.ratio < linearGrowthBound, "\(linear)")
        #expect(quadratic.ratio > linearGrowthBound, "\(quadratic)")
    }

    // MARK: A PDF shares its budget with the reading of its text

    /// The pages of a PDF whose section is `lines` one-letter lines on each side of a date, within the limits of its
    /// words and lines.
    private func pages(lines: Int) -> [ExtractedPage] {
        var rows = ["Experience"] + Array(repeating: "a", count: lines) + ["2020 – 2021"] + Array(repeating: "a", count: lines) + ["2019 – 2020"]
        var pages: [ExtractedPage] = []
        while !rows.isEmpty {
            var sketch = PageSketch()
            for (index, row) in rows.prefix(165).enumerated() { sketch.put(row, x: 50, y: 90 + Double(index) * 3.9, size: 2) }
            rows.removeFirst(min(165, rows.count))
            pages.append(sketch.page)
        }
        return pages
    }

    @Test("A PDF's reading counts against the budget of its analysis")
    func theReadingOfAPDFSharesTheBudget() throws {
        let pages = pages(lines: 800)
        var probe = AnalysisWork(budget: .max / 2)
        let analysis = try LayoutAnalyzer.analyze(pages, limits: limits(steps: .max / 2), work: &probe)
        #expect(analysis.lines.count > 1_600, "The analysis keeps the lines the test counts on")

        // The analysis alone fits its budget, and the 640 thousand readings of the dates do not fit what is left
        let analysed = probe.steps
        let layout = ExtractedLayout.pages(pages)
        let tight = ImportCV(pdfReader: ScriptedPDFReader(layout: layout), limits: limits(steps: analysed + 300_000))
        #expect(failure(of: { try tight.read(layout) }) as? LimitReached == LimitReached(.steps))
        let roomy = ImportCV(pdfReader: ScriptedPDFReader(layout: layout), limits: limits(steps: analysed + 3_000_000))
        #expect(try roomy.read(layout).cv.experience.count == 2)
    }
}
