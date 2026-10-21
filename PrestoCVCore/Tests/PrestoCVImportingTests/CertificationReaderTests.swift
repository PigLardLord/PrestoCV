import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// The layout of a certification that an import lost: a title with its level in brackets, which holds a comma, then the
/// issuer and the year. Every value here is invented (the corpus README).
@Suite("Reading certifications")
struct CertificationReaderTests {

    private func read(_ text: String) -> Findings {
        let (document, sections) = pasted(text)
        var findings = Findings(document: document)
        for section in sections where section.kind == .certifications {
            CertificationReader.read(section, into: &findings)
        }
        return findings
    }

    private func importedPDF(_ sketch: PageSketch) async throws -> ImportResult {
        try await ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([sketch.page])), limits: .standard).importPDF(Data([1]))
    }

    // MARK: The bracket of a title

    @Test("A title keeps its brackets, whatever separator they hold; the issuer and the year after it are read", arguments: [
        ("Applied Swift Series (Pro, Level Advanced) — Example Academy (2024)", "Applied Swift Series (Pro, Level Advanced)"),
        ("Applied Swift Series (Pro. Level Advanced) — Example Academy (2024)", "Applied Swift Series (Pro. Level Advanced)"),
        ("Applied Swift Series (Pro | Advanced) — Example Academy (2024)", "Applied Swift Series (Pro | Advanced)"),
        ("Applied Swift Series (Pro - Advanced) — Example Academy (2024)", "Applied Swift Series (Pro - Advanced)"),
        ("Applied Swift Series [Pro, Advanced] — Example Academy (2024)", "Applied Swift Series [Pro, Advanced]"),
    ])
    func bracketedTitle(line: String, title: String) throws {
        let found = read("Certifications\n\(line)")
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.name.value == title)
        #expect(certification.issuer?.value == "Example Academy")
        #expect(certification.year?.value == 2024)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A year inside the title's brackets stays in the title, and is still read as the year")
    func yearInTheBrackets() throws {
        let found = read("Certifications\nApplied Swift Series (Pro, 2024) — Example Academy")
        let certification = try #require(found.cv.certifications.first)
        #expect(certification.name.value == "Applied Swift Series (Pro, 2024)")
        #expect(certification.issuer?.value == "Example Academy")
        #expect(certification.year?.value == 2024)
    }

    @Test("The two certifications of a PDF page in the rail layout: the heading beside the first entry, one line each")
    func railLayout() async throws {
        var sketch = PageSketch()
        sketch.put("Giulia Bianchi", x: 46, y: 50, size: 20, bold: true)
        sketch.put("iOS Developer", x: 46, y: 80)
        sketch.put("Certifications", x: 88, y: 150, size: 9, bold: true)
        sketch.put("Applied Swift Series (Pro, Level Advanced) — Example Academy (2024)", x: 172, y: 150, size: 9.5, bold: true)
        sketch.put("Our Best Practice (Pro, Remote Edition) — Beispiel Institut (2023)", x: 172, y: 172, size: 9.5, bold: true)
        let result = try await importedPDF(sketch)
        #expect(result.cv.certifications.map(\.name.value) == [
            "Applied Swift Series (Pro, Level Advanced)", "Our Best Practice (Pro, Remote Edition)",
        ])
        #expect(result.cv.certifications.map { $0.issuer?.value } == ["Example Academy", "Beispiel Institut"])
        #expect(result.cv.certifications.map { $0.year?.value } == [2024, 2023])
        #expect(result.unplaced.isEmpty)
        #expect(result.ungrounded.isEmpty)
    }
}
