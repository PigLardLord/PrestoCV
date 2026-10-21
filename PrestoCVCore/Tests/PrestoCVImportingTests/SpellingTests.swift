import Testing
@testable import PrestoCVImporting

/// Normalisation keeps the person's spelling: a soft hyphen takes nothing else away, a compound keeps its hyphen, and a
/// hyphen at a line's end goes only when the next line goes on in lower case.
@Suite("Keeping the spelling of an imported CV")
struct SpellingTests {

    struct Row: Sendable, CustomTestStringConvertible {
        var language: CVLanguage
        var text: String
        var summary: String
        var skills: [String]

        var testDescription: String { "\(language)" }
    }

    static let rows: [Row] = [
        Row(language: .en, text: """
        # Alex Morgan
        ## Profile
        Full-stack developer with ten years of experience in soft\u{AD}
        ware for e-commerce.
        ## Skills
        - Test automa\u{AD}
          tion with XCTest
        - Full-stack web development
        - Project manage-
          ment
        """, summary: "Full-stack developer with ten years of experience in software for e-commerce.",
        skills: ["Test automation with XCTest", "Full-stack web development", "Project management"]),
        Row(language: .de, text: """
        # Hannah Krüger
        ## Profil
        Full-Stack-Entwicklerin mit zehn Jahren Erfahrung in der Soft\u{AD}
        wareentwicklung für E-Mail-Dienste.
        ## Kenntnisse
        - Entwick\u{AD}
          lung von Apps
        - E-Mail-Marketing
        - Projekt-
          leitung
        """, summary: "Full-Stack-Entwicklerin mit zehn Jahren Erfahrung in der Softwareentwicklung für E-Mail-Dienste.",
        skills: ["Entwicklung von Apps", "E-Mail-Marketing", "Projektleitung"]),
        Row(language: .it, text: """
        # Chiara Lombardi
        ## Profilo
        Sviluppatrice full-stack con dieci anni di esperienza nello svi\u{AD}
        luppo di servizi e-mail.
        ## Competenze
        - Progetta\u{AD}
          zione di app
        - Sviluppo front-end
        - Gestione dei pro-
          getti
        """, summary: "Sviluppatrice full-stack con dieci anni di esperienza nello sviluppo di servizi e-mail.",
        skills: ["Progettazione di app", "Sviluppo front-end", "Gestione dei progetti"]),
        Row(language: .fr, text: """
        # Camille Laurent
        ## Profil
        Développeuse full-stack avec dix ans d'expérience en dévelop\u{AD}
        pement d'applications d'e-mail.
        ## Compétences
        - Concep\u{AD}
          tion d'applications
        - Service après-vente
        - Gestion de pro-
          jets
        """, summary: "Développeuse full-stack avec dix ans d'expérience en développement d'applications d'e-mail.",
        skills: ["Conception d'applications", "Service après-vente", "Gestion de projets"]),
        Row(language: .es, text: """
        # Lucía Romero
        ## Perfil
        Desarrolladora full-stack con diez años de experiencia en desa\u{AD}
        rrollo de servicios de e-mail.
        ## Habilidades
        - Planifica\u{AD}
          ción de proyectos
        - Marketing por e-mail
        - Gestión de equi-
          pos
        """, summary: "Desarrolladora full-stack con diez años de experiencia en desarrollo de servicios de e-mail.",
        skills: ["Planificación de proyectos", "Marketing por e-mail", "Gestión de equipos"]),
        Row(language: .pt, text: """
        # Beatriz Carvalho
        ## Perfil
        Desenvolvedora full-stack com dez anos de experiência em desen\u{AD}
        volvimento de serviços de e-mail.
        ## Competências
        - Planea\u{AD}
          mento de projetos
        - Serviço pós-venda
        - Gestão de equi-
          pas
        """, summary: "Desenvolvedora full-stack com dez anos de experiência em desenvolvimento de serviços de e-mail.",
        skills: ["Planeamento de projetos", "Serviço pós-venda", "Gestão de equipas"]),
    ]

    @Test("Soft hyphens, compound hyphens and hyphens at a line's end keep the exact spelling", arguments: rows)
    func spelling(_ row: Row) throws {
        let result = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(row.text)
        #expect(result.cv.person.summary?.value == row.summary)
        #expect(result.cv.skills.map(\.value) == row.skills)
        #expect(result.language == row.language)
        #expect(result.ungrounded.isEmpty)
    }
}
