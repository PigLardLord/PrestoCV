import Foundation
import Testing
@testable import PrestoCVImporting

/// A PDF reader that hands over a layout it was given, or throws.
struct ScriptedPDFReader: PDFTextExtracting {
    var layout: ExtractedLayout = .pages([])
    var error: (any Error & Sendable)?

    func layout(ofPDF data: Data, limits: ImportLimits) async throws -> ExtractedLayout {
        if let error { throw error }
        return layout
    }
}

@Suite("Importing a CV")
struct ImportCVTests {

    private let limits = ImportLimits(
        maximumPDFBytes: 1_000, maximumPages: 3, maximumCharacters: 5_000,
        maximumWords: 1_000, maximumLines: 200, maximumCells: 400, maximumAnalysisSteps: 1_000_000
    )

    private func importer(_ reader: ScriptedPDFReader = ScriptedPDFReader()) -> ImportCV {
        ImportCV(pdfReader: reader, limits: limits)
    }

    @Test("A pasted chat answer becomes a CV whose every value is grounded, with its review list, and nothing silently lost")
    func pastedAnswer() throws {
        let result = try importer().importText("""
        Ecco il tuo CV:

        # Giulia Bianchi
        **Infermiera**
        Torino, Italia · giulia.bianchi@example.com

        ## Esperienza
        **Infermiera** | Ospedale Esempio | Torino | 03/2019 – oggi
        - Assistenza ai pazienti

        ## Lingue
        - Inglese: buono

        ## Volontariato
        Croce Rossa, dal 2015
        """)
        #expect(result.cv.person.name?.value == "Giulia Bianchi")
        #expect(result.cv.experience.first?.employer?.value == "Ospedale Esempio")
        #expect(result.language == .it)
        #expect(result.reviewList.map(\.reason) == [.levelNotCEFR])
        #expect(result.unplaced.map(\.text) == ["Croce Rossa, dal 2015"])
        #expect(result.unplaced.first?.heading == "Volontariato")
        #expect(result.leftOut.map(\.reason) == [.chatter])
        #expect(result.ungrounded.isEmpty)
    }

    @Test("An empty text, a text over the limit and a text without letters are typed errors")
    func textErrors() {
        #expect(throws: ImportError.empty) { try importer().importText("  \n\n ") }
        #expect(throws: ImportError.empty) { try importer().importText("--- \n 2019") }
        #expect(throws: ImportError.tooLarge) { try importer().importText(String(repeating: "a", count: 5_001)) }
    }

    @Test("A PDF is read through the port; its size and pages are bounded, and a scan is told apart")
    func pdf() async throws {
        var sketch = PageSketch()
        sketch.put("Lena Hartmann", x: 50, y: 50, size: 20, bold: true)
        sketch.put("Elektrikerin", x: 50, y: 80)
        sketch.put("Berufserfahrung", x: 50, y: 120, size: 13, bold: true)
        sketch.put("03/2019 – heute", x: 50, y: 140)
        sketch.put("Elektrikerin, Beispiel GmbH, Leipzig", x: 200, y: 140)
        let result = try await importer(ScriptedPDFReader(layout: .pages([sketch.page]))).importPDF(Data([1]))
        #expect(result.document.format == .pdf)
        #expect(result.cv.person.name?.value == "Lena Hartmann")
        #expect(result.cv.experience.first?.employer?.value == "Beispiel GmbH")

        await #expect(throws: ImportError.empty) { try await importer().importPDF(Data()) }
        await #expect(throws: ImportError.tooLarge) { try await importer().importPDF(Data(count: 1_001)) }
        let fourPages = Array(repeating: sketch.page, count: 4)
        await #expect(throws: ImportError.tooManyPages) { try await importer(ScriptedPDFReader(layout: .pages(fourPages))).importPDF(Data([1])) }
        let scan = ExtractedPage(width: 595, height: 842, words: [])
        await #expect(throws: ImportError.noText) { try await importer(ScriptedPDFReader(layout: .pages([scan]))).importPDF(Data([1])) }
        await #expect(throws: ImportError.encrypted) { try await importer(ScriptedPDFReader(error: ImportError.encrypted)).importPDF(Data([1])) }
    }

    @Test("A reader's own failure is an unreadable PDF, and cancellation passes through")
    func readerFailures() async {
        struct Broken: Error {}
        await #expect(throws: ImportError.unreadable) { try await importer(ScriptedPDFReader(error: Broken())).importPDF(Data([1])) }
        await #expect(throws: CancellationError.self) { try await importer(ScriptedPDFReader(error: CancellationError())).importPDF(Data([1])) }
    }

    @Test("The gate drops a value that is not the text of its spans, keeps its text visible, and says so")
    func gate() throws {
        var result = try importer().importText("Giulia Bianchi\nInfermiera")
        #expect(result.ungrounded.isEmpty)
        var tampered = result.cv
        tampered.person.title = Sourced(value: "Primaria", spans: try #require(result.cv.person.title?.spans))
        result.cv = tampered
        let enforced = ImportGrounding.enforced(result)
        #expect(enforced.ungrounded == ["title"])
        #expect(enforced.cv.person.title == nil)
        #expect(enforced.unplaced.map(\.text) == ["Infermiera"])
    }
}
