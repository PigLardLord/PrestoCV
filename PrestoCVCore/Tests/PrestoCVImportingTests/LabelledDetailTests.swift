import Testing
@testable import PrestoCVImporting

/// A personal detail written as "Label Value", with no colon and no column (#321).
@Suite("Reading a personal detail written as a label and its value")
struct LabelledDetailTests {

    private func header(_ text: String) -> Findings {
        let (document, sections) = pasted(text)
        var findings = Findings(document: document)
        HeaderReader.read(
            sections.filter { $0.kind == .header || $0.kind == .personal }, headingsThatCouldBeTheName: sections.filter(\.headingCouldBeTheName),
            hasSummarySection: sections.contains { $0.kind == .summary }, into: &findings
        )
        return findings
    }

    private func shown(_ findings: Findings) -> [String] {
        findings.unplaced.map { findings.document.text(of: $0.span) }
    }

    @Test("An empty form has no name: a detail line is never taken for it, and stays visible")
    func emptyEnglishForm() {
        let found = header("""
        Personal information
        Surname(s) / First name(s)
        Address(es)
        E-mail person@example.com
        Nationality German
        Date of birth
        Gender Male
        """)
        #expect(found.cv.person.name == nil)
        #expect(found.cv.person.title == nil)
        #expect(found.cv.person.email?.value.value == "person@example.com")
        #expect(shown(found).contains("Nationality German"))
        #expect(shown(found).contains("Gender Male"))
    }

    @Test("The form's own name label gives the name, and the other details stay visible")
    func italianForm() {
        let found = header("""
        Informazioni personali
        Cognome(i)/Nome(i) Weber Anna
        E-mail person@example.com
        Cittadinanza Tedesca
        Sesso Femminile
        """)
        #expect(found.cv.person.name?.value == "Weber Anna")
        #expect(found.cv.person.name?.check == nil)
        #expect(found.cv.person.title == nil)
        #expect(shown(found).contains("Cittadinanza Tedesca"))
        #expect(shown(found).contains("Sesso Femminile"))
    }

    @Test("The English form's name label gives the name", arguments: [
        "Surname(s) / First name(s) Anna Weber",
        "Surname(s) / First name(s): Anna Weber",
        "Name Anna Weber",
    ])
    func englishName(_ line: String) {
        let found = header("""
        Personal information
        \(line)
        Nationality German
        """)
        #expect(found.cv.person.name?.value == "Anna Weber")
        #expect(found.cv.person.name?.check == nil)
    }

    @Test("A real name under the heading is still the name")
    func realNameStays() {
        let found = header("""
        Personal information
        Anna Weber
        Nationality German
        E-mail person@example.com
        """)
        #expect(found.cv.person.name?.value == "Anna Weber")
        #expect(shown(found) == ["Nationality German"])
    }

    @Test("A title that starts with a label's word is a title, outside a form", arguments: ["Web Developer", "Gender Pay Analyst", "Mobile Engineer"])
    func titleWithALabelWord(_ title: String) {
        let found = header("""
        Anna Weber
        \(title)
        person@example.com
        """)
        #expect(found.cv.person.name?.value == "Anna Weber")
        #expect(found.cv.person.title?.value == title)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A line with a colon after words that are no label is shown whole, label words and all")
    func colonAfterMoreWords() {
        let found = header("""
        Dati personali
        Telefono abitazione: 02 5367 2389
        Nazionalità: Italiana
        """)
        #expect(shown(found).contains("Telefono abitazione"))
        #expect(!shown(found).contains("abitazione"))
    }
}
