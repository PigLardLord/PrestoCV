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

    // MARK: The issuer, the link and the description

    @Test("A web address on its own line and a description of two lines land in the fields of the certification before them")
    func linkAndDescriptionLines() throws {
        let found = read("""
        Certifications
        Advanced Swift Concurrency (Level 2) — Example Academy (2024)
        https://academy.example/achievement
        Covers actors and structured concurrency in depth.
        Includes a capstone project reviewed by a mentor.
        """)
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.name.value == "Advanced Swift Concurrency (Level 2)")
        #expect(certification.issuer?.value == "Example Academy")
        #expect(certification.year?.value == 2024)
        #expect(certification.link?.value.value == "https://academy.example/achievement")
        #expect(certification.link?.reading == nil)
        #expect(certification.description?.value == "Covers actors and structured concurrency in depth.\nIncludes a capstone project reviewed by a mentor.")
        #expect(found.unplaced.isEmpty)
    }

    @Test("A web address in the line of the title is the link, and the issuer is still read", arguments: [
        ("https://academy.example/achievement", nil as ReadingRule?, "https://academy.example/achievement"),
        ("academy.dev/achievement", ReadingRule.webAddress, "https://academy.dev/achievement"),
    ])
    func linkInTheLine(address: String, reading: ReadingRule?, link: String) throws {
        let found = read("Certifications\nAdvanced Swift Concurrency (Level 2) — Example Academy (2024) — \(address)")
        let certification = try #require(found.cv.certifications.first)
        #expect(certification.name.value == "Advanced Swift Concurrency (Level 2)")
        #expect(certification.issuer?.value == "Example Academy")
        #expect(certification.year?.value == 2024)
        #expect(certification.link?.value.value == link)
        #expect(certification.link?.reading == reading)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A label of the link, in any of the six languages, is left out as structure, and the address is the link", arguments: [
        "Credential: https://academy.example/c/123", "Link: https://academy.example/c/123", "Verifica online: https://academy.example/c/123",
        "Zertifikat https://academy.example/c/123", "Enlace: https://academy.example/c/123", "Lien : https://academy.example/c/123",
        "Verificar https://academy.example/c/123", "https://academy.example/c/123 (credential)",
    ])
    func labelledLink(line: String) throws {
        let found = read("Certifications\nSwift Basics – Example Academy, 2023\n\(line)")
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.link?.value.value == "https://academy.example/c/123")
        #expect(found.leftOut.map(\.reason).allSatisfy { $0 == .categoryLabel })
        #expect(found.unplaced.isEmpty)
    }

    @Test("A short certification with a web address in its line is a certification of its own, not the label and link of the one before", arguments: [
        "Swift Basics https://academy.example/swift", "Swift Basics (2023) https://academy.example/swift",
        "Swift Basics 2023 https://academy.example/swift", "Swift Basics – academy.dev/swift", "Swift Basics: https://academy.example/swift",
    ])
    func titledAddressIsAnEntry(line: String) throws {
        let found = read("Certifications\nFirst Certificate\n\(line)")
        #expect(found.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        #expect(found.cv.certifications.map { $0.link != nil } == [false, true])
        #expect(found.leftOut.isEmpty)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A second address, and a part the rules cannot place, stay visible as text not imported")
    func whatTheRulesCannotPlace() throws {
        let found = read("""
        Certifications
        Swift Basics (Level 1) — Example Academy — Remote cohort (2023) — https://academy.example/a — https://academy.example/b
        """)
        let certification = try #require(found.cv.certifications.first)
        #expect(certification.name.value == "Swift Basics (Level 1)")
        #expect(certification.issuer?.value == "Example Academy")
        #expect(certification.link?.value.value == "https://academy.example/a")
        #expect(found.unplaced.map(\.text) == ["Remote cohort", "https://academy.example/b"])
    }

    @Test("Plain lines stay one certification each: a line is a description only when it reads as one")
    func plainLinesStayEntries() throws {
        let found = read("""
        Certifications
        BLSD – Croce Rossa Italiana (2021)
        Corso di primo soccorso
        Patente nautica
        """)
        #expect(found.cv.certifications.map(\.name.value) == ["BLSD", "Corso di primo soccorso", "Patente nautica"])
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
    }

    @Test("A sentence under a certification is its description; a dated line is the next certification")
    func sentenceIsDescription() throws {
        let found = read("""
        Certifications
        BLSD – Croce Rossa Italiana (2021)
        Il corso copre la rianimazione di base per adulti e bambini.
        AWS Certified Developer, Amazon Web Services, 2022
        """)
        #expect(found.cv.certifications.map(\.name.value) == ["BLSD", "AWS Certified Developer"])
        #expect(found.cv.certifications.map { $0.description?.value } == ["Il corso copre la rianimazione di base per adulti e bambini.", nil])
    }

    @Test("In a PDF, the lines under a bold title in the regular weight are its description, however short")
    func pdfDescription() async throws {
        var sketch = PageSketch()
        sketch.put("Giulia Bianchi", x: 46, y: 50, size: 20, bold: true)
        sketch.put("iOS Developer", x: 46, y: 80)
        sketch.put("Certifications", x: 88, y: 150, size: 9, bold: true)
        sketch.put("Applied Swift Series (Pro, Level Advanced) — Example Academy (2024)", x: 172, y: 150, size: 9.5, bold: true)
        sketch.put("Covers actors and structured concurrency.", x: 172, y: 164, size: 9.5)
        sketch.put("Includes a capstone project.", x: 172, y: 176, size: 9.5)
        sketch.put("Our Best Practice (Pro, Remote Edition) — Beispiel Institut (2023)", x: 172, y: 196, size: 9.5, bold: true)
        sketch.put("Advanced", x: 172, y: 210, size: 9.5)
        sketch.put("Server Side Swift (Beta) — Example Institute (2022)", x: 172, y: 230, size: 9.5, bold: true)
        let result = try await importedPDF(sketch)
        #expect(result.cv.certifications.map(\.name.value) == [
            "Applied Swift Series (Pro, Level Advanced)", "Our Best Practice (Pro, Remote Edition)", "Server Side Swift (Beta)",
        ])
        #expect(result.cv.certifications.map { $0.issuer?.value } == ["Example Academy", "Beispiel Institut", "Example Institute"])
        #expect(result.cv.certifications.map { $0.year?.value } == [2024, 2023, 2022])
        #expect(result.cv.certifications.map { $0.description?.value } == [
            "Covers actors and structured concurrency.\nIncludes a capstone project.", "Advanced", nil,
        ])
        #expect(result.unplaced.isEmpty)
        #expect(result.ungrounded.isEmpty)
    }

    @Test("The gate refuses a link or a description that is not the text of its spans, and keeps that text visible")
    func gate() throws {
        var result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText("""
        Certifications
        Swift Basics – Example Academy (2023) – https://academy.example/a
        Covers the basics of the language.
        """)
        let certification = try #require(result.cv.certifications.first)
        #expect(result.ungrounded.isEmpty)
        var tampered = certification
        tampered.link = Sourced(value: try #require(WebLink("https://evil.example/")), spans: try #require(certification.link?.spans))
        tampered.description = Sourced(value: "An invented description.", spans: try #require(certification.description?.spans))
        result.cv.certifications = [tampered]
        let enforced = ImportGrounding.enforced(result)
        #expect(enforced.ungrounded == ["certification link", "certification description"])
        #expect(enforced.cv.certifications.first?.link == nil)
        #expect(enforced.cv.certifications.first?.description == nil)
        #expect(enforced.unplaced.map(\.text).contains("https://academy.example/a"))
        #expect(enforced.unplaced.map(\.text).contains("Covers the basics of the language."))
    }
}
