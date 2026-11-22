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

    @Test("A title that starts with a personal label's word is a title beside labelled contacts too", arguments: [
        "Web Developer", "Mobile Developer", "Portfolio Manager", "Site Manager", "City Planner", "Cell Biologist",
        "Location Scout", "Age Care Worker",
    ])
    func titleBesideLabelledContacts(_ title: String) {
        let found = header("""
        Anna Weber
        \(title)
        Email: person@example.com
        Phone: +44 20 7946 0000
        """)
        #expect(found.cv.person.name?.value == "Anna Weber")
        #expect(found.cv.person.title?.value == title)
        #expect(found.cv.person.location == nil)
        #expect(found.cv.person.email?.value.value == "person@example.com")
        #expect(found.cv.person.phone != nil)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A name that starts with a personal label's word is the name beside labelled contacts")
    func nameWithALabelWord() {
        let found = header("""
        Age Weber
        Email: person@example.com
        """)
        #expect(found.cv.person.name?.value == "Age Weber")
        #expect(found.cv.person.email?.value.value == "person@example.com")
        #expect(found.unplaced.isEmpty)
    }

    @Test("A title with a label's word stays a title when a labelled contact comes first and a line has no colon")
    func titleWithLabelledContactsFirst() {
        let found = header("""
        Anna Weber
        Email: person@example.com
        City Planner
        """)
        #expect(found.cv.person.name?.value == "Anna Weber")
        #expect(found.cv.person.title?.value == "City Planner")
        #expect(found.cv.person.location == nil)
        #expect(found.unplaced.isEmpty)
    }

    @Test("Under a personal-information heading, an age or a place-like label is not read from a name or a title")
    func personalHeadingKeepsNamesAndTitles() {
        let found = header("""
        Personal information
        Age Weber
        City Planner
        E-mail person@example.com
        """)
        #expect(found.cv.person.name?.value == "Age Weber")
        #expect(found.cv.person.location == nil)
        #expect(!shown(found).contains("Planner"))
    }

    @Test("A form of several bare labels reads its closed details: a nationality, a gender, a birth date")
    func formOfBareLabels() {
        let found = header("""
        Surname(s) / First name(s)
        Address(es)
        Date of birth 12 May 1990
        Nationality German
        """)
        #expect(found.cv.person.name == nil)
        #expect(found.cv.person.title == nil)
        #expect(shown(found).contains("Nationality German"))
    }

    @Test("A job title above the name stays the title, with a labelled contact below", arguments: [
        ("Web Developer", "Anna Weber", "Email"), ("City Planner", "Anna Weber", "Email"),
        ("Mobile Developer", "Anna Weber", "Email"), ("Softwareentwickler", "Anna Weber", "E-Mail"),
        ("Ingegnere informatico", "Anna Weber", "Email")
    ])
    func titleAboveTheName(title: String, name: String, label: String) {
        let found = header("""
        \(title)
        \(name)
        \(label): person@example.com
        """)
        #expect(found.cv.person.name?.value == name)
        #expect(found.cv.person.title?.value == title)
        #expect(found.cv.person.email?.value.value == "person@example.com")
    }

    @Test("A form label that names the occupation is never the title; the value under it is", arguments: [
        ("Sesso Femminile", "Occupazione desiderata/Settore professionale", "Direttrice Vendite"),
        ("Sex Female", "Desired employment/Occupational field", "Sales Manager")
    ])
    func labelIsNotTheTitle(before: String, label: String, value: String) {
        let found = header("""
        Informazioni personali
        Cognome(i)/Nome(i)
        Indirizzo(i)
        Telefono(i)
        Cellulare
        E-mail person@example.com
        Cittadinanza Italiana
        Data di nascita
        \(before)
        \(label)
        \(value)

        Esperienza professionale
        Date 01/2007
        """)
        #expect(found.cv.person.title?.value != label, "\(String(describing: found.cv.person.name?.value)) / \(String(describing: found.cv.person.title?.value))")
        #expect(found.cv.person.title == nil || found.cv.person.title?.value == value)
    }
}
