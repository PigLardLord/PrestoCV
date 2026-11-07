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
        let found = read(["First Aid Certificate", "issued by: Red Cross 2021"])
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

    @Test("A long sentence that starts with a lead is not an issuer")
    func longSentence() {
        let found = read(["First Aid Certificate", "Issued by the committee after a long review of the written and practical exams that candidates sat in spring and autumn of the year."])
        #expect(found.cv.certifications.count == 2)
        #expect(found.cv.certifications.first?.issuer == nil)
    }

    @Test("A lead with nothing after it is not an issuer")
    func bareLead() {
        let found = read(["First Aid Certificate", "Issued by"])
        #expect(found.cv.certifications.count == 2)
    }
}
