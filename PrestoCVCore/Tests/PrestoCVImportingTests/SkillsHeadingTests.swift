import Foundation
import Testing
@testable import PrestoCVImporting

/// The headings under which CVs list their skills, in each language. Every CV here is invented.
enum SkillsHeadings {

    /// A heading and the language whose list of the vocabulary must have it.
    static let all: [(CVLanguage, String)] = [
        // The ones a CV gives its skills besides "Skills" (#287)
        (.en, "Technologies"), (.en, "Tech stack"), (.en, "Tools"), (.en, "Technical skills"), (.en, "Core skills"),
        (.en, "Key skills"), (.en, "Competencies"), (.en, "Tools & Technologies"), (.en, "Technologies and tools"),
        (.en, "Technology stack"), (.en, "Technical expertise"), (.en, "Core Technologies"), (.en, "Key technologies"),
        (.it, "Competenze tecniche"), (.it, "Conoscenze informatiche"), (.it, "Tecnologie"), (.it, "Strumenti"),
        (.it, "Stack tecnologico"), (.it, "Competenze chiave"), (.it, "Strumenti e tecnologie"), (.it, "Conoscenze tecniche"), (.it, "Tecnologie principali"),
        (.de, "Kenntnisse"), (.de, "Technische Kenntnisse"), (.de, "IT-Kenntnisse"), (.de, "Technologien"),
        (.de, "Werkzeuge"), (.de, "Tech-Stack"), (.de, "Kernkompetenzen"), (.de, "Technische Fähigkeiten"), (.de, "Kerntechnologien"),
        (.es, "Conocimientos técnicos"), (.es, "Herramientas"), (.es, "Tecnologías"), (.es, "Stack tecnológico"),
        (.es, "Competencias clave"), (.es, "Herramientas y tecnologías"), (.es, "Tecnologías principales"),
        (.fr, "Compétences techniques"), (.fr, "Outils"), (.fr, "Stack technique"),
        (.fr, "Connaissances techniques"), (.fr, "Outils et technologies"), (.fr, "Technologies principales"),
        (.pt, "Competências técnicas"), (.pt, "Ferramentas"), (.pt, "Tecnologias"), (.pt, "Conhecimentos técnicos"),
        (.pt, "Stack tecnológico"), (.pt, "Ferramentas e tecnologias"), (.pt, "Tecnologias principais"),
        // The ones the study found besides (#293)
        (.de, "Fertigkeiten"), (.de, "Besondere Qualifikationen"), (.it, "Abilità e competenze"), (.it, "Software e strumenti"),
        (.pt, "Qualificações essenciais"),
    ]

    /// Headings that a CV of a language borrows from another: the vocabulary reads the CV under them, and they keep the
    /// vote of the language that has them, so that they do not weaken it in telling the language of a CV.
    static let borrowed: [(language: CVLanguage, heading: String, votes: Set<CVLanguage>)] = [
        (.fr, "Technologies", [.en]), (.de, "Tools", [.en]), (.pt, "Habilidades técnicas", [.es]),
    ]

    /// The heading of the work experience in each language, so that the CV's headings tell its language.
    static let experience: [CVLanguage: String] = [
        .en: "Work Experience", .it: "Esperienza lavorativa", .de: "Berufserfahrung", .es: "Experiencia profesional",
        .fr: "Expérience professionnelle", .pt: "Experiência profissional",
    ]

    /// The skills the invented CVs list.
    static let skills = ["Swift", "SwiftUI", "Combine", "Kotlin", "Docker"]

    /// Sentences of a job description with a word that is also a heading, by language.
    static let sentences: [(CVLanguage, String)] = [
        (.en, "Built internal tools for the support team"), (.en, "Tools for the whole team"),
        (.en, "Migrated the technologies of the billing service"), (.en, "Tech stack review with the architects"),
        (.it, "Sviluppo di strumenti interni per il supporto"), (.it, "Tecnologie per la sanità digitale"),
        (.de, "Entwicklung interner Werkzeuge für das Support-Team"), (.de, "Tools für die Abrechnung entwickelt"),
        (.de, "Technologien der Abrechnung modernisiert"),
        (.es, "Herramientas internas para el equipo de soporte"), (.es, "Tecnologías de la facturación modernizadas"),
        (.fr, "Outils internes pour l'équipe de support"), (.fr, "Technologies de la facturation modernisées"),
        (.pt, "Ferramentas internas para a equipa de suporte"), (.pt, "Tecnologias da faturação modernizadas"),
    ]
}

@Suite("Skills under the headings a CV gives them")
struct SkillsHeadingTests {

    private let limits = ImportLimits.standard

    private func importText(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: limits).importText(text)
    }

    private func importLayout(_ page: ExtractedPage) async throws -> ImportResult {
        try await ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([page])), limits: limits).importPDF(Data([1]))
    }

    private func experienceHeading(_ language: CVLanguage) throws -> String {
        try #require(SkillsHeadings.experience[language])
    }

    /// A CV pasted as text, its skills under `heading`.
    private func pastedText(_ language: CVLanguage, heading: String) throws -> String {
        """
        Alex Example
        Software Engineer

        \(try experienceHeading(language))
        Software Engineer, Example Ltd
        03/2019 – 05/2024

        \(heading)
        Swift, SwiftUI, Combine
        Kotlin; Docker
        """
    }

    /// The page of a PDF: the name, a bold heading for each section, the skills as lines of the body.
    private func page(_ language: CVLanguage, heading: String) throws -> ExtractedPage {
        var sketch = PageSketch()
        sketch.put("Alex Example", x: 50, y: 50, size: 20, bold: true)
        sketch.put("Software Engineer", x: 50, y: 80)
        sketch.put(try experienceHeading(language), x: 50, y: 120, size: 13, bold: true)
        sketch.put("Software Engineer, Example Ltd", x: 50, y: 140, bold: true)
        sketch.put("03/2019 – 05/2024", x: 50, y: 155)
        sketch.put(heading, x: 50, y: 200, size: 13, bold: true)
        sketch.put("Swift, SwiftUI, Combine", x: 50, y: 220)
        sketch.put("Kotlin; Docker", x: 50, y: 235)
        return sketch.page
    }

    private func expectSkillsRead(_ result: ImportResult, _ language: CVLanguage, _ label: String) {
        #expect(result.cv.skills.map(\.value) == SkillsHeadings.skills, "\(label)")
        #expect(result.unplaced.isEmpty, "\(label): text not imported: \(result.unplaced.map(\.text))")
        #expect(result.ungrounded.isEmpty, "\(label)")
        #expect(result.cv.experience.count == 1, "\(label): the skills must not go into the experience")
        #expect(result.language == language, "\(label): \(String(describing: result.language))")
    }

    @Test("The vocabulary knows each heading of the skills, for its language, in capitals and with a colon", arguments: SkillsHeadings.all)
    func knownHeadings(language: CVLanguage, heading: String) {
        for form in [heading, heading.uppercased(), heading + ":"] {
            let match = SectionVocabulary.kind(ofHeading: form)
            #expect(match?.kind == .skills, "\(language) \(form)")
            #expect(match?.languages.contains(language) == true, "\(language) \(form): \(String(describing: match?.languages))")
        }
    }

    @Test("No heading of the vocabulary names two kinds of section, whatever its language")
    func noHeadingNamesTwoKinds() {
        var kinds: [String: SectionKind] = [:]
        for (kind, byLanguage) in SectionVocabulary.entries {
            for (language, headings) in byLanguage {
                for heading in headings {
                    let key = SectionVocabulary.key(heading)
                    if let other = kinds[key], other != kind { Issue.record("\(language) \(heading) is both \(other) and \(kind)") }
                    kinds[key] = kind
                }
            }
        }
    }

    @Test("A heading a language borrows is read as skills and keeps the vote of the language that has it", arguments: SkillsHeadings.borrowed)
    func borrowedHeadings(language: CVLanguage, heading: String, votes: Set<CVLanguage>) async throws {
        for form in [heading, heading.uppercased(), heading + ":"] {
            let match = SectionVocabulary.kind(ofHeading: form)
            #expect(match?.kind == .skills, "\(language) \(form)")
            #expect(match?.languages == votes, "\(language) \(form): \(String(describing: match?.languages))")
        }
        for result in [try importText(pastedText(language, heading: heading)), try await importLayout(page(language, heading: heading))] {
            #expect(result.cv.skills.map(\.value) == SkillsHeadings.skills, "\(language) \(heading)")
            #expect(result.unplaced.isEmpty, "\(language) \(heading): text not imported: \(result.unplaced.map(\.text))")
            #expect(result.cv.experience.count == 1, "\(language) \(heading)")
        }
    }

    @Test("An English CV stays English under a heading that French has too, with French names of employers")
    func englishCVKeepsItsLanguage() throws {
        let result = try importText("""
        Alex Example
        Software Engineer

        Experience
        Developer, Le Monde
        03/2019 – 05/2024
        Built APIs for Les Echos

        Technologies
        Swift, Docker
        """)
        #expect(result.cv.skills.map(\.value) == ["Swift", "Docker"])
        #expect(result.language == .en)
    }

    @Test("A pasted CV with its skills under the heading has them read as skills, and nothing is left over", arguments: SkillsHeadings.all)
    func pastedText(language: CVLanguage, heading: String) throws {
        expectSkillsRead(try importText(pastedText(language, heading: heading)), language, "\(language) \(heading)")
    }

    @Test("A chat answer with its skills as a list under the heading has them read as skills", arguments: SkillsHeadings.all)
    func chatAnswer(language: CVLanguage, heading: String) throws {
        let text = """
        # Alex Example
        **Software Engineer**

        ## \(try experienceHeading(language))
        **Software Engineer** | Example Ltd | 03/2019 – 05/2024

        ## \(heading)
        - Swift
        - SwiftUI
        - Combine
        - Kotlin
        - Docker
        """
        let result = try importText(text)
        #expect(result.cv.skills.map(\.value) == SkillsHeadings.skills, "\(language) \(heading)")
        #expect(result.unplaced.isEmpty, "\(language) \(heading): text not imported: \(result.unplaced.map(\.text))")
    }

    @Test("A PDF's layout with its skills under the heading, bold or in capitals, has them read as skills", arguments: SkillsHeadings.all)
    func drawnLayout(language: CVLanguage, heading: String) async throws {
        for form in [heading, heading.uppercased()] {
            expectSkillsRead(try await importLayout(page(language, heading: form)), language, "\(language) \(form)")
        }
    }

    @Test("The word of a heading inside a sentence of a job description opens no section", arguments: SkillsHeadings.sentences)
    func sentences(language: CVLanguage, sentence: String) async throws {
        #expect(SectionVocabulary.kind(ofHeading: sentence) == nil, "\(sentence)")

        func sketch(_ line: String) throws -> ExtractedPage {
            var sketch = PageSketch()
            sketch.put("Alex Example", x: 50, y: 50, size: 20, bold: true)
            sketch.put(try experienceHeading(language), x: 50, y: 120, size: 13, bold: true)
            sketch.put("Software Engineer, Example Ltd", x: 50, y: 140, bold: true)
            sketch.put("03/2019 – 05/2024", x: 50, y: 155)
            sketch.put(line, x: 50, y: 170)
            return sketch.page
        }
        func text(_ line: String) throws -> String {
            "Alex Example\n\n\(try experienceHeading(language))\nSoftware Engineer, Example Ltd\n03/2019 – 05/2024\n\(line)"
        }

        // On a line of its own, the sentence stays in the job
        for (form, result) in [("pasted", try importText(text(sentence))), ("drawn", try await importLayout(sketch(sentence)))] {
            #expect(SectionSegmenter.sections(of: result.document).map(\.kind) == [.header, .experience], "\(form) \(sentence)")
            #expect(result.cv.skills.isEmpty, "\(form) \(sentence): \(result.cv.skills.map(\.value))")
        }
        // As a bullet of the job, it is a detail of the job
        for (form, result) in [("pasted", try importText(text("- " + sentence))), ("drawn", try await importLayout(sketch("• " + sentence)))] {
            #expect(result.cv.skills.isEmpty, "\(form) \(sentence): \(result.cv.skills.map(\.value))")
            #expect(result.cv.experience.first?.details.map(\.value) == [sentence], "\(form) \(sentence)")
        }
    }

    @Test("A bullet of a job description that is only a heading's word is no heading")
    func bulletOfAJob() throws {
        for word in ["Tools", "Outils", "Herramientas", "Ferramentas", "Werkzeuge", "Tecnologie"] {
            let result = try importText("""
            Alex Example

            Work Experience
            Software Engineer, Example Ltd
            03/2019 – 05/2024
            - \(word)
            - Built the billing service
            """)
            #expect(result.cv.skills.isEmpty, "\(word): \(result.cv.skills.map(\.value))")
            #expect(result.cv.experience.first?.details.map(\.value) == [word, "Built the billing service"], "\(word)")
        }
    }

    @Test("Skills under a heading the vocabulary does not know stay visible as text not imported, with that heading")
    func unknownHeading() async throws {
        let pasted = try importText("""
        # Alex Example

        ## Work Experience
        **Software Engineer** | Example Ltd | 03/2019 – 05/2024

        ## My toolbox
        - Swift
        - Docker
        """)
        #expect(pasted.cv.skills.isEmpty)
        #expect(pasted.unplaced.map(\.text) == ["Swift", "Docker"])
        #expect(pasted.unplaced.first?.heading == "My toolbox")

        var sketch = PageSketch()
        sketch.put("Alex Example", x: 50, y: 50, size: 20, bold: true)
        sketch.put("Work Experience", x: 50, y: 120, size: 13, bold: true)
        sketch.put("Software Engineer, Example Ltd", x: 50, y: 140, bold: true)
        sketch.put("03/2019 – 05/2024", x: 50, y: 155)
        sketch.put("MY TOOLBOX", x: 50, y: 200, size: 13, bold: true)
        sketch.put("Swift, Docker", x: 50, y: 220)
        let drawn = try await importLayout(sketch.page)
        #expect(drawn.cv.skills.isEmpty)
        #expect(drawn.unplaced.map(\.text) == ["Swift, Docker"])
        #expect(drawn.unplaced.first?.heading == "MY TOOLBOX")
    }
}
