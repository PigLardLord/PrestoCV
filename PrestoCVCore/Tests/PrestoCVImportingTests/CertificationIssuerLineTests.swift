import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// A certification written on two lines, its name and then an issuer line (#304). The rule is split rather than merge
/// (#283): only an explicit lead sets the issuer of the line above, anything else stays an entry of its own. Every value
/// here is invented (the corpus README).
@Suite("Reading a certification's issuer line")
struct CertificationIssuerLineTests {

    /// The lead words of each of the six languages, as a person types them.
    private static let leads: [(language: String, lead: String)] = [
        ("en", "Issued by"), ("en", "Offered by"), ("en", "Provided by"), ("en", "Awarded by"),
        ("it", "Rilasciato da"), ("it", "Rilasciata da"), ("it", "Emesso da"), ("it", "Offerto da"),
        ("de", "Ausgestellt von"), ("de", "Angeboten von"), ("de", "Verliehen von"),
        ("es", "Emitido por"), ("es", "Emitida por"), ("es", "Ofrecido por"), ("es", "Expedido por"),
        ("fr", "Délivré par"), ("fr", "Délivrée par"), ("fr", "Offert par"), ("fr", "Émis par"),
        ("pt", "Emitido pela"), ("pt", "Emitido pelo"), ("pt", "Emitido por"), ("pt", "Oferecido por"),
    ]

    private static let separators = CertificationReader.lineSeparators

    private func read(_ lines: [String]) -> Findings {
        let (document, sections) = pasted((["Certifications"] + lines).joined(separator: "\n"))
        var findings = Findings(document: document)
        for section in sections where section.kind == .certifications {
            CertificationReader.read(section, into: &findings)
        }
        return findings
    }

    // MARK: The issuer line attaches

    @Test("An issuer line sets the issuer and the year of the line above, for each lead", arguments: leads)
    func leadWords(language: String, lead: String) throws {
        let found = read(["First Aid Certificate", "\(lead) Red Cross, 2021"])
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1, "\(language)")
        #expect(certification.name.value == "First Aid Certificate")
        #expect(certification.issuer?.value == "Red Cross")
        #expect(certification.year?.value == 2021)
        #expect(found.unplaced.isEmpty)
    }

    @Test("An issuer line is read at every separator the reader splits at", arguments: separators)
    func separatorsOfTheLine(separator: String) throws {
        let found = read(["First Aid Certificate", "Issued by Red Cross\(separator)2021"])
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.issuer?.value == "Red Cross")
        #expect(certification.year?.value == 2021)
    }

    @Test("The lead is read in lower case and with a colon")
    func casing() throws {
        let found = read(["First Aid Certificate", "issued by: Red Cross, 2021"])
        #expect(found.cv.certifications.count == 1)
        #expect(found.cv.certifications.first?.issuer?.value == "Red Cross")
        #expect(found.cv.certifications.first?.year?.value == 2021)
    }

    @Test("Each certification takes its own issuer line, wherever it is in the list", arguments: [1, 2, 3])
    func position(count: Int) {
        var lines: [String] = []
        for index in 0..<count { lines += ["Course \(index)", "Issued by Safety Council \(index), 20\(10 + index)"] }
        let found = read(lines)
        #expect(found.cv.certifications.map(\.name.value) == (0..<count).map { "Course \($0)" })
        #expect(found.cv.certifications.map { $0.issuer?.value } == (0..<count).map { "Safety Council \($0)" })
        #expect(found.cv.certifications.map { $0.year?.value } == (0..<count).map { 2010 + $0 })
    }

    @Test("A certification with no issuer line stays between two that have one")
    func middleWithout() {
        let found = read(["First Aid Certificate", "Issued by Red Cross, 2021", "Forklift Licence", "Rigging Basics", "Offered by Safety Council, 2019"])
        #expect(found.cv.certifications.map(\.name.value) == ["First Aid Certificate", "Forklift Licence", "Rigging Basics"])
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["Red Cross", nil, "Safety Council"])
    }

    @Test("What follows the issuer on its line is text not imported, not a certification")
    func trailingWords() throws {
        let found = read(["Pool Safety Course", "Offered by Red Cross, focused on rescue basics"])
        #expect(found.cv.certifications.count == 1)
        #expect(found.cv.certifications.first?.issuer?.value == "Red Cross")
        #expect(found.unplaced.map(\.text) == ["focused on rescue basics"])
    }

    // MARK: A short name is not cut at its commas

    @Test("A short name with commas and no year or organisation after them stays whole")
    func commaName() throws {
        let found = read(["Managing Anxiety, Stress, Sleep Problems"])
        #expect(found.cv.certifications.map(\.name.value) == ["Managing Anxiety, Stress, Sleep Problems"])
        #expect(found.unplaced.isEmpty)
    }

    /// The separators that end the name before a later part: every one the reader cuts at, except the comma.
    private static let separatorsAfterTheName = CertificationReader.lineSeparators.filter { $0 != ", " }

    @Test("Only the name holds a list: a later part is cut at its commas, at every separator", arguments: separatorsAfterTheName)
    func laterPartCutAtCommas(separator: String) throws {
        let found = read(["First Aid\(separator)Acme Ltd, practical assessment, distinction"])
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.name.value == "First Aid")
        #expect(certification.issuer?.value == "Acme Ltd")
        #expect(found.unplaced.map(\.text) == ["practical assessment", "distinction"])
    }

    @Test("Only the name holds a list: a later cell of a table row is cut at its commas")
    func laterCellCutAtCommas() throws {
        let found = read(["| Name | Issuer |", "|---|---|", "| First Aid | Acme Ltd, practical assessment, distinction |"])
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.name.value == "First Aid")
        #expect(certification.issuer?.value == "Acme Ltd")
        #expect(found.unplaced.map(\.text) == ["practical assessment", "distinction"])
    }

    @Test("The name keeps its list when an issuer follows it")
    func nameListBeforeIssuer() throws {
        let found = read(["Managing Anxiety, Stress, Sleep Problems - Acme Ltd"])
        #expect(found.cv.certifications.map(\.name.value) == ["Managing Anxiety, Stress, Sleep Problems"])
        #expect(found.cv.certifications.first?.issuer?.value == "Acme Ltd")
        #expect(found.unplaced.isEmpty)
    }

    @Test("A comma that is followed by an organisation or a year still splits")
    func commaStillSplits() {
        let found = read(["Rescue Basics, Red Cross Society", "Rope Work, Safety, 2019"])
        #expect(found.cv.certifications.map(\.name.value) == ["Rescue Basics", "Rope Work"])
        #expect(found.cv.certifications.first?.issuer?.value == "Red Cross Society")
        #expect(found.cv.certifications.last?.year?.value == 2019)
    }

    // MARK: Anything else stays an entry (split rather than merge)

    @Test("A second certification that only contains the word by is its own entry")
    func containsBy() {
        let found = read(["First Aid Certificate", "Written by Hand Calligraphy", "Ideas Issued by Nobody"])
        #expect(found.cv.certifications.count == 3)
        #expect(found.cv.certifications.allSatisfy { $0.issuer == nil })
    }

    @Test("An issuer line with no certification above it is an entry of its own")
    func noCertificationAbove() {
        let found = read(["Issued by Red Cross, 2021"])
        #expect(found.cv.certifications.map(\.name.value) == ["Issued by Red Cross"])
        #expect(found.cv.certifications.first?.issuer == nil)
    }

    @Test("A line after a section heading does not join the entry before the heading")
    func afterHeading() {
        let (document, sections) = pasted("Certifications\nFirst Aid Certificate\nLanguages\nIssued by Red Cross, 2021\nCourses\nIssued by Safety Council")
        var findings = Findings(document: document)
        for section in sections where section.kind == .certifications { CertificationReader.read(section, into: &findings) }
        #expect(findings.cv.certifications.map(\.name.value) == ["First Aid Certificate", "Issued by Safety Council"])
        #expect(findings.cv.certifications.allSatisfy { $0.issuer == nil })
    }

    @Test("A second issuer line, or one that states a second year, does not overwrite the first")
    func noOverwrite() {
        let second = read(["First Aid Certificate", "Issued by Red Cross", "Issued by Safety Council"])
        #expect(second.cv.certifications.count == 2)
        #expect(second.cv.certifications.first?.issuer?.value == "Red Cross")
        let years = read(["First Aid Certificate 2020", "Issued by Red Cross, 2021"])
        #expect(years.cv.certifications.count == 2)
        #expect(years.cv.certifications.first?.year?.value == 2020)
    }

    @Test("A long sentence that starts with a lead is not an issuer: it is the description of the certification (#283)")
    func longSentence() {
        let sentence = "Issued by the committee after a long review of the written and practical exams that candidates sat in spring and autumn of the year."
        let found = read(["First Aid Certificate", sentence])
        #expect(found.cv.certifications.count == 1)
        #expect(found.cv.certifications.first?.issuer == nil)
        #expect(found.cv.certifications.first?.description?.value == sentence)
    }

    @Test("A lead with nothing after it is not an issuer")
    func bareLead() {
        let found = read(["First Aid Certificate", "Issued by"])
        #expect(found.cv.certifications.count == 2)
    }

    // MARK: An issuer line is cut at every comma

    @Test("A line that starts with a lead never keeps its commas whole: the first part is the issuer, the rest is not imported")
    func leadLineCutAtCommas() {
        let three = read(["Python Basics", "Offered by Example Online, focused on Python, Data"])
        #expect(three.cv.certifications.count == 1)
        #expect(three.cv.certifications.first?.issuer?.value == "Example Online")
        #expect(three.unplaced.map(\.text) == ["focused on Python", "Data"])
        let four = read(["Python Basics", "Offered by Example Online, focused on Python, Data, Notebooks"])
        #expect(four.cv.certifications.count == 1)
        #expect(four.cv.certifications.first?.issuer?.value == "Example Online")
        #expect(four.unplaced.map(\.text) == ["focused on Python", "Data", "Notebooks"])
    }

    // MARK: Contracted leads

    private static let contracted: [String] = [
        "Rilasciato dal", "Rilasciata dalla", "Rilasciato dallo", "Rilasciato dall'", "Rilasciata dall\u{2019}",
        "Emesso dal", "Emessa dalla", "Emesso dallo", "Emesso dall'",
        "Offerto dal", "Offerta dalla", "Offerto dallo", "Offerto dall'",
        "Ausgestellt vom", "Angeboten vom", "Verliehen vom",
    ]

    @Test("A contracted lead sets the issuer", arguments: contracted)
    func contractedLeads(lead: String) throws {
        let separator = lead.hasSuffix("'") || lead.hasSuffix("\u{2019}") ? "" : " "
        let found = read(["Pool Safety", "\(lead)\(separator)Example Council, 2020"])
        #expect(found.cv.certifications.count == 1, "\(lead)")
        #expect(found.cv.certifications.first?.issuer?.value == "Example Council")
        #expect(found.cv.certifications.first?.year?.value == 2020)
    }

    @Test("A name that merely starts like a contracted lead stays an entry of its own")
    func contractedNames() {
        let found = read(["Pool Safety", "Dallas Rescue Basics", "Vom Kurs zur Praxis"])
        #expect(found.cv.certifications.count == 3)
        #expect(found.cv.certifications.allSatisfy { $0.issuer == nil })
    }

    // MARK: The safe split of "A, B"

    @Test("A name with one part after a comma takes it as issuer, so a lead line below stays its own entry")
    func twoPartName() {
        let found = read(["First Aid, Level 2", "Issued by Example Council, 2021"])
        #expect(found.cv.certifications.map(\.name.value) == ["First Aid", "Issued by Example Council"])
        #expect(found.cv.certifications.first?.issuer?.value == "Level 2")
    }

    // MARK: Conditions of the issuer line

    @Test("A lead line after a certification whose own line named an issuer is an entry of its own")
    func issuerFromOwnLine() {
        let found = read(["Pool Safety - Example Cross", "Issued by Example Council"])
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.first?.issuer?.value == "Example Cross")
    }

    @Test("A lead line without a year completes a certification that has one, and keeps its year")
    func yearAbove() {
        let found = read(["Pool Safety 2020", "Issued by Example Cross"])
        #expect(found.cv.certifications.count == 1)
        #expect(found.cv.certifications.first?.issuer?.value == "Example Cross")
        #expect(found.cv.certifications.first?.year?.value == 2020)
    }

    // MARK: The year of the issuer line must be unambiguous

    /// Lines whose dates are not one issuance year standing as a part of its own: the line is an entry of its own (split
    /// rather than merge, #283). A date that shares its part with words ("expires 2024", "valid until 2024") may belong to
    /// those words, whatever they are, and so may a date written right after the issuer with no separator.
    private static let ambiguousLines: [String] = [
        "Issued by Red Cross, 2021, expires 2024",
        "Rilasciato da Croce Rossa, 2021, scadenza 2024",
        "Issued by Red Cross, expires 2024",
        "Issued by Red Cross, 2021\u{2013}2024",
        "Issued by Red Cross, Rome, 2021",
        "Issued by Red Cross expires 2024",
        "Rilasciato da Croce Rossa scadenza 2024",
        "Ausgestellt von Rotes Kreuz gültig bis 2024",
        "Issued by Red Cross 2021",
        "Issued by Red Cross (2021)",
        "Issued by Red Cross (valid until 2024)",
    ]

    @Test("A lead line whose dates are not one issuance year is an entry of its own, and gives no year to the line above",
          arguments: ambiguousLines)
    func ambiguousYear(line: String) {
        let found = read(["First Aid Certificate", line])
        #expect(found.cv.certifications.count == 2, "\(line)")
        #expect(found.cv.certifications.first?.issuer == nil, "\(line)")
        #expect(found.cv.certifications.first?.year == nil, "\(line)")
    }

    /// Lines with one issuance year as a part of its own, after the issuer.
    private static let unambiguousLines: [String] = [
        "Issued by Red Cross, 2021",
        "Issued by Red Cross, March 2021",
        "Issued by Red Cross, (2021)",
        "Issued by Red Cross | 2021",
    ]

    @Test("A lead line with one issuance year as a part of its own, and nothing else, still completes the line above",
          arguments: unambiguousLines)
    func unambiguousYear(line: String) {
        let found = read(["First Aid Certificate", line])
        #expect(found.cv.certifications.count == 1, "\(line)")
        #expect(found.cv.certifications.first?.issuer?.value == "Red Cross", "\(line)")
        #expect(found.cv.certifications.first?.year?.value == 2021, "\(line)")
    }

    @Test("A lead line with no date still completes the line above")
    func noYear() {
        let found = read(["First Aid Certificate", "Issued by Red Cross"])
        #expect(found.cv.certifications.count == 1)
        #expect(found.cv.certifications.first?.issuer?.value == "Red Cross")
        #expect(found.cv.certifications.first?.year == nil)
    }

    // MARK: The link to the line above is cut

    @Test("A table header between a certification and a lead line cuts the link")
    func linkCutAtTableHeader() {
        let (document, sections) = pasted("Certifications\nPool Safety\n| Name | Issuer |\n|---|---|\nIssued by Example Cross")
        var findings = Findings(document: document)
        for section in sections where section.kind == .certifications { CertificationReader.read(section, into: &findings) }
        #expect(findings.cv.certifications.first?.issuer == nil)
        #expect(findings.cv.certifications.map(\.name.value).contains("Issued by Example Cross"))
    }

    @Test("A block with no cell between a certification and a lead line cuts the link")
    func linkCutAtEmptyBlock() {
        let (document, sections) = pasted("Certifications\nPool Safety\nIssued by Example Cross")
        var findings = Findings(document: document)
        for var section in sections where section.kind == .certifications {
            let first = section.blocks[0]
            let empty = SourceBlock(index: 99, span: first.span, cells: [], kind: .line, isEmphasized: false, followsGap: false,
                                    page: nil, frame: nil, column: nil, fontSize: nil)
            section.blocks.insert(empty, at: 1)
            CertificationReader.read(section, into: &findings)
        }
        #expect(findings.cv.certifications.first?.issuer == nil)
    }

    @Test("A consumed block between a certification and a lead line cuts the link")
    func linkCutAtConsumedBlock() {
        let (document, sections) = pasted("Certifications\nPool Safety\nSomething Else\nIssued by Example Cross")
        var findings = Findings(document: document)
        for section in sections where section.kind == .certifications {
            findings.consumedBlocks.insert(section.blocks[1].index)
            CertificationReader.read(section, into: &findings)
        }
        #expect(findings.cv.certifications.first?.issuer == nil)
    }
}
