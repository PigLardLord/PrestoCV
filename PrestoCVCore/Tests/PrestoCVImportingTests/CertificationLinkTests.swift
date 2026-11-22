import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// A certification's link and description (#283, ADR 0027). The rule is to split rather than merge: a line goes on with
/// the certification above it only on clear evidence, and anything else starts a certification of its own or stays in
/// the text not imported, because a wrong split shows on screen and a wrong merge loses a certification without a word.
/// Every value here is invented.
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

    private func imported(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
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
        try await importedPDF { sketch in
            sketch.put("Certifications", x: 46, y: 130, size: 11, bold: true)
            var y = 150.0
            for row in rows {
                if row.gap { y += 12 }
                sketch.put(row.text, x: 46 + row.indent, y: y, size: row.size, bold: row.bold)
                y += 14
            }
        }
    }

    /// A PDF page with a name and a role at the top, and what `place` puts under them.
    private func importedPDF(_ place: (inout PageSketch) -> Void) async throws -> ImportResult {
        var sketch = PageSketch()
        sketch.put("Lena Marsh", x: 46, y: 50, size: 20, bold: true)
        sketch.put("iOS Developer", x: 46, y: 80)
        place(&sketch)
        return try await ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([sketch.page])), limits: .standard).importPDF(Data([1]))
    }

    // MARK: The four counterexamples of the reviews

    @Test("A title with its address, under another certification, is a certification of its own with the address as its link")
    func titleWithAddress() {
        let found = read("Certifications\nFirst Certificate\nSwift Basics \(address)")
        #expect(found.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        #expect(found.cv.certifications.map { $0.link?.value.value } == [nil, address])
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
        #expect(found.unplaced.isEmpty)
        #expect(found.leftOut.isEmpty)
    }

    @Test("A bare noun with an address is no label of the link: it is a certification of its own", arguments: [
        "Certificate", "Certificate:", "Badge", "Digital", "Credential", "Certificato", "Zertifikat", "Certificado", "Attestation", "Details",
        "Online", "Website",
    ])
    func bareNounWithAddress(noun: String) {
        let found = read("Certifications\nFirst Certificate\n\(noun) https://academy.example/c/123")
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.map { $0.link?.value.value } == [nil, "https://academy.example/c/123"])
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

    @Test("A title with its issuer that ends with a full stop is a certification of its own, not the description above (the trap of the second attempt)", arguments: [
        "Swift Basics, Beispiel Institut.", "Swift Basics, Example Academy.", "Swift basics course, Example Academy.",
        "Introduction to cloud security, Example Academy.", "Einführung in die sichere Entwicklung, Beispiel Institut.",
    ])
    func titleAndIssuerSentence(line: String) {
        let found = read("Certifications\nFirst Certificate – Example Academy (2023)\n\(line)")
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.map { $0.description == nil } == [true, true])
        #expect(found.cv.certifications.last?.issuer != nil)
        #expect(found.cv.certifications.map(\.check) == [nil, nil])
        #expect(found.unplaced.isEmpty)
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
    func punctuationAroundAnAddress(line: String) {
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
        "Credential URL: https://academy.example/c/123", "Link: https://academy.example/c/123", "Verify https://academy.example/c/123",
        "View certificate: https://academy.example/c/123", "https://academy.example/c/123 (link)",
        "Verifica online: https://academy.example/c/123", "Maggiori informazioni: https://academy.example/c/123",
        "Zertifikatslink https://academy.example/c/123", "Überprüfen: https://academy.example/c/123",
        "Enlace: https://academy.example/c/123", "Verificar https://academy.example/c/123",
        "Lien : https://academy.example/c/123", "Vérifier : https://academy.example/c/123",
        "Verificação: https://academy.example/c/123", "Mais informações: https://academy.example/c/123",
    ])
    func labelledAddress(line: String) throws {
        let found = read("Certifications\nSwift Basics – Example Academy, 2023\n\(line)")
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.link?.value.value == "https://academy.example/c/123")
        #expect(found.leftOut.map(\.reason) == [.categoryLabel])
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

    @Test("The label of a link inside the line of a title is left out, not read as the issuer", arguments: [
        ("Swift Basics – Verify: https://academy.example/swift", nil as String?),
        ("Swift Basics https://academy.example/swift (link)", nil),
        ("Swift Basics (2023) – Credential URL: https://academy.example/swift", nil),
        ("Verify – Swift Basics https://academy.example/swift", nil),
        ("Swift Basics – Example Academy – Verifica online: https://academy.example/swift", "Example Academy"),
    ])
    func labelInTheTitleLine(line: String, issuer: String?) throws {
        let found = read("Certifications\n\(line)")
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.name.value == "Swift Basics")
        #expect(certification.issuer?.value == issuer)
        #expect(certification.link?.value.value == "https://academy.example/swift")
        #expect(found.leftOut.map(\.reason) == [.categoryLabel])
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
    func addressWithNoCertification() {
        let found = read("Certifications\nhttps://academy.example/achievement\nSwift Basics – Example Academy (2023)")
        #expect(found.cv.certifications.map(\.name.value) == ["Swift Basics"])
        #expect(found.cv.certifications.first?.link == nil)
        #expect(found.unplaced.map(\.text) == ["https://academy.example/achievement"])
    }

    @Test("A bullet that holds only a web address is the link of the certification above it")
    func addressInABullet() {
        let found = read("Certifications\n- Swift Basics – Example Academy (2023)\n- https://academy.example/achievement")
        #expect(found.cv.certifications.count == 1)
        #expect(found.cv.certifications.first?.link?.value.value == "https://academy.example/achievement")
        #expect(found.unplaced.isEmpty)
    }

    @Test("A certification whose issuer a lead line names below it keeps the link under that line")
    func linkUnderTheIssuerLine() throws {
        let found = read("Certifications\nSwift Basics\nIssued by Example Academy\nhttps://academy.example/swift")
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.issuer?.value == "Example Academy")
        #expect(certification.link?.value.value == "https://academy.example/swift")
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
        // Only the words of the lines placed them there, no layout: the person checks the certification
        #expect(certification.check == .descriptionOrEntryUnsure)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A link and a description of two lines land in the fields of the certification before them")
    func linkAndDescription() {
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
        #expect(found.cv.certifications.map(\.check) == [.descriptionOrEntryUnsure, nil])
        #expect(found.unplaced.isEmpty)
    }

    @Test("A sentence with a web address is no description: it is a certification of its own, with the address as its link")
    func sentenceWithAddress() throws {
        let found = read("""
        Certifications
        First Certificate – Example Academy (2023)
        See the syllabus at \(longAddress) for the full list of topics.
        """)
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.map { $0.link?.value.value } == [nil, longAddress])
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
        #expect(found.cv.certifications.map(\.check) == [nil, .descriptionOrEntryUnsure])
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
        // Neither indented nor smaller: only the words placed the lines there, so the person checks the certification
        #expect(result.cv.certifications.map(\.check) == [.descriptionOrEntryUnsure, nil])
        #expect(checked(result).map(\.field) == [.certification(0)])
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
        #expect(result.cv.certifications.allSatisfy { $0.check == nil })
        #expect(result.unplaced.isEmpty)
        #expect(result.ungrounded.isEmpty)
    }

    // MARK: Anything else is a certification of its own

    @Test("A title with an address, in any wording, is a certification of its own", arguments: [
        "Swift Basics (2023) https://academy.example/swift", "Swift Basics 2023 https://academy.example/swift",
        "Swift Basics – academy.dev/swift", "Swift Basics: https://academy.example/swift", "Swift Basics | https://academy.example/swift",
        "Swift Basics, Example Academy https://academy.example/swift", "Example Academy https://academy.example/swift",
    ])
    func titledAddressIsAnEntry(line: String) {
        let found = read("Certifications\nFirst Certificate\n\(line)")
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.map { $0.link != nil } == [false, true])
        #expect(found.leftOut.isEmpty)
        #expect(found.unplaced.isEmpty)
    }

    // MARK: Evidence of a certification of its own beats every rule that joins a line to the one above

    /// Lines that read as a certification of their own: a title with its issuer, the issuer first, a date, a sentence-shaped
    /// title with its issuer, and one with a date.
    private static let entryEvidence = [
        "Swift Basics – Example Academy", "Example Academy – Swift Basics", "Swift Basics (2023)",
        "Certificate in practical cloud security — Example Academy.", "Example Academy — certificate in practical cloud security.",
        "Certificate in practical cloud security — 2023.", "Certificate in practical cloud security - Example Academy.",
        "Example Academy - certificate in practical cloud security.", "Certificate in practical cloud security, Example Academy.",
    ]

    @Test("A line with the evidence of a certification of its own is never the description of the one above, nor is its address", arguments: entryEvidence)
    func entryEvidenceBeatsTheSentenceRule(line: String) {
        let found = read("Certifications\nFirst Certificate\n\(line)\nhttps://academy.example/security")
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
        #expect(found.cv.certifications.map { $0.link?.value.value } == [nil, "https://academy.example/security"])
        #expect(found.unplaced.isEmpty)
    }

    @Test("In a PDF, a line with the evidence of a certification of its own is not placed under the one above by its layout", arguments: entryEvidence + [
        "Example Academy", "Swift Basics https://academy.example/security", "Level 2, Remote",
    ])
    func entryEvidenceBeatsTheLayoutRule(line: String) async throws {
        for (indent, size) in [(8.0, 9.5), (0.0, 8.0)] {
            for bold in [false, true] {
                let result = try await importedPDF([
                    Row(text: "First Certificate (2023)", bold: bold),
                    Row(text: line, indent: indent, size: size),
                ])
                #expect(result.cv.certifications.count == 2, "\(line), indent \(indent), size \(size), bold \(bold)")
                #expect(result.cv.certifications.allSatisfy { $0.description == nil })
                #expect(result.cv.certifications.first?.link == nil)
                #expect(result.ungrounded.isEmpty)
            }
        }
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
        let bold = try await importedPDF([Row(text: "First Certificate (2023)", bold: true), Row(text: "Swift Basics", indent: 12, bold: true)])
        #expect(bold.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])

        let afterGap = try await importedPDF([Row(text: "First Certificate (2023)", bold: true), Row(text: "Swift Basics", indent: 12, size: 8, gap: true)])
        #expect(afterGap.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])

        let bullets = try await importedPDF([Row(text: "• First Certificate (2023)", bold: true), Row(text: "• Swift Basics", indent: 12, size: 8)])
        #expect(bullets.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        for result in [bold, afterGap, bullets] {
            #expect(result.cv.certifications.allSatisfy { $0.description == nil })
            #expect(result.unplaced.isEmpty)
        }
    }

    @Test("In a PDF, a regular line under a bold title is no description by its weight: it is a certification of its own")
    func weightAloneIsNotEnough() async throws {
        let result = try await importedPDF([
            Row(text: "First Certificate", bold: true),
            Row(text: "Advanced"),
            Row(text: "Swift Basics – Example Academy (2022)", bold: true),
        ])
        #expect(result.cv.certifications.map(\.name.value) == ["First Certificate", "Advanced", "Swift Basics"])
        #expect(result.cv.certifications.map { $0.description == nil } == [true, true, true])
        #expect(result.unplaced.isEmpty)
    }

    @Test("In bold Markdown, a regular line under a bold title is a certification of its own")
    func weightInMarkdown() {
        let found = read("Certifications\n**First Certificate**\nAdvanced")
        #expect(found.cv.certifications.map(\.name.value) == ["First Certificate", "Advanced"])
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
    }

    @Test("Plain lines stay one certification each: a line is a description only when it reads as a sentence")
    func plainLinesStayEntries() {
        let found = read("""
        Certifications
        BLSD – Croce Rossa Italiana (2021)
        Corso di primo soccorso
        Patente nautica
        """)
        #expect(found.cv.certifications.map(\.name.value) == ["BLSD", "Corso di primo soccorso", "Patente nautica"])
        #expect(found.cv.certifications.allSatisfy { $0.description == nil })
        #expect(found.cv.certifications.allSatisfy { $0.check == nil })
        #expect(found.unplaced.isEmpty)
    }

    @Test("A sentence is a description only of a certification that is not a sentence itself, with no date and no gap before it; otherwise it is a certification of its own")
    func sentenceNeedsClearEvidence() {
        // A list of sentences is a list: none goes on with the one before
        let sentences = read("""
        Certifications
        Completed the swift basics course at the academy.
        Completed the advanced course at the academy.
        """)
        #expect(sentences.cv.certifications.count == 2)

        // A dated sentence is not a detail
        let dated = read("Certifications\nFirst Certificate – Example Academy (2023)\nPassed the final exam of the course in March 2024.")
        #expect(dated.cv.certifications.count == 2)

        // A sentence after a blank line is a paragraph of its own
        let afterGap = read("Certifications\nFirst Certificate – Example Academy (2023)\n\nCovers actors and structured concurrency in depth.")
        #expect(afterGap.cv.certifications.map(\.name.value) == ["First Certificate", "Covers actors and structured concurrency in depth."])

        // A bullet is an item of its own
        let bullet = read("Certifications\nFirst Certificate – Example Academy (2023)\n- Covers actors and structured concurrency in depth.")
        #expect(bullet.cv.certifications.count == 2)

        // A sentence under a bullet that is itself a sentence is an item of its own too
        let underASentence = read("Certifications\n- Completed the swift basics course at the academy.\nCovers actors and structured concurrency in depth.")
        #expect(underASentence.cv.certifications.count == 2)
        for found in [sentences, dated, afterGap, bullet, underASentence] {
            #expect(found.cv.certifications.allSatisfy { $0.description == nil })
            #expect(found.unplaced.isEmpty)
        }

        // A sentence under a title that reads as a description, split off only by its date, its gap or its marker, is
        // in doubt: the person checks it. A list of sentences is no doubt.
        for found in [dated, afterGap, bullet] {
            #expect(found.cv.certifications.map(\.check) == [nil, .descriptionOrEntryUnsure])
        }
        for found in [sentences, underASentence] {
            #expect(found.cv.certifications.map(\.check) == [nil, nil])
        }
    }

    // MARK: In doubt, the person checks the certification

    /// The certifications the review list asks the person to check.
    private func checked(_ result: ImportResult) -> [ReviewItem] {
        result.reviewList.filter { item in
            if case .certification = item.field { return true }
            return false
        }
    }

    @Test("A sentence under a bare title stays its description, but only its words placed it there: the person checks the certification", arguments: [
        ("First Certificate", "Introduction to machine learning."),
        ("Erstes Zertifikat", "Einführung in das maschinelle Lernen."),
        ("Primo Certificato", "Introduzione al machine learning."),
    ])
    func sentenceShapeAloneIsChecked(title: String, line: String) throws {
        let result = try imported("Certifications\n\(title)\n\(line)")
        let certification = try #require(result.cv.certifications.first)
        #expect(result.cv.certifications.count == 1)
        #expect(certification.name.value == title)
        #expect(certification.description?.value == line)
        #expect(certification.check == .descriptionOrEntryUnsure)
        #expect(checked(result) == [ReviewItem(field: .certification(0), reason: .descriptionOrEntryUnsure, text: title)])
        #expect(result.unplaced.isEmpty)
        #expect(result.ungrounded.isEmpty)
        #expect(Coverage.lost(result).isEmpty)
    }

    @Test("In a PDF, a sentence the layout places under the title, indented or smaller, is its description with nothing to check", arguments: [
        "Introduction to machine learning.", "Einführung in das maschinelle Lernen.", "Introduzione al machine learning.",
    ])
    func laidOutSentenceIsNotChecked(line: String) async throws {
        for title in ["First Certificate", "First Certificate – Example Academy (2023)"] {
            for (indent, size) in [(6.0, 9.5), (0.0, 8.0)] {
                let result = try await importedPDF([Row(text: title, bold: true), Row(text: line, indent: indent, size: size)])
                #expect(result.cv.certifications.map(\.name.value) == ["First Certificate"], "\(title), indent \(indent), size \(size)")
                #expect(result.cv.certifications.first?.description?.value == line)
                #expect(result.cv.certifications.first?.check == nil)
                #expect(checked(result).isEmpty)
                #expect(result.unplaced.isEmpty)
                #expect(result.ungrounded.isEmpty)
            }
        }
    }

    @Test("In a PDF, an indented sentence with a comma is the description, but only its words made it one text: the person checks the certification", arguments: [
        "Covers Swift, testing and deployment.", "Behandelt Swift, das Testen und die Auslieferung.", "Tratta Swift, i test e il rilascio.",
    ])
    func laidOutSentenceWithACommaIsChecked(line: String) async throws {
        for title in ["First Certificate", "First Certificate – Example Academy (2023)"] {
            for (indent, size) in [(6.0, 9.5), (0.0, 8.0)] {
                let result = try await importedPDF([Row(text: title, bold: true), Row(text: line, indent: indent, size: size)])
                #expect(result.cv.certifications.map(\.name.value) == ["First Certificate"], "\(title), indent \(indent), size \(size)")
                #expect(result.cv.certifications.first?.description?.value == line)
                #expect(result.cv.certifications.first?.check == .descriptionOrEntryUnsure, "\(title), indent \(indent), size \(size)")
                #expect(checked(result).map(\.field) == [.certification(0)])
                #expect(result.unplaced.isEmpty)
                #expect(result.ungrounded.isEmpty)
            }
        }
    }

    @Test("In a PDF, an indented line the reader cuts, its later part in lower case, is a certification of its own, and the person checks it", arguments: [
        ("First Certificate – Example Academy (2023)", "Swift Basics, remote", "Swift Basics"),
        ("First Certificate – Example Academy (2023)", "Swift Basics – online", "Swift Basics"),
        ("First Certificate – Example Academy (2023)", "Swift Basics - online", "Swift Basics"),
        ("First Certificate – Example Academy (2023)", "Managing Anxiety, Stress, Sleep", "Managing Anxiety, Stress, Sleep"),
        ("Erstes Zertifikat – Beispiel Akademie (2023)", "Swift-Grundlagen, berufsbegleitend", "Swift-Grundlagen"),
        ("Primo Certificato – Accademia Esempio (2023)", "Fondamenti di Swift, da remoto", "Fondamenti di Swift"),
    ])
    func laidOutCutLineIsChecked(title: String, line: String, name: String) async throws {
        for (indent, size) in [(8.0, 9.5), (0.0, 8.0)] {
            for bold in [false, true] {
                let result = try await importedPDF([Row(text: title, bold: bold), Row(text: line, indent: indent, size: size)])
                let layout = "\(line), indent \(indent), size \(size), bold \(bold)"
                #expect(result.cv.certifications.count == 2, "\(layout)")
                #expect(result.cv.certifications.last?.name.value == name, "\(layout)")
                #expect(result.cv.certifications.allSatisfy { $0.description == nil }, "\(layout)")
                #expect(result.cv.certifications.map(\.check) == [nil, .descriptionOrEntryUnsure], "\(layout)")
                #expect(checked(result).map(\.field) == [.certification(1)], "\(layout)")
                #expect(result.ungrounded.isEmpty)
                #expect(Coverage.lost(result).isEmpty)
            }
        }
    }

    /// The heading, then a certification whose line starts with its date: in a rail of its own, close enough to join the
    /// line, or in the same words. Then `line` under the certification's name.
    private func importedUnderADatedTitle(dateApart: Bool, line: String) async throws -> ImportResult {
        try await importedPDF { sketch in
            sketch.put("Certifications", x: 46, y: 130, size: 11, bold: true)
            if dateApart {
                sketch.put("2023", x: 46, y: 150)
                sketch.put("First Certificate – Example Academy", x: 76, y: 150)
            } else {
                sketch.put("2023 First Certificate – Example Academy", x: 46, y: 150)
            }
            sketch.put(line, x: dateApart ? 76 : 68, y: 164)
        }
    }

    @Test("In a PDF, a title line that starts with its date tells nothing of where the name stands: a plain line under the name is a certification of its own", arguments: [
        true, false,
    ])
    func lineUnderADatedTitle(dateApart: Bool) async throws {
        let result = try await importedUnderADatedTitle(dateApart: dateApart, line: "Swift Basics")
        #expect(result.cv.certifications.map(\.name.value) == ["First Certificate", "Swift Basics"])
        #expect(result.cv.certifications.allSatisfy { $0.description == nil })
        #expect(result.cv.certifications.first?.year?.value == 2023)
        #expect(result.ungrounded.isEmpty)
        #expect(Coverage.lost(result).isEmpty)
    }

    @Test("In a PDF, a sentence under the name of a title line that starts with its date is its description by its words only: the person checks the certification", arguments: [
        true, false,
    ])
    func sentenceUnderADatedTitle(dateApart: Bool) async throws {
        let result = try await importedUnderADatedTitle(dateApart: dateApart, line: "Introduction to machine learning.")
        #expect(result.cv.certifications.map(\.name.value) == ["First Certificate"])
        #expect(result.cv.certifications.first?.description?.value == "Introduction to machine learning.")
        #expect(result.cv.certifications.first?.check == .descriptionOrEntryUnsure)
        #expect(checked(result).map(\.field) == [.certification(0)])
        #expect(result.ungrounded.isEmpty)
    }

    @Test("In a PDF, a title on the line of the heading stands where the heading does: a plain line under its name is a certification of its own", arguments: [
        11.0, 9.5,
    ])
    func lineUnderATitleBesideTheHeading(headingSize: Double) async throws {
        let result = try await importedPDF { sketch in
            sketch.put("Certifications", x: 46, y: 150, size: headingSize, bold: true)
            sketch.put("First Certificate – Example Academy (2023)", x: 140, y: 150)
            sketch.put("Swift Basics", x: 140, y: 164)
            sketch.put("Advanced Swift", x: 140, y: 178)
        }
        #expect(result.cv.certifications.first?.name.value == "First Certificate")
        #expect(result.cv.certifications.last?.name.value == "Advanced Swift")
        #expect(result.cv.certifications.allSatisfy { $0.description == nil })
        #expect(result.ungrounded.isEmpty)
        #expect(Coverage.lost(result).isEmpty)
    }

    /// A summary as wide as the page, then certifications whose dates stand in a column of their own, on the left or on
    /// the right, on the baseline of the title, one row every `pitch` points.
    private func importedWithADateColumn(_ titles: [String], dateLeft: Bool, dateSize: Double, pitch: Double) async throws -> ImportResult {
        try await importedPDF { sketch in
            sketch.put("Summary", x: 46, y: 110, size: 11, bold: true)
            sketch.put("Developer with eight years of experience building mobile apps for banks, shops and public services", x: 46, y: 128, size: 9.5)
            sketch.put("Leads small teams, writes clear code and tests, and works closely with designers and product owners", x: 46, y: 142, size: 9.5)
            sketch.put("Certifications", x: 46, y: 170, size: 11, bold: true)
            for (index, title) in titles.enumerated() {
                let y = 190 + Double(index) * pitch
                sketch.put(title, x: dateLeft ? 90 : 46, y: y, size: 9.5, bold: true)
                sketch.put("\(2021 + index)", x: dateLeft ? 46 : 480, y: y + 9.5 - dateSize, size: dateSize)
            }
        }
    }

    @Test("In a PDF, a date in a column of its own keeps the row of its title: the next certification set solid under it is a certification of its own", arguments: [
        ["First Certificate", "Swift Basics", "Advanced Swift"],
        ["Erstes Zertifikat", "Swift-Grundlagen", "Fortgeschrittenes Swift"],
        ["Primo Certificato", "Fondamenti di Swift", "Swift Avanzato"],
    ])
    func dateColumnKeepsTheRow(titles: [String]) async throws {
        // Set solid (the rows as far apart as the font is large) and single-spaced, the date as large as the title or
        // larger: the page analysis joins two rows only when they share half the height of the smaller, drawn on each other
        for dateLeft in [true, false] {
            for dateSize in [9.5, 12] {
                for pitch in [9.5, 11.4] {
                    let result = try await importedWithADateColumn(titles, dateLeft: dateLeft, dateSize: dateSize, pitch: pitch)
                    let layout = "date left \(dateLeft), date size \(dateSize), pitch \(pitch)"
                    #expect(result.cv.certifications.map(\.name.value) == titles, "\(layout)")
                    #expect(result.cv.certifications.map { $0.year?.value } == [2021, 2022, 2023], "\(layout)")
                    #expect(result.cv.certifications.allSatisfy { $0.issuer == nil && $0.description == nil && $0.check == nil }, "\(layout)")
                    #expect(result.unplaced.isEmpty, "\(layout)")
                    #expect(result.ungrounded.isEmpty)
                    #expect(Coverage.lost(result).isEmpty, "\(layout)")
                }
            }
        }
    }

    @Test("A sentence with commas under a certification is its description: a comma before words in lower case names no issuer", arguments: [
        "Covers Swift, testing and deployment.", "Behandelt Swift, das Testen und die Auslieferung.", "Tratta Swift, i test e il rilascio.",
    ])
    func commaInASentence(line: String) throws {
        let result = try imported("Certifications\nFirst Certificate – Example Academy (2023)\n\(line)")
        let certification = try #require(result.cv.certifications.first)
        #expect(result.cv.certifications.count == 1)
        #expect(certification.issuer?.value == "Example Academy")
        #expect(certification.description?.value == line)
        // No layout placed it, only its words
        #expect(certification.check == .descriptionOrEntryUnsure)
        #expect(result.unplaced.isEmpty)
        #expect(result.ungrounded.isEmpty)
        #expect(Coverage.lost(result).isEmpty)
    }

    @Test("A sentence that reads as neither a clear description nor a clear title is a certification of its own, and the person checks it", arguments: [
        "Includes exercises on AWS, Azure.", "Umfasst die Übungen mit AWS, Azure.",
    ])
    func neitherDescriptionNorTitleIsChecked(line: String) throws {
        let result = try imported("Certifications\nFirst Certificate – Example Academy (2023)\n\(line)")
        #expect(result.cv.certifications.count == 2)
        #expect(result.cv.certifications.allSatisfy { $0.description == nil })
        #expect(result.cv.certifications.map(\.check) == [nil, .descriptionOrEntryUnsure])
        #expect(checked(result).map(\.field) == [.certification(1)])
        #expect(result.ungrounded.isEmpty)
        #expect(Coverage.lost(result).isEmpty)
    }

    @Test("A sentence with a web address is a certification of its own with the address as its link, and the person checks it", arguments: [
        "The full syllabus is at https://academy.example/syllabus.",
        "Il programma completo è su https://academy.example/programma con tutti gli argomenti.",
    ])
    func sentenceWithAddressIsChecked(line: String) throws {
        let result = try imported("Certifications\nFirst Certificate – Example Academy (2023)\n\(line)")
        #expect(result.cv.certifications.count == 2)
        #expect(result.cv.certifications.map { $0.link == nil } == [true, false])
        #expect(result.cv.certifications.allSatisfy { $0.description == nil })
        #expect(result.cv.certifications.map(\.check) == [nil, .descriptionOrEntryUnsure])
        #expect(checked(result).map(\.field) == [.certification(1)])
        #expect(result.ungrounded.isEmpty)
        #expect(Coverage.lost(result).isEmpty)
    }

    // MARK: In doubt, nothing is lost

    @Test("A line the rules cannot place is never lost: it stays visible as text not imported, and nothing is carried over it")
    func nothingIsCarriedOverAnUnplacedLine() {
        let found = read("""
        Certifications
        First Certificate – Example Academy (2023)
        2024
        https://academy.example/achievement
        Covers actors and structured concurrency in depth.
        """)
        // A line with only a date has no title: it is not imported, and the lines after it join nothing before it
        #expect(found.unplaced.map(\.text) == ["2024", "https://academy.example/achievement"])
        #expect(found.cv.certifications.first?.link == nil)
        #expect(found.cv.certifications.first?.description == nil)
        #expect(found.cv.certifications.map(\.name.value) == ["First Certificate", "Covers actors and structured concurrency in depth."])
    }

    @Test("Through the whole import, every word of the certifications is a value, a label left out or text not imported")
    func nothingIsLostSilently() throws {
        let result = try imported("""
        Lena Marsh
        lena.marsh@example.com

        Certifications
        Advanced Swift Concurrency (Level 2) — Example Academy (2024)
        https://academy.example/achievement
        Covers actors and structured concurrency in depth.
        Swift Basics, Beispiel Institut.
        Verify: https://academy.example/c/123
        Certificate https://academy.example/c/456
        2024
        https://academy.example/orphan
        """)
        #expect(result.cv.certifications.map(\.name.value) == ["Advanced Swift Concurrency (Level 2)", "Swift Basics", "Certificate"])
        #expect(result.cv.certifications.map { $0.link?.value.value } == [
            "https://academy.example/achievement", "https://academy.example/c/123", "https://academy.example/c/456",
        ])
        #expect(result.cv.certifications.map { $0.description?.value } == ["Covers actors and structured concurrency in depth.", nil, nil])
        #expect(checked(result) == [
            ReviewItem(field: .certification(0), reason: .descriptionOrEntryUnsure, text: "Advanced Swift Concurrency (Level 2) — Example Academy"),
        ])
        #expect(result.unplaced.map(\.text) == ["2024", "https://academy.example/orphan"])
        #expect(result.ungrounded.isEmpty)
        #expect(Coverage.lost(result).isEmpty)
    }

    // MARK: The gate

    @Test("The gate refuses a link or a description that is not the text of its spans, and keeps that text visible")
    func gate() throws {
        var result = try imported("""
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
