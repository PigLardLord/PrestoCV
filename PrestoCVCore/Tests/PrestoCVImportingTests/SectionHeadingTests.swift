import Foundation
import Testing
@testable import PrestoCVImporting

/// The headings of the sections that the lists of the vocabulary have besides the skills' (#293), and the headings that
/// are read by their parts: a bracketed qualifier, a generic word, two or more alternatives. Every CV here is invented.
enum SectionHeadings {

    /// A heading a list of the vocabulary has, the kind of section it names and the only language whose list has it.
    static let listed: [(CVLanguage, String, SectionKind)] = [
        // What a CV is proud of and what it is good at: text not imported, under its own heading
        (.en, "Key Achievements", .additional), (.en, "Strengths", .additional), (.en, "Accomplishments", .additional),
        (.it, "Risultati ottenuti", .additional), (.it, "Principali risultati", .additional), (.it, "Punti di forza", .additional),
        (.de, "Erfolge", .additional), (.de, "Wichtigste Erfolge", .additional), (.de, "Stärken", .additional),
        (.es, "Logros clave", .additional), (.es, "Logros destacados", .additional), (.es, "Principales logros", .additional),
        (.fr, "Réalisations", .additional), (.fr, "Principales réalisations", .additional), (.fr, "Réalisations clés", .additional),
        (.fr, "Points forts", .additional),
        (.pt, "Conquistas", .additional), (.pt, "Principais conquistas", .additional), (.pt, "Realizações", .additional),
        (.pt, "Principais realizações", .additional), (.pt, "Pontos fortes", .additional),
        (.it, "Altri dati", .additional),
        // The blocks of an Italian form-style CV
        (.it, "Indirizzo", .personal), (.it, "Altre generalità", .personal),
        // Courses and certificates
        (.de, "Bescheinigungen", .certifications), (.fr, "Cours", .certifications),
        // Passions
        (.de, "Leidenschaften", .interests), (.es, "Pasiones", .interests), (.pt, "Paixões", .interests),
        // Volunteering, also in the singular
        (.de, "Freiwilligenarbeit", .volunteering), (.de, "Ehrenamtliche Tätigkeit", .volunteering),
        // The training and the internships of the CVs that call them so
        (.it, "Esperienze formative", .education), (.de, "Praktika", .experience),
        // The personal qualities
        (.it, "Qualità personali", .skills),
    ]

    /// A heading read by a rule, not by a list: the kind it names and the languages that vote for it, which are the
    /// languages of the heading it is read as, so that the rule takes no share from the language the CV is written in.
    static let derived: [(String, SectionKind, Set<CVLanguage>)] = [
        // A generic word beside a known heading
        ("Resume Summary", .summary, [.en]), ("Objective statement", .summary, [.en]), ("CV Profile", .summary, [.en]),
        // ("Education" is French's too, once its accent is folded: the vote is the one of the heading beside the generic word)
        ("Education and credentials", .education, [.en, .fr]), ("Credentials and education", .education, [.en, .fr]),
        // A qualifier in brackets, which is a heading of the same kind
        ("Competenze tecniche (Hard Skills)", .skills, [.it]), ("Competenze trasversali (Soft Skills)", .skills, [.it]),
        ("Technical skills (hard skills)", .skills, [.en]), ("Berufserfahrung (Work Experience)", .experience, [.de]),
        ("Compétences [Skills]", .skills, [.fr]), ("Hard Skills (Competenze tecniche)", .skills, [.en]),
        // Alternatives of one kind are that kind
        ("Weiterbildung / Kurse", .certifications, [.de]), ("Praktika / Berufliche Erfahrung", .experience, [.de]),
        ("Loisirs & Passions", .interests, [.fr]), ("Tools, Technologies", .skills, [.en]),
        ("Competenze e abilità", .skills, [.it]), ("Hobbys + Interessen", .interests, [.de]),
        // Alternatives of two kinds have no section of their own to be read in: they are text not imported
        ("Ehrenamt & Interessen", .additional, [.de]), ("Formation / Cours", .additional, [.fr]),
        ("Skills and Languages", .additional, [.en]), ("Berufserfahrung und Ausbildung", .additional, [.de]),
    ]

    /// Text that is no heading: a bracket that is no heading of the same kind, a sentence, a generic word alone.
    static let content = [
        "Skills (see the project page)", "Skills (Languages)", "Education (Skills)", "Skills (hard skills",
        "Credentials", "Statement", "Resume and CV",
        "Managed the education and credentials of forty staff", "Education and credentials are listed below",
        "Strengths, weaknesses", "Swift / Kotlin", "Tools for the whole team", "Work & Travel", "Skills in (hard skills) and more",
        // More than seven words
        "Skills, Languages, Interests, Projects, Awards, References, Publications, Memberships",
        "Competenze tecniche e trasversali e informatiche e linguistiche e personali (Hard Skills)",
    ]

    /// The headings of the first sections of the invented CVs, by language.
    static let experience: [CVLanguage: String] = SkillsHeadings.experience
    static let education: [CVLanguage: String] = [
        .en: "Education", .it: "Istruzione", .de: "Ausbildung", .es: "Formación académica", .fr: "Formation", .pt: "Formação",
    ]
}

@Suite("The headings of the sections, by their lists and by their parts")
struct SectionHeadingTests {

    private let limits = ImportLimits.standard

    private func importText(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: limits).importText(text)
    }

    private func importLayout(_ page: ExtractedPage) async throws -> ImportResult {
        try await ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([page])), limits: limits).importPDF(Data([1]))
    }

    private func forms(of heading: String) -> [String] {
        [heading, heading.uppercased(), heading + ":"]
    }

    // MARK: The lists

    @Test("Each heading of the lists names its kind of section, for its language only, in capitals and with a colon", arguments: SectionHeadings.listed)
    func listedHeadings(language: CVLanguage, heading: String, kind: SectionKind) {
        for form in forms(of: heading) {
            let match = SectionVocabulary.kind(ofHeading: form)
            #expect(match?.kind == kind, "\(language) \(form): \(String(describing: match?.kind))")
            #expect(match?.languages == [language], "\(language) \(form): \(String(describing: match?.languages))")
        }
    }

    // MARK: The rules

    @Test("A heading read by its parts names the kind of its parts and keeps the vote of the heading it is read as", arguments: SectionHeadings.derived)
    func derivedHeadings(heading: String, kind: SectionKind, languages: Set<CVLanguage>) {
        for form in forms(of: heading) {
            let match = SectionVocabulary.kind(ofHeading: form)
            #expect(match?.kind == kind, "\(form): \(String(describing: match?.kind))")
            #expect(match?.languages == languages, "\(form): \(String(describing: match?.languages))")
        }
    }

    @Test("Text that is no heading stays no heading, whatever words of the headings it has", arguments: SectionHeadings.content)
    func contentIsNoHeading(text: String) {
        for form in forms(of: text) {
            #expect(SectionVocabulary.kind(ofHeading: form) == nil, "\(form)")
        }
    }

    @Test("A heading read by its parts does not weaken the language of the CV: Italian alternatives still vote for Italian")
    func votes() throws {
        let result = try importText("""
        Marta Ferri
        Elettricista

        Esperienza lavorativa
        Elettricista, Impianti Esempio S.r.l.
        09/2019 – oggi

        Competenze tecniche (Hard Skills)
        Cablaggio, Diagnostica
        """)
        #expect(result.language == .it)
        #expect(result.cv.skills.map(\.value) == ["Cablaggio", "Diagnostica"])
    }

    // MARK: The sections

    /// A CV pasted as text: the work experience, an education, and a section under `heading`.
    private func pastedText(_ language: CVLanguage, heading: String) throws -> String {
        """
        Alex Example
        Software Engineer

        \(try #require(SectionHeadings.experience[language]))
        Software Engineer, Example Ltd
        03/2019 – 05/2024

        \(try #require(SectionHeadings.education[language]))
        BSc Computing, Example University, 2016

        \(heading)
        First line of the section
        Second line of the section
        """
    }

    /// The same CV drawn on a page: a bold heading for each section.
    private func page(_ language: CVLanguage, heading: String) throws -> ExtractedPage {
        var sketch = PageSketch()
        sketch.put("Alex Example", x: 50, y: 50, size: 20, bold: true)
        sketch.put("Software Engineer", x: 50, y: 80)
        sketch.put(try #require(SectionHeadings.experience[language]), x: 50, y: 120, size: 13, bold: true)
        sketch.put("Software Engineer, Example Ltd", x: 50, y: 140, bold: true)
        sketch.put("03/2019 – 05/2024", x: 50, y: 155)
        sketch.put(try #require(SectionHeadings.education[language]), x: 50, y: 200, size: 13, bold: true)
        sketch.put("BSc Computing, Example University, 2016", x: 50, y: 220)
        sketch.put(heading, x: 50, y: 280, size: 13, bold: true)
        sketch.put("First line of the section", x: 50, y: 300)
        sketch.put("Second line of the section", x: 50, y: 315)
        return sketch.page
    }

    private func expectOpens(_ kind: SectionKind, _ heading: String, in result: ImportResult, _ label: String) {
        let sections = SectionSegmenter.sections(of: result.document)
        #expect(sections.map(\.kind) == [.header, .experience, .education, kind], "\(label): \(sections.map(\.kind))")
        guard let last = sections.last, last.kind == kind else { return }
        #expect(last.heading.map { result.document.text(of: $0.span) } == heading, "\(label)")
    }

    @Test("A heading of the lists opens its section, in a pasted text and in a drawn page, and the lines under it stay out of the section before it",
          arguments: SectionHeadings.listed)
    func listedHeadingsOpenSections(language: CVLanguage, heading: String, kind: SectionKind) async throws {
        let pasted = try importText(pastedText(language, heading: heading))
        expectOpens(kind, heading, in: pasted, "pasted \(language) \(heading)")
        let sections = SectionSegmenter.sections(of: pasted.document)
        #expect(sections.last?.blocks.map { pasted.document.text(of: $0.span) } == ["First line of the section", "Second line of the section"],
                "\(language) \(heading)")
        expectOpens(kind, heading, in: try await importLayout(page(language, heading: heading)), "drawn \(language) \(heading)")
    }

    @Test("A heading read by its parts opens its section, in a pasted text and in a drawn page", arguments: SectionHeadings.derived)
    func derivedHeadingsOpenSections(heading: String, kind: SectionKind, languages: Set<CVLanguage>) async throws {
        let language = try #require(languages.first)
        for form in [heading, heading.uppercased()] {
            expectOpens(kind, form, in: try importText(pastedText(language, heading: form)), "pasted \(form)")
            expectOpens(kind, form, in: try await importLayout(page(language, heading: form)), "drawn \(form)")
        }
    }

    @Test("A sentence with the words of a heading stays a line of its section")
    func sentenceInAJob() throws {
        for sentence in ["Managed the education and credentials of forty staff", "Education and credentials are listed below", "Strengths, weaknesses"] {
            let result = try importText("""
            Alex Example

            Work Experience
            Software Engineer, Example Ltd
            03/2019 – 05/2024
            \(sentence)
            """)
            #expect(SectionSegmenter.sections(of: result.document).map(\.kind) == [.header, .experience], "\(sentence)")
        }
    }

    // MARK: Found by the study (#289)

    @Test("The education that follows the skills is no skill, under a heading with a generic word")
    func educationAfterSkills() throws {
        let result = try importText("""
        Sam Rivera
        Electrician

        Experience
        Electrician, Local Union 4
        2018 – present

        Skills
        Wiring
        Diagnostics

        Education and credentials
        Associate degree in business, Warner Institute, 2009
        """)
        #expect(result.cv.skills.map(\.value) == ["Wiring", "Diagnostics"])
        #expect(result.cv.education.map { $0.degree?.value } == ["Associate degree in business"])
        #expect(result.cv.education.map { $0.school?.value } == ["Warner Institute"])
        #expect(result.unplaced.isEmpty, "\(result.unplaced.map(\.text))")
    }

    @Test("A sentence of the achievements is no detail of the education: it is text not imported, with its heading")
    func achievementsAfterEducation() throws {
        let result = try importText("""
        Sam Rivera
        Nurse

        Education
        BSc Nursing, University of Leeds, 2016

        Key Achievements
        Raised patient satisfaction by 12%
        """)
        #expect(result.cv.education.count == 1)
        #expect(result.cv.education.first?.details.isEmpty == true)
        #expect(result.unplaced.map(\.text) == ["Raised patient satisfaction by 12%"])
        #expect(result.unplaced.first?.heading == "Key Achievements")
        #expect(result.unplaced.first?.section == .additional)
    }

    @Test("The blocks of an Italian form-style CV after the experience are personal details, not lines of the last job")
    func italianFormBlocks() throws {
        let result = try importText("""
        Marta Ferri
        Elettricista

        Esperienza lavorativa
        Elettricista, Impianti Esempio S.r.l.
        09/2019 – oggi

        Indirizzo
        Via Esempio 12, 20100 Milano

        Altre generalità
        Nata a Milano il 04/03/1990
        """)
        #expect(SectionSegmenter.sections(of: result.document).map(\.kind) == [.header, .experience, .personal, .personal])
        #expect(result.cv.person.location?.value == "Via Esempio 12, 20100 Milano")
        #expect(result.cv.experience.allSatisfy { $0.details.isEmpty }, "\(result.cv.experience.map(\.details))")
        let general = result.unplaced.filter { $0.heading == "Altre generalità" }
        #expect(general.map(\.text) == ["Nata a Milano il 04/03/1990"])
        #expect(general.first?.section == .personal)
    }

    @Test("In a form-style CV the birth lines are no residence: the municipality under the address heading is the place")
    func birthLinesAreNoResidence() throws {
        let result = try importText("""
        CURRICULUM VITAE
        di MARTA FERRI

        ANAGRAFICA
        Nome: Marta
        Cognome: Ferri
        Data di nascita: 04/03/1990
        Luogo di nascita: Torino
        Provincia di nascita: Torino
        Stato di nascita: Italia

        INDIRIZZO
        Via/viale/piazza: Esempio
        Numero: 12
        Comune: Milano
        Provincia: Milano
        """)
        #expect(result.cv.person.location?.value == "Milano", "\(String(describing: result.cv.person.location?.value))")
        let texts = result.unplaced.map(\.text)
        #expect(texts.contains("Stato di nascita: Italia"), "\(texts)")
        #expect(texts.contains("Provincia di nascita: Torino"), "\(texts)")
    }

    @Test("Two kinds of section under one heading are shown as text not imported, with that heading")
    func twoKinds() throws {
        let result = try importText("""
        Sam Rivera
        Teacher

        Education
        BEd Primary Teaching, University of Leeds, 2016

        Ehrenamt & Interessen
        Youth football coach
        Chess
        """)
        #expect(result.cv.education.count == 1)
        #expect(result.cv.interests.isEmpty)
        #expect(result.unplaced.map(\.text) == ["Youth football coach", "Chess"])
        #expect(result.unplaced.first?.heading == "Ehrenamt & Interessen")
    }
}
