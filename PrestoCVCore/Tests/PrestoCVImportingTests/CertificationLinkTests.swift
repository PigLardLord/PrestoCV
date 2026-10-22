import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// A certification's link and description (ADR 0027). The rule is to split rather than merge: a line goes on with the
/// certification above it only on clear evidence, and anything else starts a certification of its own, because a wrong
/// split shows on screen and a wrong merge loses a certification without a word. Every value here is invented.
@Suite("Reading a certification's link and description")
struct CertificationLinkTests {

    private let address = "https://academy.example/swift"
    private let longAddress = "https://academy.example/certificates/professional/swift/development/advanced/concurrency/networking/testing/security/performance/design/patterns/credential"

    private func read(_ text: String) -> Findings {
        let (document, sections) = pasted(text)
        var findings = Findings(document: document)
        for section in sections where section.kind == .certifications {
            CertificationReader.read(section, into: &findings)
        }
        return findings
    }

    /// A line of a PDF page under the heading, from the left margin or indented.
    private struct Row {
        var text: String
        var indent = 0.0
        var size = 9.5
        var bold = false
        /// A blank line comes before it.
        var gap = false
    }

    private func importedPDF(_ rows: [Row]) async throws -> ImportResult {
        var sketch = PageSketch()
        sketch.put("Giulia Bianchi", x: 46, y: 50, size: 20, bold: true)
        sketch.put("iOS Developer", x: 46, y: 80)
        sketch.put("Certifications", x: 46, y: 130, size: 11, bold: true)
        var y = 150.0
        for row in rows {
            if row.gap { y += 12 }
            sketch.put(row.text, x: 46 + row.indent, y: y, size: row.size, bold: row.bold)
            y += 14
        }
        return try await ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([sketch.page])), limits: .standard).importPDF(Data([1]))
    }

    // MARK: The four counterexamples of the reviews

    @Test("A title with its address, under another certification, is a certification of its own with the address as its link")
    func titleWithAddress() throws {
        let found = read("Certifications\nFirst Certificate\nSwift Basics \(address)")
        #expect(found.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        #expect(found.cv.certifications.map { $0.link?.value.value } == [nil, address])
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
        #expect(found.cv.certifications.allSatisfy { $0.name.check == nil })
        #expect(found.unplaced.isEmpty)
        #expect(found.leftOut.isEmpty)
    }

    @Test("A bare noun with an address is no label of the link: it is a certification of its own, to check", arguments: [
        "Certificate", "Certificate:", "Badge", "Digital", "Credential", "Certificato", "Zertifikat", "Certificado", "Attestation", "Details",
        "Online", "Website",
    ])
    func bareNounWithAddress(noun: String) throws {
        let found = read("Certifications\nFirst Certificate\n\(noun) https://academy.example/c/123")
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.map { $0.link?.value.value } == [nil, "https://academy.example/c/123"])
        #expect(found.cv.certifications.map(\.name.check) == [nil, .certificationOrDetail])
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
        #expect(found.leftOut.isEmpty)
        #expect(found.unplaced.isEmpty)
    }

    @Test("In a PDF, a regular-weight undated title with an address under a bold title is a certification of its own")
    func regularTitleWithAddressInPDF() async throws {
        let result = try await importedPDF([
            Row(text: "First Certificate", bold: true),
            Row(text: "Swift Basics \(address)"),
        ])
        #expect(result.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        #expect(result.cv.certifications.map { $0.link?.value.value } == [nil, address])
        #expect(result.cv.certifications.map { $0.description == nil } == [true, true])
        #expect(result.unplaced.isEmpty)
        #expect(result.ungrounded.isEmpty)
    }

    @Test("The words of a long address are no sentence: a short title with a long address is a certification of its own")
    func longAddressIsNoSentence() async throws {
        let found = read("Certifications\nFirst Certificate\nSwift Basics \(longAddress)")
        #expect(found.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        #expect(found.cv.certifications.map { $0.link?.value.value } == [nil, longAddress])
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })

        // The same through the whole import, gate included, from a PDF with a bold title before it
        let result = try await importedPDF([
            Row(text: "First Certificate", bold: true),
            Row(text: "Swift Basics \(longAddress)"),
        ])
        #expect(result.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        #expect(result.cv.certifications.map { $0.link?.value.value } == [nil, longAddress])
        #expect(result.cv.certifications.map { $0.description == nil } == [true, true])
        #expect(result.unplaced.isEmpty)
        #expect(result.ungrounded.isEmpty)
    }

    // MARK: The link of a certification

    @Test("A line that holds only a web address is the link of the certification above it")
    func addressOnItsOwnLine() throws {
        let found = read("Certifications\nSwift Basics – Example Academy (2023)\nhttps://academy.example/achievement")
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.link?.value.value == "https://academy.example/achievement")
        #expect(certification.link?.reading == nil)
        #expect(found.unplaced.isEmpty)
    }

    @Test("The punctuation around an address is no text of the line: the address is still the whole of it", arguments: [
        "https://academy.example/achievement.", "(https://academy.example/achievement)", "Verify: https://academy.example/achievement.",
        "<https://academy.example/achievement>", "https://academy.example/achievement;",
    ])
    func punctuationAroundAnAddress(line: String) throws {
        let found = read("Certifications\nSwift Basics – Example Academy (2023)\n\(line)")
        #expect(found.cv.certifications.count == 1)
        #expect(found.cv.certifications.first?.link?.value.value == "https://academy.example/achievement")
        #expect(found.unplaced.isEmpty)
    }

    @Test("An address written without its scheme is read as an https address, and says so")
    func addressWithoutScheme() throws {
        let found = read("Certifications\nSwift Basics – Example Academy (2023)\nacademy.dev/achievement")
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.link?.value.value == "https://academy.dev/achievement")
        #expect(certification.link?.reading == .webAddress)
    }

    @Test("An address after an explicit label of a link, in any of the six languages, is the link; the label is left out", arguments: [
        "Credential URL: https://academy.example/c/123", "Link: https://academy.example/c/123", "Verifica online: https://academy.example/c/123",
        "Zertifikatslink https://academy.example/c/123", "Enlace: https://academy.example/c/123", "Lien : https://academy.example/c/123",
        "Verificar https://academy.example/c/123", "View certificate: https://academy.example/c/123", "Verify https://academy.example/c/123",
        "Überprüfen: https://academy.example/c/123", "https://academy.example/c/123 (link)",
    ])
    func labelledAddress(line: String) throws {
        let found = read("Certifications\nSwift Basics – Example Academy, 2023\n\(line)")
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.link?.value.value == "https://academy.example/c/123")
        #expect(found.leftOut.map(\.reason).allSatisfy { $0 == .categoryLabel })
        #expect(found.unplaced.isEmpty)
    }

    @Test("A web address in the line of the title is the link of that certification, and its issuer and year are still read", arguments: [
        ("https://academy.example/achievement", nil as ReadingRule?, "https://academy.example/achievement"),
        ("academy.dev/achievement", ReadingRule.webAddress, "https://academy.dev/achievement"),
    ])
    func addressInTheTitleLine(address: String, reading: ReadingRule?, link: String) throws {
        let found = read("Certifications\nAdvanced Swift Concurrency (Level 2) — Example Academy (2024) — \(address)")
        let certification = try #require(found.cv.certifications.first)
        #expect(certification.name.value == "Advanced Swift Concurrency (Level 2)")
        #expect(certification.issuer?.value == "Example Academy")
        #expect(certification.year?.value == 2024)
        #expect(certification.link?.value.value == link)
        #expect(certification.link?.reading == reading)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A second address stays visible as text not imported; it neither replaces the link nor makes a certification")
    func secondAddress() throws {
        let found = read("""
        Certifications
        Swift Basics (Level 1) — Example Academy — Remote cohort (2023) — https://academy.example/a — https://academy.example/b
        https://academy.example/c
        """)
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.name.value == "Swift Basics (Level 1)")
        #expect(certification.issuer?.value == "Example Academy")
        #expect(certification.link?.value.value == "https://academy.example/a")
        #expect(found.unplaced.map(\.text) == ["Remote cohort", "https://academy.example/b", "https://academy.example/c"])
    }

    @Test("A web address with no certification before it stays visible as text not imported")
    func addressWithNoCertification() throws {
        let found = read("Certifications\nhttps://academy.example/achievement\nSwift Basics – Example Academy (2023)")
        #expect(found.cv.certifications.map(\.name.value) == ["Swift Basics"])
        #expect(found.cv.certifications.first?.link == nil)
        #expect(found.unplaced.map(\.text) == ["https://academy.example/achievement"])
    }

    @Test("A bullet that holds only a web address is the link of the certification above it")
    func addressInABullet() throws {
        let found = read("Certifications\n- Swift Basics – Example Academy (2023)\n- https://academy.example/achievement")
        #expect(found.cv.certifications.count == 1)
        #expect(found.cv.certifications.first?.link?.value.value == "https://academy.example/achievement")
        #expect(found.unplaced.isEmpty)
    }

    // MARK: The description of a certification

    @Test("A sentence under a certification is its description; a second one goes on with it, in order")
    func sentenceIsDescription() throws {
        let found = read("""
        Certifications
        Advanced Swift Concurrency (Level 2) — Example Academy (2024)
        Covers actors and structured concurrency in depth.
        Includes a capstone project reviewed by a mentor.
        """)
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.description?.value == "Covers actors and structured concurrency in depth.\nIncludes a capstone project reviewed by a mentor.")
        #expect(certification.description?.spans.count == 2)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A link and a description of two lines land in the fields of the certification before them")
    func linkAndDescription() throws {
        let found = read("""
        Certifications
        Advanced Swift Concurrency (Level 2) — Example Academy (2024)
        https://academy.example/achievement
        Covers actors and structured concurrency in depth.
        Includes a capstone project reviewed by a mentor.
        Applied Swift Series (Pro) — Beispiel Institut (2023)
        """)
        #expect(found.cv.certifications.map(\.name.value) == ["Advanced Swift Concurrency (Level 2)", "Applied Swift Series (Pro)"])
        #expect(found.cv.certifications.first?.link?.value.value == "https://academy.example/achievement")
        #expect(found.cv.certifications.first?.description?.value == "Covers actors and structured concurrency in depth.\nIncludes a capstone project reviewed by a mentor.")
        #expect(found.cv.certifications.last?.link == nil)
        #expect(found.cv.certifications.last?.description == nil)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A sentence is judged on its words outside any address: one with an address is still a description, and keeps it in its text")
    func sentenceWithAddress() throws {
        let found = read("""
        Certifications
        First Certificate – Example Academy (2023)
        See the syllabus at \(longAddress) for the full list of topics.
        """)
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.link == nil)
        #expect(certification.description?.value == "See the syllabus at \(longAddress) for the full list of topics.")
    }

    @Test("In a PDF, a regular sentence under a bold title is its description")
    func sentenceInPDF() async throws {
        let result = try await importedPDF([
            Row(text: "Applied Swift Series (Pro, Level Advanced) — Example Academy (2024)", bold: true),
            Row(text: "Covers actors and structured concurrency."),
            Row(text: "Includes a capstone project."),
            Row(text: "Our Best Practice (Pro, Remote Edition) — Beispiel Institut (2023)", bold: true),
        ])
        #expect(result.cv.certifications.map(\.name.value) == ["Applied Swift Series (Pro, Level Advanced)", "Our Best Practice (Pro, Remote Edition)"])
        #expect(result.cv.certifications.map { $0.description?.value } == ["Covers actors and structured concurrency.\nIncludes a capstone project.", nil])
        #expect(result.unplaced.isEmpty)
        #expect(result.ungrounded.isEmpty)
    }

    @Test("In a PDF, the lines the layout places under the entry, indented or smaller, are its description, in any weight but bold", arguments: [
        (6.0, 9.5), (0.0, 8.0), (12.0, 8.0),
    ])
    func layoutPlacesTextUnderTheEntry(indent: Double, size: Double) async throws {
        let result = try await importedPDF([
            Row(text: "First Certificate – Example Academy (2023)", bold: true),
            Row(text: "Advanced", indent: indent, size: size),
            Row(text: "Remote cohort", indent: indent, size: size),
            Row(text: "Swift Basics – Example Academy (2022)", bold: true),
        ])
        #expect(result.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        #expect(result.cv.certifications.map { $0.description?.value } == ["Advanced\nRemote cohort", nil])
        #expect(result.unplaced.isEmpty)
        #expect(result.ungrounded.isEmpty)
    }

    // MARK: Anything else is a certification of its own

    @Test("A title with an address, in any wording, is a certification of its own", arguments: [
        "Swift Basics (2023) https://academy.example/swift", "Swift Basics 2023 https://academy.example/swift",
        "Swift Basics – academy.dev/swift", "Swift Basics: https://academy.example/swift", "Swift Basics | https://academy.example/swift",
        "Swift Basics, Example Academy https://academy.example/swift", "Example Academy https://academy.example/swift",
    ])
    func titledAddressIsAnEntry(line: String) throws {
        let found = read("Certifications\nFirst Certificate\n\(line)")
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.map { $0.link != nil } == [false, true])
        #expect(found.leftOut.isEmpty)
        #expect(found.unplaced.isEmpty)
    }

    @Test("In a PDF, the layout joins a line only to a title that states an issuer or a year: the titles indented under a group heading stay certifications")
    func layoutNeedsACompleteTitle() async throws {
        let result = try await importedPDF([
            Row(text: "Example Academy", bold: true),
            Row(text: "Swift Basics", indent: 12, size: 8.5),
            Row(text: "Advanced Swift", indent: 12, size: 8.5),
        ])
        #expect(result.cv.certifications.map(\.name.value) == ["Example Academy", "Swift Basics", "Advanced Swift"])
        #expect(result.cv.certifications.allSatisfy { $0.description == nil })
        #expect(result.unplaced.isEmpty)
    }

    @Test("A certification with an issuer or a date is a certification of its own, whatever its weight and its place", arguments: [
        "Swift Basics – Example Academy", "Swift Basics | Beispiel Institut", "AWS Certified Developer, Amazon Web Services, 2022", "Swift Basics (2023)",
    ])
    func issuerOrDateIsAnEntry(line: String) async throws {
        let found = read("Certifications\nFirst Certificate\n\(line)")
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
        #expect(found.unplaced.isEmpty)

        // Under a bold title, indented and smaller than it: the layout does not turn a certification into a detail
        let result = try await importedPDF([Row(text: "First Certificate", bold: true), Row(text: line, indent: 12, size: 8)])
        #expect(result.cv.certifications.count == 2)
        #expect(result.cv.certifications.allSatisfy { $0.description == nil })
        #expect(result.unplaced.isEmpty)
    }

    @Test("In a PDF, a bold line, a line after a gap and a line of a bullet list are not details, however they are laid out")
    func layoutIsNotEnough() async throws {
        let bold = try await importedPDF([Row(text: "First Certificate", bold: true), Row(text: "Swift Basics", indent: 12, bold: true)])
        #expect(bold.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])

        let afterGap = try await importedPDF([Row(text: "First Certificate", bold: true), Row(text: "Swift Basics", indent: 12, size: 8, gap: true)])
        #expect(afterGap.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])

        let bullets = try await importedPDF([Row(text: "• First Certificate", bold: true), Row(text: "• Swift Basics", indent: 12, size: 8)])
        #expect(bullets.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        for result in [bold, afterGap, bullets] {
            #expect(result.cv.certifications.allSatisfy { $0.description == nil })
            #expect(result.unplaced.isEmpty)
        }
    }

    @Test("In a PDF, a regular line under a bold title is no description by its weight: it is a certification of its own, to check")
    func weightAloneIsNotEnough() async throws {
        let result = try await importedPDF([
            Row(text: "First Certificate", bold: true),
            Row(text: "Advanced"),
            Row(text: "Swift Basics – Example Academy (2022)", bold: true),
        ])
        #expect(result.cv.certifications.map(\.name.value) == ["First Certificate", "Advanced", "Swift Basics"])
        #expect(result.cv.certifications.map { $0.description == nil } == [true, true, true])
        #expect(result.cv.certifications.map(\.name.check) == [nil, .certificationOrDetail, nil])
        #expect(result.reviewList.map(\.field) == [.certification(1)])
        #expect(result.reviewList.map(\.reason) == [.certificationOrDetail])
        #expect(result.reviewList.map(\.text) == ["Advanced"])
        #expect(result.unplaced.isEmpty)
    }

    @Test("In bold Markdown, a regular line under a bold title is a certification of its own, to check")
    func weightInMarkdown() throws {
        let found = read("Certifications\n**First Certificate**\nAdvanced")
        #expect(found.cv.certifications.map(\.name.value) == ["First Certificate", "Advanced"])
        #expect(found.cv.certifications.map(\.name.check) == [nil, .certificationOrDetail])
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
    }

    @Test("Plain lines stay one certification each, and none is to check: a line is a description only when it reads as a sentence")
    func plainLinesStayEntries() throws {
        let found = read("""
        Certifications
        BLSD – Croce Rossa Italiana (2021)
        Corso di primo soccorso
        Patente nautica
        """)
        #expect(found.cv.certifications.map(\.name.value) == ["BLSD", "Corso di primo soccorso", "Patente nautica"])
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
        #expect(found.cv.certifications.allSatisfy { $0.name.check == nil })
        #expect(found.unplaced.isEmpty)
    }

    @Test("A sentence is a description only of a certification that is not a sentence itself, with no date and no gap before it; otherwise it is a certification to check")
    func sentenceNeedsClearEvidence() throws {
        // A list of sentences is a list: none goes on with the one before
        let sentences = read("""
        Certifications
        Completed the swift basics course at the academy.
        Completed the advanced course at the academy.
        """)
        #expect(sentences.cv.certifications.count == 2)
        #expect(sentences.cv.certifications.allSatisfy { $0.description == nil })
        #expect(sentences.cv.certifications.map(\.name.check) == [nil, .certificationOrDetail])

        // A dated sentence is not a detail
        let dated = read("Certifications\nFirst Certificate – Example Academy (2023)\nPassed the final exam of the course in March 2024.")
        #expect(dated.cv.certifications.count == 2)
        #expect(dated.cv.certifications.allSatisfy { $0.description == nil })
        #expect(dated.cv.certifications.map(\.name.check) == [nil, .certificationOrDetail])

        // A sentence after a blank line is a paragraph of its own
        let afterGap = read("Certifications\nFirst Certificate – Example Academy (2023)\n\nCovers actors and structured concurrency in depth.")
        #expect(afterGap.cv.certifications.map(\.name.value) == ["First Certificate", "Covers actors and structured concurrency in depth."])
        #expect(afterGap.cv.certifications.allSatisfy { $0.description == nil })
        #expect(afterGap.cv.certifications.map(\.name.check) == [nil, .certificationOrDetail])

        // A bullet is an item of its own
        let bullet = read("Certifications\nFirst Certificate – Example Academy (2023)\n- Covers actors and structured concurrency in depth.")
        #expect(bullet.cv.certifications.count == 2)
        #expect(bullet.cv.certifications.allSatisfy { $0.description == nil })
        #expect(bullet.cv.certifications.map(\.name.check) == [nil, nil])
        for found in [sentences, dated, afterGap, bullet] { #expect(found.unplaced.isEmpty) }
    }

    @Test("A sentence that is a certification of its own is kept whole: no date, comma or address cuts it into a title and an issuer")
    func sentenceEntryIsKeptWhole() throws {
        let found = read("""
        Certifications
        First Certificate – Example Academy (2023)
        Completed in 2023 with distinction, at the academy.
        Issued by the academy, valid for two years.
        """)
        #expect(found.cv.certifications.map(\.name.value) == [
            "First Certificate", "Completed in 2023 with distinction, at the academy.", "Issued by the academy, valid for two years.",
        ])
        #expect(found.cv.certifications.dropFirst().allSatisfy { $0.issuer == nil && $0.year == nil && $0.link == nil && $0.description == nil })
        #expect(found.cv.certifications.map(\.name.check) == [nil, .certificationOrDetail, .certificationOrDetail])
        #expect(found.unplaced.isEmpty)
    }

    @Test("A sentence under a bullet that is itself a sentence is a certification to check, not its description")
    func sentenceUnderASentenceBullet() throws {
        let found = read("""
        Certifications
        - Completed the swift basics course at the academy.
        Covers actors and structured concurrency in depth.
        """)
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
        #expect(found.cv.certifications.map(\.name.check) == [nil, .certificationOrDetail])
        #expect(found.unplaced.isEmpty)
    }

    @Test("A Markdown link is a title with its address, or the label of the link above: split rather than merge")
    func markdownLinks() throws {
        let titled = read("Certifications\n- First Certificate – Example Academy (2023)\n- [Swift Basics](https://academy.example/swift)")
        #expect(titled.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        #expect(titled.cv.certifications.map { $0.link?.value.value } == [nil, "https://academy.example/swift"])

        let labelled = read("Certifications\n- First Certificate – Example Academy (2023)\n- [Verify](https://academy.example/swift)")
        #expect(labelled.cv.certifications.map(\.name.value) == ["First Certificate"])
        #expect(labelled.cv.certifications.first?.link?.value.value == "https://academy.example/swift")
    }

    @Test("A line the rules cannot place is never lost: it stays visible as text not imported, and nothing is carried over it")
    func nothingIsLost() throws {
        let found = read("""
        Certifications
        First Certificate – Example Academy (2023)
        2024
        https://academy.example/achievement
        Covers actors and structured concurrency in depth.
        """)
        // A line with only a date has no title: it is not imported, and the lines after it join nothing before it
        #expect(found.unplaced.map(\.text).first == "2024")
        #expect(found.cv.certifications.first?.link == nil)
        #expect(found.cv.certifications.first?.description == nil)
        #expect(found.unplaced.map(\.text).contains("https://academy.example/achievement"))
        #expect(found.cv.certifications.map(\.name.value) == ["First Certificate", "Covers actors and structured concurrency in depth."])
    }

    // MARK: The gate

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
