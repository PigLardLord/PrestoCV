import Testing
@testable import PrestoCVImporting

/// What the traps of the corpus must leave visible as text not imported, or leave out with its reason: nothing the
/// person wrote goes without a trace (ADR 0027).
@Suite("The traps of the corpus")
struct TrapTests {

    private func result(_ id: String) throws -> ImportResult {
        let entry = try #require(try Corpus.entries().first { $0.id == id })
        return try Corpus.importResult(of: entry)
    }

    @Test("A reference's contacts are never the person's; they stay visible with the references")
    func references() throws {
        let found = try result("traps/references-en")
        #expect(found.cv.person.email?.value.value == "daniel.brooks@example.com")
        #expect(found.unplaced.filter { $0.section == .references }.map(\.text) == [
            "Sarah Hill, Operations Manager, Example Distribution Ltd", "sarah.hill@example.org · +44 7700 900321",
        ])
    }

    @Test("The consent to data processing and the signature are left out; the driving licence stays visible")
    func consentAndSignature() throws {
        let found = try result("traps/consent-it")
        #expect(found.leftOut.map(\.reason).filter { $0 != .documentTitle } == [.consent, .signature, .signature])
        #expect(found.unplaced.map(\.text) == ["B, patentino per carrello elevatore"])
    }

    @Test("A Lebenslauf's signature is no date of an entry, and its place and name are left out")
    func lebenslaufSignature() throws {
        let found = try result("traps/seit-de")
        #expect(found.leftOut.filter { $0.reason == .signature }.map(\.text) == ["Köln, den 03.10.2026", "Mehmet Yilmaz"])
        #expect(found.cv.experience.map { $0.period?.value.end } == [.current, .date(YearMonth(year: 2019, month: nil))])
    }

    @Test("Personal details the CV has no field for stay visible with their label")
    func personalDetails() throws {
        let found = try result("traps/datos-personales-es")
        #expect(found.unplaced.map(\.text) == ["Fecha de nacimiento: 21/02/1995"])
    }

    @Test("Levels drawn as bars are no levels; the bars are left out of the values")
    func bars() throws {
        let found = try result("traps/bars-it")
        #expect(found.cv.skills.map(\.value) == ["Photoshop", "Illustrator", "InDesign"])
        #expect(found.cv.languages.allSatisfy { $0.level == nil && $0.levelWords == nil })
    }

    @Test("LinkedIn's computed durations and page numbers are left out of LinkedIn's text")
    func linkedInText() throws {
        let found = try result("traps/linkedin-text-pt")
        #expect(found.leftOut.filter { $0.reason == .computedDuration }.map(\.text) == ["(6 anos 10 meses)", "(3 anos 4 meses)"])
        #expect(found.leftOut.contains { $0.reason == .pageNumber && $0.text == "Page 1 of 1" })
    }

    @Test("A review list flags what the rules are unsure of, in every language")
    func reviewList() throws {
        let words = try result("de-jonas/chat").reviewList
        #expect(words.contains { $0.field == .language(1) && $0.reason == .levelNotCEFR && $0.text == "Englisch — gute Kenntnisse" })
    }
}
