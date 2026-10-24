import Testing
@testable import PrestoCVImporting

@Suite("Finding the sections by their headings")
struct SectionSegmenterTests {

    private func sections(_ text: String) -> [(SectionKind, String?, [String])] {
        let (document, _) = DocumentBuilder.build(lines: PlainTextReader.lines(of: text).map { RawLine(text: $0) }, format: .pastedText)
        return SectionSegmenter.sections(of: document).map { section in
            (section.kind, section.heading.map { document.text(of: $0.span) }, section.blocks.map { document.text(of: $0.span) })
        }
    }

    @Test("Headings and their synonyms in six languages, the Europass's and the Lebenslauf's", arguments: [
        ("Work Experience", SectionKind.experience), ("ESPERIENZA LAVORATIVA", .experience), ("Esperienze professionali:", .experience),
        ("Berufserfahrung", .experience), ("Beruflicher Werdegang", .experience), ("Experiencia laboral", .experience),
        ("Expérience professionnelle", .experience), ("Experiência profissional", .experience),
        ("Education & Training", .education), ("ISTRUZIONE E FORMAZIONE", .education), ("Ausbildung", .education),
        ("Schulbildung", .education), ("Formación académica", .education), ("Formation", .education), ("Formação académica", .education),
        ("Professional Summary", .summary), ("Profilo professionale", .summary), ("Über mich", .summary), ("Kurzprofil", .summary),
        ("Perfil profesional", .summary), ("Profil", .summary), ("Sobre mim", .summary),
        ("Skills", .skills), ("Top Skills", .skills), ("Competenze tecniche", .skills), ("EDV-Kenntnisse", .skills),
        ("Habilidades", .skills), ("Compétences", .skills), ("Competências", .skills),
        ("CAPACITÀ E COMPETENZE PERSONALI", .skills),
        ("Languages", .languages), ("Lingue straniere", .languages), ("Sprachkenntnisse", .languages), ("Idiomas", .languages),
        ("Langues", .languages), ("Línguas", .languages),
        ("Certifications", .certifications), ("Certificazioni", .certifications), ("Weiterbildungen", .certifications),
        ("Certificaciones", .certifications), ("Certificats", .certifications), ("Certificações", .certifications),
        ("Hobbies & Interests", .interests), ("Interessi", .interests), ("Hobbys", .interests), ("Aficiones", .interests),
        ("Centres d’intérêt", .interests), ("Interesses", .interests),
        ("Persönliche Daten", .personal), ("INFORMAZIONI PERSONALI", .personal), ("Contact", .personal), ("Datos personales", .personal),
        ("References", .references), ("Referenzen", .references), ("Ehrenamtliches Engagement", .volunteering),
        ("Projects", .projects), ("Führerschein", .drivingLicence), ("ULTERIORI INFORMAZIONI", .additional),
    ] as [(String, SectionKind)])
    func vocabulary(heading: String, kind: SectionKind) {
        #expect(SectionVocabulary.kind(ofHeading: heading)?.kind == kind, "\(heading)")
    }

    @Test("A line of content is no heading")
    func notHeadings() {
        for line in ["Swift, Kotlin", "Senior iOS Developer", "Led a team of 5", "Acme S.p.A.", "Experience with Swift since 2015"] {
            #expect(SectionVocabulary.kind(ofHeading: line) == nil, "\(line)")
        }
    }

    @Test("Blocks before the first heading are the head of the CV; each heading opens its section")
    func segmentation() {
        let found = sections("""
        Lena Hartmann
        Elektrikerin

        Berufserfahrung
        03/2019 – heute	Elektrikerin, Beispiel GmbH

        Sprachen
        Deutsch – Muttersprache
        """)
        #expect(found.map(\.0) == [.header, .experience, .languages])
        #expect(found[0].2 == ["Lena Hartmann", "Elektrikerin"])
        #expect(found[1].1 == "Berufserfahrung")
        #expect(found[2].2 == ["Deutsch – Muttersprache"])
    }

    @Test("A heading the vocabulary does not know opens a section of unknown kind when the text marks it as one")
    func unknownHeading() {
        let found = sections("# Giulia Bianchi\n## Esperienza\n- Assistenza\n## Il mio motto\nSempre avanti")
        #expect(found.map(\.0) == [.header, .experience, .unknown])
        #expect(found[0].2 == ["Giulia Bianchi"])
        #expect(found[2].1 == "Il mio motto")
    }

    @Test("A heading of the first level with the shape of a name stays in the head, whatever its words; after the head it opens a section")
    func nameHeading() {
        for name in ["Thomas Kiel", "Rebecca Cook", "Anna Weber"] {
            let found = sections("person@example.com\n\n# \(name)\nNurse\n\n## Experience\n2019 - 2021 Nurse")
            #expect(found.map(\.0) == [.header, .experience], "\(name)")
            #expect(found[0].2 == ["person@example.com", name, "Nurse"], "\(name)")
            let later = sections("# Giulia Bianchi\n## Esperienza\n- Assistenza\n# \(name)\nSempre avanti")
            #expect(later.map(\.0) == [.header, .experience, .unknown], "\(name)")
            #expect(later.count == 3 && later[2].1 == name, "\(name)")
        }
    }

    @Test("A Europass row of the mother tongue opens the languages and stays in them")
    func europassLanguageRows() {
        let found = sections("CAPACITÀ E COMPETENZE PERSONALI\nMADRELINGUA\tItaliano\nALTRE LINGUE\tInglese")
        #expect(found.map(\.0) == [.skills, .languages])
        #expect(found[1].2 == ["MADRELINGUA\tItaliano", "ALTRE LINGUE\tInglese"])
    }

    @Test("The vocabulary of the headings tells the language of the CV")
    func language() {
        let (document, _) = DocumentBuilder.build(
            lines: PlainTextReader.lines(of: "Lena Hartmann\nBerufserfahrung\nx\nAusbildung\ny\nSprachen\nz").map { RawLine(text: $0) },
            format: .pastedText
        )
        #expect(SectionSegmenter.language(of: SectionSegmenter.sections(of: document), in: document) == .de)
    }
}
