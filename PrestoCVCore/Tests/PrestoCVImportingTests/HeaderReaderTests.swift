import Testing
@testable import PrestoCVImporting

/// The document of a pasted text, and its sections.
func pasted(_ text: String) -> (SourceDocument, [Section]) {
    let (document, _) = DocumentBuilder.build(lines: PlainTextReader.lines(of: text).map { RawLine(text: $0) }, format: .pastedText)
    return (document, SectionSegmenter.sections(of: document))
}

@Suite("Reading the head of a CV")
struct HeaderReaderTests {

    private func header(_ text: String) -> Findings {
        let (document, sections) = pasted(text)
        var findings = Findings(document: document)
        HeaderReader.read(
            sections.filter { $0.kind == .header || $0.kind == .personal }, headingsThatCouldBeTheName: sections.filter(\.headingCouldBeTheName),
            hasSummarySection: sections.contains { $0.kind == .summary }, into: &findings
        )
        return findings
    }

    @Test("A chat answer's head: the name in a heading, the title in bold, contacts after icons")
    func chatAnswer() {
        let found = header("""
        # Giulia Bianchi
        **Infermiera professionale**
        📍 Torino, Italia | 📞 +39 333 000 0000 | ✉️ giulia.bianchi@example.com | 🔗 linkedin.com/in/giulia-bianchi-example
        """)
        let person = found.cv.person
        #expect(person.name?.value == "Giulia Bianchi")
        #expect(person.name?.check == nil)
        #expect(person.title?.value == "Infermiera professionale")
        #expect(person.location?.value == "Torino, Italia")
        #expect(person.location?.check == nil)
        #expect(person.phone?.value.value == "+39 333 000 0000")
        #expect(person.email?.value.value == "giulia.bianchi@example.com")
        #expect(person.links.map(\.kind) == [.linkedIn])
        #expect(found.unplaced.isEmpty)
    }

    @Test("The document's title is left out; an address line with a postal code is the place")
    func plainWordText() {
        let found = header("""
        CURRICULUM VITAE
        Lena Hartmann
        Elektrikerin
        Musterstraße 5, 04109 Leipzig
        Tel.: 0341 1234567
        E-Mail: lena.hartmann@example.com
        """)
        #expect(found.leftOut.map(\.reason) == [.documentTitle])
        #expect(found.cv.person.name?.value == "Lena Hartmann")
        #expect(found.cv.person.name?.check == nil, "The first line after the title is the name")
        #expect(found.cv.person.title?.value == "Elektrikerin")
        #expect(found.cv.person.location?.value == "Musterstraße 5, 04109 Leipzig")
        #expect(found.cv.person.phone?.value.value == "0341 1234567")
        #expect(found.cv.person.email?.value.value == "lena.hartmann@example.com")
    }

    @Test("Labelled personal details: the name and the address are read; the date of birth and nationality stay visible")
    func personalDetails() {
        let found = header("""
        Persönliche Daten
        Name: Lena Hartmann
        Anschrift: Musterstraße 5, 04109 Leipzig
        Geburtsdatum: 12.05.1990
        Staatsangehörigkeit: deutsch
        """)
        #expect(found.cv.person.name?.value == "Lena Hartmann")
        #expect(found.cv.person.name?.check == nil)
        #expect(found.cv.person.location?.value == "Musterstraße 5, 04109 Leipzig")
        #expect(found.unplaced.map(\.text) == ["Geburtsdatum: 12.05.1990", "Staatsangehörigkeit: deutsch"])
    }

    @Test("The rows of the formato europeo")
    func formatoEuropeo() {
        let found = header("""
        INFORMAZIONI PERSONALI
        Nome\tBianchi Giulia
        Indirizzo\tVia Roma 1, 10121 Torino
        Telefono\t+39 333 0000000
        E-mail\tgiulia.bianchi@example.com
        Nazionalità\tItaliana
        Data di nascita\t12/05/1990
        """)
        #expect(found.cv.person.name?.value == "Bianchi Giulia")
        #expect(found.cv.person.location?.value == "Via Roma 1, 10121 Torino")
        #expect(found.cv.person.phone?.value.value == "+39 333 0000000")
        #expect(found.cv.person.email?.value.value == "giulia.bianchi@example.com")
        #expect(found.unplaced.map(\.text) == ["Nazionalità\tItaliana", "Data di nascita\t12/05/1990"])
    }

    @Test("Prose at the top, under no heading, is the summary, to be checked")
    func summaryWithoutHeading() {
        let found = header("""
        Mariana Costa
        Desenvolvedora de software
        Desenvolvedora com seis anos de experiência em aplicações móveis, apaixonada por acessibilidade e por equipas pequenas.
        """)
        #expect(found.cv.person.summary?.value.hasPrefix("Desenvolvedora com seis anos") == true)
        #expect(found.cv.person.summary?.check == .summaryWithoutHeading)
        #expect(found.cv.person.title?.value == "Desenvolvedora de software")
    }

    @Test("A second e-mail address stays visible instead of replacing the first")
    func secondEmail() {
        let found = header("Lucas Martin\nlucas.martin@example.org · lucas@example.net")
        #expect(found.cv.person.email?.value.value == "lucas.martin@example.org")
        #expect(found.unplaced.map(\.text) == ["lucas@example.net"])
    }

    @Test("Names have capitals or particles, and no role, organisation or place")
    func names() {
        #expect(HeaderReader.looksLikeName("Giulia Bianchi"))
        #expect(HeaderReader.looksLikeName("João Pedro da Silva"))
        #expect(HeaderReader.looksLikeName("LENA HARTMANN"))
        #expect(HeaderReader.looksLikeName("Senior iOS Developer") == false)
        #expect(HeaderReader.looksLikeName("Beispiel GmbH") == false)
        #expect(HeaderReader.looksLikeName("Torino, Italia") == false)
        #expect(HeaderReader.looksLikeName("Curriculum Vitae") == false)
    }

    // MARK: Contacts with their labels (#301)

    @Test("A labelled phone number is read for its label, and the label of an e-mail address is no place")
    func labelledContacts() {
        let found = header("""
        Jane Rowe
        Phone: 555-555-5555
        Email address: jane@example.com
        """)
        #expect(found.cv.person.name?.value == "Jane Rowe")
        #expect(found.cv.person.phone?.value.value == "555-555-5555")
        #expect(found.cv.person.email?.value.value == "jane@example.com")
        #expect(found.cv.person.location == nil)
        #expect(found.cv.person.title == nil)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A label of the personal details alone on its line, with the value under it, is no title and no place", arguments: [
        "Anschrift:", "Adresse :", "Address:", "Indirizzo:", "Dirección:", "Endereço:",
    ])
    func bareLabel(label: String) {
        let found = header("""
        Name:
        Jane Rowe
        \(label)
        Kiesweg 70
        12345 Musterstadt
        Tel. 0151 2345678
        """)
        #expect(found.cv.person.name?.value == "Jane Rowe", "\(label)")
        #expect(found.cv.person.title == nil, "\(label)")
        #expect(found.cv.person.location?.value.hasPrefix("Kiesweg 70") == true, "\(label)")
        // The labels stay visible as text not imported, the values are all in the person
        #expect(found.unplaced.allSatisfy { EntryVocabulary.personalLabel($0.text) != nil }, "\(label)")
    }

    @Test("The row of a table gives its number to the phone, whatever the number looks like")
    func labelledRow() {
        let found = header("Jane Rowe\nPhone\t555-0142\nE-mail\tjane@example.com")
        #expect(found.cv.person.phone?.value.value == "555-0142")
        #expect(found.unplaced.isEmpty)
    }

    @Test("The labels of an e-mail address in Spanish and Portuguese are no place and no title")
    func labelsInOtherLanguages() {
        for label in ["Dirección de correo electrónico", "Endereço de correio electrónico", "Indirizzo e-mail", "Adresse électronique"] {
            let found = header("Mateo Vargas\n\(label): mateo.vargas@example.com")
            #expect(found.cv.person.email?.value.value == "mateo.vargas@example.com", "\(label)")
            #expect(found.cv.person.location == nil, "\(label)")
            #expect(found.cv.person.title == nil, "\(label)")
            #expect(found.unplaced.isEmpty, "\(label)")
        }
    }

    @Test("A postcode is no phone number: the phone after the address is the person's")
    func postcodeIsNoPhone() {
        let found = header("""
        Ana Souza
        Rua das Flores, 45, São Paulo - SP, 01010-000
        ana@example.com • (11) 91234-5678
        """)
        #expect(found.cv.person.phone?.value.value == "(11) 91234-5678")
        #expect(found.cv.person.location?.value == "Rua das Flores, 45, São Paulo - SP, 01010-000")
        #expect(found.cv.person.title == nil)
        #expect(found.unplaced.isEmpty)
    }

    @Test("A label the vocabulary does not know stays visible; it is not the place")
    func unknownLabel() {
        let found = header("Jane Rowe\nContact via: jane@example.com")
        #expect(found.cv.person.email?.value.value == "jane@example.com")
        #expect(found.cv.person.location == nil)
        #expect(found.unplaced.map(\.text) == ["Contact via"])
    }

    // MARK: The name followed by credentials (#302)

    @Test("The name is read before its credentials; they go with the title")
    func credentials() {
        let found = header("""
        Jane Rowe, RN
        Nurse
        Akron, OH
        jane@example.com
        """)
        let person = found.cv.person
        #expect(person.name?.value == "Jane Rowe")
        #expect(person.name?.check == nil)
        #expect(person.title?.value == "Nurse, RN")
        #expect(person.location?.value == "Akron, OH")
        #expect(person.location?.check == nil)
        #expect(person.email?.value.value == "jane@example.com")
        #expect(found.unplaced.isEmpty)
    }

    @Test("Credentials of every kind: letters, a list of them, dotted degrees, a degree in words", arguments: [
        ("Tessa Marlowe, MSN", "Tessa Marlowe"), ("John Smith, CPA", "John Smith"), ("Sam Carter, MBA, PMP", "Sam Carter"),
        ("Priya Nair, PhD", "Priya Nair"), ("Lena Hartmann, Dipl.-Ing.", "Lena Hartmann"), ("Luca Neri, M.Sc.", "Luca Neri"),
        ("Rosa Vidal, MSN, RN, CCRN", "Rosa Vidal"), ("Jane Rowe, Bachelor of Science in Nursing", "Jane Rowe"),
    ])
    func credentialsOfEveryKind(line: String, name: String) {
        let found = header(line + "\nProject manager\nTorino, Italia\nperson@example.com")
        #expect(found.cv.person.name?.value == name, "\(line)")
        #expect(found.cv.person.name?.check == nil, "\(line)")
        let credentials = String(line.dropFirst(name.count + 2))
        #expect(found.cv.person.title?.value == "Project manager, " + credentials, "\(line)")
    }

    @Test("With no title line the credentials stay visible, and the place after them is still read")
    func credentialsWithoutTitle() {
        let found = header("Jane Rowe, RN\nAkron, OH\njane@example.com")
        #expect(found.cv.person.name?.value == "Jane Rowe")
        #expect(found.cv.person.title == nil)
        #expect(found.cv.person.location?.value == "Akron, OH")
        #expect(found.unplaced.map(\.text) == ["RN"])
    }

    @Test("A code that is a credential and a state is a credential only for a name alone; the check says to look")
    func ambiguousCode() {
        let alone = header("Jane Rowe, MD\nPhysician")
        #expect(alone.cv.person.name?.value == "Jane Rowe")
        #expect(alone.cv.person.name?.check == .nameByPosition)
        #expect(alone.cv.person.title?.value == "Physician, MD")
        // With a name that needs no guess in the head, the place with the state is a place; read without its code it could
        // have been the name, so the two are to be checked
        let withName = header("Silver Spring, MD\nJane Rowe\nNurse")
        #expect(withName.cv.person.name?.value == "Jane Rowe")
        #expect(withName.cv.person.name?.check == .nameByPosition)
        #expect(withName.cv.person.location?.value == "Silver Spring, MD")
        #expect(withName.cv.person.location?.check == .locationByPosition)
    }

    @Test("A place with a state or a province is never a name", arguments: [
        "Los Angeles, CA", "San Diego, CA", "Fort Worth, TX", "Santa Fe, NM", "Palo Alto, CA", "Salt Lake City, UT",
    ])
    func placeIsNoName(line: String) {
        let found = header(line + "\nNurse\njane@example.com")
        #expect(found.cv.person.name == nil, "\(line)")
        #expect(found.cv.person.location?.value == line, "\(line)")
    }

    @Test("Credentials without a comma follow the name too, in capitals only", arguments: [
        ("Jane Rowe RN", "Jane Rowe", "Nurse, RN"), ("JOHN SMITH CPA", "JOHN SMITH", "Nurse, CPA"),
        ("Sam Carter PMP, MBA", "Sam Carter", "Nurse, PMP, MBA"),
    ])
    func credentialsWithoutComma(line: String, name: String, title: String) {
        let found = header(line + "\nNurse\njane@example.com")
        #expect(found.cv.person.name?.value == name, "\(line)")
        #expect(found.cv.person.title?.value == title, "\(line)")
    }

    @Test("A name before a contact keeps being a name, and a place before one a place")
    func nameBeforeAContact() {
        let found = header("Jane Rowe: jane@example.com\nNurse")
        #expect(found.cv.person.name?.value == "Jane Rowe")
        #expect(found.cv.person.title?.value == "Nurse")
        #expect(found.unplaced.isEmpty)
        let place = header("Jane Rowe\nNurse\nTorino: jane@example.com")
        #expect(place.cv.person.location?.value == "Torino")
    }

    @Test("A name that is the name of a state or a city is still a name")
    func nameLikeAPlace() {
        for line in ["Denzel Washington", "Virginia Woolf", "Georgia Brown", "Austin Powers", "Jordan Lee"] {
            #expect(HeaderReader.looksLikeName(line), "\(line)")
            let found = header(line + "\nNurse\njane@example.com")
            #expect(found.cv.person.name?.value == line, "\(line)")
        }
    }

    @Test("A surname or a given name that is the name of a city is still a name, to be checked, with credentials or without", arguments: [
        "Thomas Kiel", "Anna Münster", "Paul Kassel", "Maria Mainz", "Jack London", "Florence Nightingale",
    ], ["", ", RN"])
    func nameWithACityWord(line: String, credentials: String) {
        let found = header(line + credentials + "\nNurse\nperson@example.com")
        #expect(found.cv.person.name?.value == line, "\(line)\(credentials)")
        // A word of a list only lowers the evidence: "Greater London" has the same words and the same place in the head
        #expect(found.cv.person.name?.check == .nameByPosition, "\(line)\(credentials)")
        #expect(found.cv.person.title?.value == "Nurse" + (credentials.isEmpty ? "" : ", RN"), "\(line)\(credentials)")
        #expect(found.cv.person.location == nil, "\(line)\(credentials)")
        let untitled = header(line + credentials + "\nperson@example.com")
        #expect(untitled.cv.person.name?.value == line, "\(line)\(credentials)")
        #expect(untitled.cv.person.name?.check == .nameByPosition, "\(line)\(credentials)")
        #expect(untitled.cv.person.location == nil, "\(line)\(credentials)")
    }

    @Test("A line with a city and another word is the name when the head says so, and the other one the place")
    func placeWordsAreNoName() {
        let placeFirst = header("Greater London\nAnna Weber\nNurse\nanna@example.com")
        #expect(placeFirst.cv.person.name?.value == "Anna Weber")
        #expect(placeFirst.cv.person.name?.check == .nameByPosition)
        let nameFirst = header("Thomas Kiel\nNurse\nGreater London\nthomas@example.com")
        #expect(nameFirst.cv.person.name?.value == "Thomas Kiel")
        #expect(nameFirst.cv.person.location?.value == "Greater London")
        #expect(nameFirst.cv.person.location?.check == .locationByPosition)
    }

    // MARK: The name by the evidence of the whole head (#301)

    @Test("A place with a word no list knows, above a name with a city word, is never the name without a check", arguments: [
        "Greater London", "Upper Bielefeld", "Old Torino",
    ])
    func placeAboveTheName(place: String) {
        let titled = header(place + "\nThomas Kiel\nNurse\nperson@example.com")
        #expect(titled.cv.person.name?.value == "Thomas Kiel", "\(place)")
        #expect(titled.cv.person.name?.check == .nameByPosition, "\(place)")
        #expect(titled.cv.person.title?.value == "Nurse", "\(place)")
        #expect(titled.cv.person.location?.value == place, "\(place)")
        #expect(titled.cv.person.location?.check == .locationByPosition, "\(place)")
        // With no title nothing in the head tells the two lines apart: both are read, and both are to be checked
        let person = header(place + "\nThomas Kiel\nperson@example.com").cv.person
        #expect(Set([person.name?.value, person.location?.value]) == Set([place, "Thomas Kiel"]), "\(place)")
        #expect(person.name?.check == .nameByPosition, "\(place)")
        #expect(person.location?.check == .locationByPosition, "\(place)")
    }

    @Test("A place that no list knows, above the name, is never the name without a check, whatever the name's words", arguments: [
        "Thomas Kiel", "Rebecca Cook", "Victoria West", "Anna Weber",
    ])
    func unknownPlaceAboveTheName(name: String) {
        let titled = header("Greater Wexby\n" + name + "\nNurse\nperson@example.com")
        #expect(titled.cv.person.name?.value == name, "\(name)")
        #expect(titled.cv.person.name?.check == .nameByPosition, "\(name)")
        #expect(titled.cv.person.title?.value == "Nurse", "\(name)")
        let placeIsKept = titled.cv.person.location?.value == "Greater Wexby" || titled.unplaced.map(\.text).contains("Greater Wexby")
        #expect(placeIsKept, "\(name)")
        // With no title nothing in the head tells the two lines apart: both are read, and each is to be checked
        let person = header("Greater Wexby\n" + name + "\nperson@example.com").cv.person
        let read = [person.name, person.title, person.location].compactMap { $0 }
        let unchecked = read.filter { $0.check == nil }.map(\.value)
        #expect(Set(read.map(\.value)) == ["Greater Wexby", name], "\(name)")
        #expect(unchecked.isEmpty, "\(name)")
    }

    @Test("The first line is the name over a place that no list knows under it, sure only with a title of its own", arguments: [
        "Thomas Kiel", "Rebecca Cook", "Victoria West", "Anna Weber",
    ])
    func nameAboveAnUnknownPlace(name: String) {
        let hasListWord = name == "Thomas Kiel" || name == "Rebecca Cook"
        let titled = header(name + "\nNurse\nGreater Wexby\nperson@example.com").cv.person
        #expect(titled.name?.value == name, "\(name)")
        #expect(titled.name?.check == (hasListWord ? .nameByPosition : nil), "\(name)")
        #expect(titled.title?.value == "Nurse", "\(name)")
        #expect(titled.location?.value == "Greater Wexby", "\(name)")
        // The line under the name could have been the name: it is read where a title is expected, and the two are to be checked
        let untitled = header(name + "\nGreater Wexby\nperson@example.com").cv.person
        #expect(untitled.name?.value == name, "\(name)")
        #expect(untitled.name?.check == .nameByPosition, "\(name)")
        let other = [untitled.title, untitled.location].compactMap { $0 }
        #expect(other.map(\.value) == ["Greater Wexby"], "\(name)")
        #expect(!other.contains { $0.check == nil }, "\(name)")
    }

    @Test("A line made only of known places, above the name, is the place, and both are to be checked", arguments: [
        "Berlin Germany", "San Francisco",
    ])
    func knownPlaceAboveTheName(place: String) {
        let person = header(place + "\nAnna Weber\nperson@example.com").cv.person
        #expect(person.name?.value == "Anna Weber", "\(place)")
        #expect(person.name?.check == .nameByPosition, "\(place)")
        #expect(person.location?.value == place, "\(place)")
        #expect(person.location?.check == .locationByPosition, "\(place)")
    }

    @Test("A place alone is never the name without a check", arguments: [
        "Greater London", "Berlin Germany", "New York", "Fully Remote", "Milano Italia", "Upper Bielefeld",
    ], ["\nNurse", ""])
    func placeAlone(place: String, title: String) {
        let name = header(place + title + "\nperson@example.com").cv.person.name
        #expect(name == nil || name?.check == .nameByPosition, "\(place)\(title)")
    }

    @Test("The first line is the name; with another line that could be one and no title it is to be checked, and so is the place")
    func nameFirst() {
        let untitled = header("Anna Weber\nGreater London\nanna@example.com")
        #expect(untitled.cv.person.name?.value == "Anna Weber")
        #expect(untitled.cv.person.name?.check == .nameByPosition)
        #expect(untitled.cv.person.title == nil)
        #expect(untitled.cv.person.location?.value == "Greater London")
        #expect(untitled.cv.person.location?.check == .locationByPosition)
        let titled = header("Anna Weber\nNurse\nGreater London\nanna@example.com")
        #expect(titled.cv.person.name?.check == nil)
        #expect(titled.cv.person.title?.value == "Nurse")
        #expect(titled.cv.person.location?.value == "Greater London")
        #expect(titled.cv.person.location?.check == nil)
    }

    @Test("A surname that is a point of the compass is a name like any other", arguments: ["Victoria West", "Anna North", "Mark South"])
    func compassSurname(line: String) {
        let first = header(line + "\nNurse\nperson@example.com")
        #expect(first.cv.person.name?.value == line, "\(line)")
        #expect(first.cv.person.name?.check == nil, "\(line)")
        #expect(first.cv.person.title?.value == "Nurse", "\(line)")
        let belowAPlace = header("Greater London\n" + line + "\nNurse\nperson@example.com")
        #expect(belowAPlace.cv.person.name?.value == line, "\(line)")
        #expect(belowAPlace.cv.person.name?.check == .nameByPosition, "\(line)")
        #expect(belowAPlace.cv.person.location?.value == "Greater London", "\(line)")
        #expect(belowAPlace.cv.person.location?.check == .locationByPosition, "\(line)")
    }

    @Test("A surname that is also a trade is a name, to be checked, in a line, a heading or before a contact", arguments: [
        "Rebecca Cook", "Anna Koch", "Maria Meister", "Thomas Kaufmann",
    ])
    func surnameThatIsATrade(line: String) {
        for text in [line + "\nNurse\nperson@example.com", "# " + line + "\n**Nurse**\nperson@example.com", line + ": person@example.com\nNurse"] {
            let found = header(text)
            #expect(found.cv.person.name?.value == line, "\(text)")
            #expect(found.cv.person.name?.check == .nameByPosition, "\(text)")
            #expect(found.cv.person.title?.value == "Nurse", "\(text)")
            #expect(found.unplaced.isEmpty, "\(text)")
        }
    }

    @Test("A place after a contact on its line has no title under it, and is not in doubt as the name")
    func placeOnTheContactLine() {
        let kiel = header("Thomas Kiel\nperson@example.com | Greater London\nNurse")
        #expect(kiel.cv.person.name?.value == "Thomas Kiel")
        #expect(kiel.cv.person.name?.check == .nameByPosition)
        #expect(kiel.cv.person.location?.value == "Greater London")
        #expect(kiel.cv.person.location?.check == nil)
        let weber = header("Anna Weber\nperson@example.com | Greater London\nNurse")
        #expect(weber.cv.person.name?.value == "Anna Weber")
        #expect(weber.cv.person.name?.check == nil)
        #expect(weber.cv.person.location?.value == "Greater London")
        let below = header("person@example.com | Greater London\nThomas Kiel\nNurse")
        #expect(below.cv.person.name?.value == "Thomas Kiel")
        #expect(below.cv.person.title?.value == "Nurse")
        #expect(below.cv.person.location?.value == "Greater London")
        // A name after a contact on its line is still the name, its title under it
        let after = header("person@example.com | Anna Weber\nNurse")
        #expect(after.cv.person.name?.value == "Anna Weber")
        #expect(after.cv.person.title?.value == "Nurse")
    }

    @Test("A name in a heading of the first level stays in the head after a contact or the document's title, whatever its words", arguments: [
        "Thomas Kiel", "Rebecca Cook", "Anna Weber",
    ], ["person@example.com\n\n", "**Curriculum Vitae**\n\n", "Here is the CV you asked for.\n\n"])
    func nameHeadingInTheHead(name: String, before: String) {
        let found = header(before + "# " + name + "\nNurse\n\n## Experience\n2019 - 2021\nNurse\nAcme Ltd")
        #expect(found.cv.person.name?.value == name, "\(before)\(name)")
        #expect(found.cv.person.name?.check == (name == "Anna Weber" ? nil : .nameByPosition), "\(before)\(name)")
        #expect(found.cv.person.title?.value == "Nurse", "\(before)\(name)")
    }

    // MARK: A heading after the name (#301)

    @Test("A heading of the first level after the name and its contacts is a section, not the name, the title or the place; the name is to be checked, as the heading could have been it", arguments: [
        "Anna Weber", "Thomas Kiel", "Rebecca Cook",
    ], ["", "Nurse\n"])
    func headingAfterTheNameAndContacts(name: String, title: String) throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(
            "\(name)\n\(title)person@example.com\n\n# University Projects\nBuilt a scheduling application"
        )
        let person = result.cv.person
        #expect(person.name?.value == name, "\(name) / \(title)")
        #expect(person.name?.check == .nameByPosition, "\(name) / \(title)")
        #expect(person.title?.value == (title.isEmpty ? nil : "Nurse"), "\(name) / \(title)")
        #expect(person.location == nil, "\(name) / \(title)")
        #expect(result.unplaced.map(\.text) == ["Built a scheduling application"], "\(name) / \(title)")
        #expect(result.unplaced.first?.heading == "University Projects", "\(name) / \(title)")
    }

    @Test("The price of a heading after a line in the shape of a name and the contacts: a name in it is a section's heading, and the line before the contacts is the name, to be checked")
    func nameInAHeadingAfterTheContacts() throws {
        let importer = ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard)
        for before in ["Greater Wexby", "Senior Nurse"] {
            let result = try importer.importText("\(before)\nperson@example.com\n\n# Anna Weber\nNurse")
            #expect(result.cv.person.name?.value == before, "\(before)")
            #expect(result.cv.person.name?.check == .nameByPosition, "\(before)")
            #expect(result.cv.person.title == nil, "\(before)")
            #expect(result.unplaced.map(\.text) == ["Nurse"], "\(before)")
            #expect(result.unplaced.first?.heading == "Anna Weber", "\(before)")
            // A heading with no line of its own is shown, with the head
            let bare = try importer.importText("\(before)\nperson@example.com\n\n# Anna Weber\n\n## Experience\n2019 - 2021 Nurse, Northgate Hospital")
            #expect(bare.cv.person.name?.check == .nameByPosition, "\(before)")
            #expect(bare.unplaced.map(\.text) == ["Anna Weber"], "\(before)")
            #expect(bare.unplaced.first?.section == .header && bare.unplaced.first?.heading == nil, "\(before)")
        }
        // A name given by its label stays sure
        let labelled = try importer.importText("Name: Anna Weber\nEmail: person@example.com\n\n# University Projects\nBuilt a scheduling application")
        #expect(labelled.cv.person.name?.value == "Anna Weber")
        #expect(labelled.cv.person.name?.check == nil)
    }

    @Test("Before a profile's heading, after a section of contacts or of skills, a heading of the first level in the shape of a name is a section's, not the place (#301)")
    func headingBeforeAProfile() throws {
        let importer = ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard)
        for between in ["## Contact\nperson@example.com", "person@example.com\n\n## Skills\nSwift"] {
            let result = try importer.importText(
                "Anna Weber\n\(between)\n\n# University Projects\nBuilt a scheduling application\n\n## Experience\n2019 - 2021 Nurse, Northgate Hospital"
            )
            let person = result.cv.person
            #expect(person.name?.value == "Anna Weber" && person.name?.check == .nameByPosition, "\(between)")
            #expect(person.title == nil && person.location == nil, "\(between)")
            #expect(result.unplaced.map(\.text) == ["Built a scheduling application"], "\(between)")
            #expect(result.unplaced.first?.heading == "University Projects", "\(between)")
            let bare = try importer.importText("Anna Weber\n\(between)\n\n# University Projects\n\n## Experience\n2019 - 2021 Nurse, Northgate Hospital")
            #expect(bare.cv.person.location == nil, "\(between)")
            #expect(bare.unplaced.map(\.text) == ["University Projects"], "\(between)")
        }
    }

    @Test("A heading of the first level under a line in the shape of a name is no mark of the name: the first line keeps its evidence", arguments: [
        "Anna Weber", "Thomas Kiel",
    ])
    func headingUnderTheName(name: String) {
        // The first line with a title of its own is the name, and the heading is no title
        let titled = header("\(name)\nNurse\n\n# University Projects\nBuilt a scheduling application")
        #expect(titled.cv.person.name?.value == name, "\(name)")
        #expect(titled.cv.person.name?.check == (name == "Anna Weber" ? nil : .nameByPosition), "\(name)")
        #expect(titled.cv.person.title?.value == "Nurse", "\(name)")
        let contactAfter = header("\(name)\nNurse\n\n# University Projects\nperson@example.com")
        #expect(contactAfter.cv.person.name?.value == name, "\(name)")
        #expect(contactAfter.cv.person.title?.value == "Nurse", "\(name)")
        // Right under the first line, the heading is its title, and the two are to be checked
        let bare = header("\(name)\n\n# University Projects\nBuilt a scheduling application")
        #expect(bare.cv.person.name?.value == name, "\(name)")
        #expect(bare.cv.person.name?.check == .nameByPosition, "\(name)")
        #expect(bare.cv.person.title?.value == "University Projects", "\(name)")
        #expect(bare.cv.person.title?.check == .titleByPosition, "\(name)")
    }

    @Test("The price of a heading that is no mark under a line in the shape of a name: a name in it under a place no list knows is flagged with it")
    func nameHeadingUnderAnUnknownPlace() {
        let found = header("Greater Wexby\n# Anna Weber\nNurse")
        #expect(found.cv.person.name?.value == "Greater Wexby")
        #expect(found.cv.person.name?.check == .nameByPosition)
        #expect(found.cv.person.title?.value == "Anna Weber")
        #expect(found.cv.person.title?.check == .titleByPosition)
        // Under a line of known places alone, the heading is still the name
        let known = header("Berlin Germany\n# Anna Weber\nNurse")
        #expect(known.cv.person.name?.value == "Anna Weber")
        #expect(known.cv.person.title?.value == "Nurse")
    }

    @Test("The profile of LinkedIn's text starts at its name after the sidebar, whatever the name's and the last skill's words", arguments: [
        "Thomas Kiel", "Rebecca Cook", "Anna Weber",
    ], ["Wound care", "Patient Safety"])
    func linkedInNameAfterTheSidebar(name: String, skill: String) {
        let found = header("""
        Contact
        person@example.com
        Top Skills
        Triage
        \(skill)
        \(name)
        Nurse at Acme Clinic
        Greater London
        Summary
        Nurse with ten years in emergency care.
        Experience
        Acme Clinic
        Nurse
        2019 - 2021
        """)
        #expect(found.cv.person.name?.value == name, "\(skill) \(name)")
        #expect(found.cv.person.title?.value == "Nurse at Acme Clinic", "\(skill) \(name)")
        #expect(found.cv.person.location?.value == "Greater London", "\(skill) \(name)")
    }

    @Test("A name given by its label loses its credentials, whatever its words")
    func labelledNameWithCredentials() {
        let found = header("Name: Thomas Kiel, RN\nperson@example.com")
        #expect(found.cv.person.name?.value == "Thomas Kiel")
        #expect(found.cv.person.name?.check == nil)
        #expect(found.unplaced.map(\.text) == ["RN"])
    }

    @Test("A line under the name with a role and the form of a place is the title, to be checked")
    func roleWithThePlaceForm() {
        let found = header("Jane Rowe\nDriver Creek, Oregon\njane@example.com")
        #expect(found.cv.person.name?.check == nil)
        #expect(found.cv.person.title?.value == "Driver Creek, Oregon")
        #expect(found.cv.person.title?.check == .titleByPosition)
        #expect(found.cv.person.location == nil)
    }

    // MARK: The place and the street (#302)

    @Test("A city with its state or province is the place, whichever way the state is written", arguments: [
        "Akron, OH", "Austin, Texas", "Seattle, Washington", "Medford, Ohio", "Toronto, ON", "Calgary, Alberta", "Leeds, England",
        "Bielefeld, Nordrhein-Westfalen", "São Paulo - SP", "Lyon, France",
    ])
    func cityWithRegion(line: String) {
        let found = header("Jane Rowe\n" + line + "\njane@example.com")
        #expect(found.cv.person.title == nil, "\(line)")
        #expect(found.cv.person.location?.value == line, "\(line)")
        #expect(found.cv.person.location?.check == nil, "\(line)")
    }

    @Test("A city alone among the lines of contacts is the place, to be checked", arguments: ["Hennef", "Waldkirch", "Frankfurt am Main"])
    func loneCity(city: String) {
        let found = header("""
        Lena Hartmann
        Elektroingenieurin
        \(city)
        Tel.: 0521 5550142
        """)
        #expect(found.cv.person.title?.value == "Elektroingenieurin")
        #expect(found.cv.person.location?.value == city)
        #expect(found.cv.person.location?.check == (Places.isKnownPlace(city) ? nil : .locationByPosition), "\(city)")
        #expect(found.unplaced.isEmpty)
    }

    @Test("The cities of the issue are known places, and a lone line far from the contacts is no place")
    func knownAndFarCities() {
        for city in ["Bielefeld", "Reims", "Akron", "Seattle"] {
            let found = header("Jane Rowe\nNurse\n\(city)\njane@example.com")
            #expect(found.cv.person.location?.value == city, "\(city)")
            #expect(found.cv.person.location?.check == nil, "\(city)")
        }
        let far = header("Jane Rowe\nNurse\nHennef\nA line that is a sentence about the work\njane@example.com")
        #expect(far.cv.person.location == nil)
    }

    @Test("The line under the name is the title, not the place, even when the contacts follow it")
    func titleNextToContacts() {
        for title in ["Pharmacologist", "Brand Strategist", "Data Wrangler"] {
            let found = header("Jane Rowe\n\(title)\njane@example.com\n555-555-5555")
            #expect(found.cv.person.title?.value == title, "\(title)")
            #expect(found.cv.person.location == nil, "\(title)")
        }
    }

    @Test("A line of words beside the contacts is no place when it is a phrase")
    func phraseBesideContacts() {
        let found = header("""
        Jane Rowe
        Nurse
        Medical-Surgical Nursing Specialist for Adults
        jane@example.com
        """)
        #expect(found.cv.person.location == nil)
    }

    @Test("A street address is the place, never the title; the city line after it joins it")
    func streetAddress() {
        let found = header("""
        Jane Rowe
        123 Main Street
        Los Angeles, CA 12345
        jane@example.com
        """)
        #expect(found.cv.person.title == nil)
        #expect(found.cv.person.location?.value == "123 Main Street, Los Angeles, CA 12345")
        #expect(found.unplaced.isEmpty)
    }

    @Test("A street address of any language is no title", arguments: [
        "123 Main Street", "45 Park Avenue", "Musterstraße 5", "Via Roma 1", "Calle Mayor 12", "Rue de la Paix 8", "Rua das Flores, 45",
        "Avenida Paulista 1000", "Hauptstr. 12a",
    ])
    func streetIsNoTitle(line: String) {
        let found = header("Jane Rowe\n" + line + "\njane@example.com")
        #expect(found.cv.person.title == nil, "\(line)")
        #expect(found.cv.person.location?.value == line, "\(line)")
    }

    @Test("A title with a digit or a street word is still a title")
    func titleWithStreetWord() {
        for title in ["Wall Street Trader", "Senior Engineer, Level 3", "Boulevard Manager", "Teacher of 5 Classes"] {
            let found = header("Jane Rowe\n\(title)\njane@example.com")
            #expect(found.cv.person.title?.value == title, "\(title)")
        }
    }

    // MARK: A title in parts (#455)

    @Test("A title line cut by separators is the title as written, to be checked, and no part of it is left out", arguments: [
        "iOS Engineer · Platform Lead", "iOS Engineer | Platform Lead", "Senior iOS Engineer · Mobile Platform Lead · Swift",
        "iOS Engineer — Platform Lead",
    ])
    func titleInParts(line: String) {
        let found = header("Tobias Renn\n\(line)\ntobias.renn@example.com")
        #expect(found.cv.person.title?.value == line)
        #expect(found.cv.person.title?.check == .titleByPosition)
        #expect(found.cv.person.location == nil)
        #expect(found.unplaced.map(\.text) == [])
    }

    @Test("A title in one part is not to be checked")
    func titleInOnePart() {
        let found = header("Tobias Renn\nSenior iOS Engineer\ntobias.renn@example.com")
        #expect(found.cv.person.title?.value == "Senior iOS Engineer")
        #expect(found.cv.person.title?.check == nil)
    }

    @Test("A detail of the head after the title joins it and is to be checked, as nothing tells it from a part of the title", arguments: [
        "iOS Engineer · Open to work", "iOS Engineer · German citizen",
    ])
    func detailAfterTheTitle(line: String) {
        let found = header("Tobias Renn\n\(line)\ntobias.renn@example.com")
        #expect(found.cv.person.title?.value == line)
        #expect(found.cv.person.title?.check == .titleByPosition)
        #expect(found.unplaced.map(\.text) == [])
    }

    @Test("Parts of a title in cells of their own are joined by a comma, to be checked")
    func titleInCells() {
        let found = header("Tobias Renn\niOS Engineer\tPlatform Lead\ntobias.renn@example.com")
        #expect(found.cv.person.title?.value == "iOS Engineer, Platform Lead")
        #expect(found.cv.person.title?.check == .titleByPosition)
        #expect(found.unplaced.map(\.text) == [])
    }

    @Test("A part of the title line that names a place is the place, and the parts before it are the title")
    func titleAndPlaceInOneLine() {
        let found = header("Tobias Renn\niOS Engineer · Leipzig\ntobias.renn@example.com")
        #expect(found.cv.person.title?.value == "iOS Engineer")
        #expect(found.cv.person.location?.value == "Leipzig")
        #expect(found.unplaced.map(\.text) == [])
        let longer = header("Tobias Renn\niOS Engineer · Platform Lead · Leipzig, Germany\ntobias.renn@example.com")
        #expect(longer.cv.person.title?.value == "iOS Engineer · Platform Lead")
        #expect(longer.cv.person.location?.value == "Leipzig, Germany")
        #expect(longer.unplaced.map(\.text) == [])
    }

    @Test("A part of the title line with a date is no part of the title, and stays visible")
    func dateAfterTheTitle() {
        let found = header("Tobias Renn\niOS Engineer · 03/2019 - 05/2024\ntobias.renn@example.com")
        #expect(found.cv.person.title?.value == "iOS Engineer")
        #expect(found.unplaced.map(\.text) == ["03/2019 - 05/2024"])
    }

    @Test("The credentials of the name follow a title in parts")
    func titleInPartsWithCredentials() {
        let found = header("Tobias Renn, PhD\nData Scientist · Research Lead\ntobias.renn@example.com")
        #expect(found.cv.person.name?.value == "Tobias Renn")
        #expect(found.cv.person.title?.value == "Data Scientist · Research Lead, PhD")
        #expect(found.unplaced.map(\.text) == [])
    }

    @Test("A head with a title in parts keeps the whole title, its place, and the details it has no field for")
    func headWithATitleInParts() {
        let found = header("""
        Tobias Renn
        iOS Engineer · Platform Lead
        EU citizen · available from March 2027
        Leipzig, Germany
        tobias.renn@example.com · +49 151 2345 6789
        """)
        #expect(found.cv.person.name?.value == "Tobias Renn")
        #expect(found.cv.person.title?.value == "iOS Engineer · Platform Lead")
        #expect(found.cv.person.location?.value == "Leipzig, Germany")
        #expect(found.unplaced.map(\.text) == ["EU citizen", "available from March 2027"])
    }

    // MARK: A title in parts through the whole import (#455)

    @Test("Through the whole import, a title in parts is kept as written, to be checked, and no part of it is lost", arguments: [
        ("Tobias Renn\niOS Engineer · Platform Lead\ntobias.renn@example.com", "iOS Engineer · Platform Lead"),
        ("Tobias Renn\niOS Engineer · Open to work\ntobias.renn@example.com", "iOS Engineer · Open to work"),
        ("Tobias Renn\nSenior iOS Engineer | Mobile Platform Lead | Swift\ntobias.renn@example.com", "Senior iOS Engineer | Mobile Platform Lead | Swift"),
        ("Tobias Renn\niOS Engineer\tPlatform Lead\ntobias.renn@example.com", "iOS Engineer, Platform Lead"),
        ("Tobias Renn\niOS Engineer · Platform Lead\tSwift\ntobias.renn@example.com", "iOS Engineer · Platform Lead, Swift"),
        ("Tobias Renn, PhD\nData Scientist · Research Lead\ntobias.renn@example.com", "Data Scientist · Research Lead, PhD"),
    ])
    func titleInPartsThroughTheImport(text: String, title: String) throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
        #expect(result.cv.person.title?.value == title, "\(text)")
        #expect(result.cv.person.title?.check == .titleByPosition, "\(text)")
        #expect(result.unplaced.map(\.text) == [], "\(text)")
        #expect(Coverage.lost(result).isEmpty, "\(text): \(Coverage.lost(result).map(\.text))")
    }

    @Test("Through the whole import, a title in parts before a place keeps the title and the place")
    func titleInPartsAndPlaceThroughTheImport() throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(
            "Tobias Renn\niOS Engineer · Platform Lead · Leipzig, Germany\ntobias.renn@example.com"
        )
        #expect(result.cv.person.title?.value == "iOS Engineer · Platform Lead")
        #expect(result.cv.person.location?.value == "Leipzig, Germany")
        #expect(result.unplaced.map(\.text) == [])
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.lost(result).map(\.text))")
    }
}
