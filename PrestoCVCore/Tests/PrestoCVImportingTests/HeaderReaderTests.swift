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
            sections.filter { $0.kind == .header || $0.kind == .personal },
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
}
