import Foundation
import Testing
@testable import PrestoCVImporting

/// A PDF's geometry is untrusted input (R8): a layout over the limits of its words, lines or cells is refused before the
/// analysis reads it, the analysis's work grows as a sort's does, and a cancelled task stops it.
@Suite("Analysing a hostile PDF layout")
struct LayoutLimitsTests {

    private let limits = ImportLimits(
        maximumPDFBytes: 1_000_000, maximumPages: 10, maximumCharacters: 100_000,
        maximumWords: 20_000, maximumLines: 2_000, maximumCells: 4_000, maximumAnalysisSteps: 10_000_000
    )

    /// Lines a hair apart, each with a word on the left and one far on the right, as many as the limits allow. The left
    /// words end at 800 different points inside the band where a column's gutter is looked for: each is a candidate.
    private func hostilePage(lines: Int, cellsPerLine: Int = 2) -> ExtractedPage {
        var words: [ExtractedWord] = []
        for index in 0..<lines {
            let y = Double(index) * 0.4
            let width = 1 + Double(index % 800) * 0.5
            words.append(ExtractedWord(text: "a", frame: Rect(x: 72, y: y, width: width, height: 0.3), fontSize: 0.3, isBold: false))
            for cell in 1..<cellsPerLine {
                let x = 480 + Double(cell) * 20
                words.append(ExtractedWord(text: "b", frame: Rect(x: x, y: y, width: 1, height: 0.3), fontSize: 0.3, isBold: false))
            }
        }
        return ExtractedPage(width: 595, height: 842, words: words)
    }

    private func analyze(_ pages: [ExtractedPage], limits: ImportLimits) throws -> LayoutAnalyzer.Analysis {
        var work = AnalysisWork(budget: limits.maximumAnalysisSteps)
        return try LayoutAnalyzer.analyze(pages, limits: limits, work: &work)
    }

    /// Limits that allow `steps` of analysis.
    private func limits(steps: Int) -> ImportLimits {
        ImportLimits(
            maximumPDFBytes: limits.maximumPDFBytes, maximumPages: limits.maximumPages, maximumCharacters: limits.maximumCharacters,
            maximumWords: limits.maximumWords, maximumLines: limits.maximumLines, maximumCells: limits.maximumCells,
            maximumAnalysisSteps: steps
        )
    }

    @Test("A hostile layout within the limits is analysed in steps that grow as a sort's, not as the square of its words")
    func boundedWork() throws {
        let page = hostilePage(lines: 2_000)
        let words = page.words.count
        // A few sorts and a few passes over the words, the lines and the cells: the square of the words is 16 million
        let bound = 16 * AnalysisWork.sortSteps(words)

        let analysis = try analyze([page], limits: limits(steps: bound))

        #expect(analysis.lines.count >= 2_000)
        #expect(throws: LimitReached(.steps)) { try analyze([page], limits: limits(steps: words / 2)) }
    }

    @Test("A layout over the words, lines or cells of the limits is refused, the words before the analysis starts")
    func refusedOverTheLimits() throws {
        let manyWords = ExtractedPage(width: 595, height: 842, words: Array(repeating: ExtractedWord(
            text: "a", frame: Rect(x: 72, y: 72, width: 5, height: 10), fontSize: 10, isBold: false
        ), count: 20_001))
        // No step is allowed: the words are refused before the analysis starts
        #expect(throws: LimitReached(.words)) { try analyze([manyWords], limits: limits(steps: 0)) }
        #expect(throws: LimitReached(.lines)) { try analyze([hostilePage(lines: 2_001)], limits: limits) }
        #expect(throws: LimitReached(.cells)) { try analyze([hostilePage(lines: 1_000, cellsPerLine: 5)], limits: limits) }
        #expect(try analyze([hostilePage(lines: 1_000, cellsPerLine: 4)], limits: limits).lines.isEmpty == false)
    }

    @Test("A cancelled task stops the analysis, and the import, with the cancellation")
    func cancelled() async throws {
        let page = hostilePage(lines: 2_000)
        let analysis = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return Result { try analyze([page], limits: limits) }
        }.value
        #expect(throws: CancellationError.self) { try analysis.get() }

        var sketch = PageSketch()
        sketch.put("Giulia Bianchi, infermiera a Torino da dieci anni", x: 50, y: 50)
        let importer = ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([sketch.page])), limits: limits)
        let imported = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await importer.importPDF(Data([1]))
        }
        await #expect(throws: CancellationError.self) { try await imported.value }
    }
}
