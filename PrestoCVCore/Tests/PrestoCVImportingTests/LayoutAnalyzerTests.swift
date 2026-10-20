import Testing
@testable import PrestoCVImporting

/// Lays out words as a PDF would: each line of text at a height, its words from an x, in Helvetica-like widths.
struct PageSketch {
    var words: [ExtractedWord] = []
    let width: Double = 595
    let height: Double = 842

    /// Puts a run of words on a line; `size` is the font size.
    mutating func put(_ text: String, x: Double, y: Double, size: Double = 10, bold: Bool = false) {
        var cursor = x
        for word in text.split(separator: " ") {
            let width = Double(word.count) * size * 0.5
            words.append(ExtractedWord(text: String(word), frame: Rect(x: cursor, y: y, width: width, height: size * 1.2), fontSize: size, isBold: bold))
            cursor += width + size * 0.28
        }
    }

    var page: ExtractedPage { ExtractedPage(width: width, height: height, words: words) }
}

@Suite("Analysing the pages of a PDF")
struct LayoutAnalyzerTests {

    private func texts(_ pages: [ExtractedPage]) -> [String] {
        LayoutAnalyzer.analyze(pages).lines.map(\.text)
    }

    @Test("Words become lines in the order of the page, whatever order the reader gave them in")
    func lines() {
        var sketch = PageSketch()
        sketch.put("Second line", x: 50, y: 120)
        sketch.put("Giulia Bianchi", x: 50, y: 80, size: 20, bold: true)
        var shuffled = sketch.page
        shuffled = ExtractedPage(width: shuffled.width, height: shuffled.height, words: shuffled.words.reversed())
        let analysis = LayoutAnalyzer.analyze([shuffled])
        #expect(analysis.lines.map(\.text) == ["Giulia Bianchi", "Second line"])
        #expect(analysis.lines[0].isEmphasized)
        #expect(analysis.lines[0].fontSize == 20)
    }

    @Test("A wide gap inside a line separates cells")
    func cells() {
        var sketch = PageSketch()
        sketch.put("Senior iOS Developer", x: 50, y: 100, bold: true)
        sketch.put("Milan, Italy", x: 450, y: 100)
        #expect(texts([sketch.page]) == ["Senior iOS Developer\tMilan, Italy"])
    }

    @Test("A sidebar is read after the main column, the column with the name first")
    func sidebar() {
        var sketch = PageSketch()
        // Sidebar on the left, with lines that do not line up with the main column
        sketch.put("Contact", x: 30, y: 60, size: 12, bold: true)
        sketch.put("giulia@example.com", x: 30, y: 78)
        sketch.put("Top Skills", x: 30, y: 110, size: 12, bold: true)
        sketch.put("Swift", x: 30, y: 128)
        sketch.put("Languages", x: 30, y: 160, size: 12, bold: true)
        sketch.put("Italian (Native)", x: 30, y: 178)
        // Main column on the right
        sketch.put("Giulia Bianchi", x: 220, y: 55, size: 22)
        sketch.put("iOS Developer", x: 220, y: 84)
        sketch.put("Experience", x: 220, y: 120, size: 14, bold: true)
        sketch.put("Acme S.p.A.", x: 220, y: 140, bold: true)
        sketch.put("Senior iOS Developer", x: 220, y: 156)
        let analysis = LayoutAnalyzer.analyze([sketch.page])
        #expect(analysis.lines.map(\.text) == [
            "Giulia Bianchi", "iOS Developer", "Experience", "Acme S.p.A.", "Senior iOS Developer",
            "Contact", "giulia@example.com", "Top Skills", "Swift", "Languages", "Italian (Native)",
        ])
        #expect(analysis.lines.map(\.column) == [0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1])
    }

    @Test("A left column of dates is a table: its rows stay rows")
    func lebenslaufTable() {
        var sketch = PageSketch()
        sketch.put("Berufserfahrung", x: 50, y: 60, size: 13, bold: true)
        sketch.put("03/2019 – heute", x: 50, y: 90)
        sketch.put("Projektleiterin", x: 180, y: 90, bold: true)
        sketch.put("Beispiel GmbH, Leipzig", x: 180, y: 104)
        sketch.put("09/2015 – 02/2019", x: 50, y: 130)
        sketch.put("Elektrikerin", x: 180, y: 130, bold: true)
        sketch.put("Muster Elektro AG, Dresden", x: 180, y: 144)
        #expect(texts([sketch.page]) == [
            "Berufserfahrung", "03/2019 – heute\tProjektleiterin", "Beispiel GmbH, Leipzig",
            "09/2015 – 02/2019\tElektrikerin", "Muster Elektro AG, Dresden",
        ])
    }

    @Test("Headers and footers repeated on every page, and page numbers, are left out")
    func repeatedLines() {
        var first = PageSketch()
        first.put("Lena Hartmann – Lebenslauf", x: 50, y: 20, size: 8)
        first.put("Berufserfahrung", x: 50, y: 100)
        first.put("Seite 1 von 2", x: 260, y: 810, size: 8)
        var second = PageSketch()
        second.put("Lena Hartmann – Lebenslauf", x: 50, y: 20, size: 8)
        second.put("Ausbildung", x: 50, y: 100)
        second.put("Seite 2 von 2", x: 260, y: 810, size: 8)
        let analysis = LayoutAnalyzer.analyze([first.page, second.page])
        #expect(analysis.lines.map(\.text) == ["Berufserfahrung", "Ausbildung"])
        #expect(analysis.leftOut.map(\.reason) == [.repeatedOnPages, .pageNumber, .repeatedOnPages, .pageNumber])
    }

    @Test("A wider gap than between lines is marked, and a list item's text start is kept for its wrapped lines")
    func gapsAndIndents() {
        var sketch = PageSketch()
        sketch.put("• Planung von Elektroinstallationen in", x: 50, y: 100)
        sketch.put("Bürogebäuden", x: 50 + 5 + 2.8, y: 113)
        sketch.put("Ausbildung", x: 50, y: 150)
        let analysis = LayoutAnalyzer.analyze([sketch.page])
        #expect(analysis.lines.map(\.followsGap) == [false, false, true])
        #expect(analysis.lines[0].textStart == 50 + 5 + 2.8)
    }
}
