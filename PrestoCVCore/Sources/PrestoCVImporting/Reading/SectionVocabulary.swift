// MARK: - Languages and sections

/// The six languages whose vocabulary the import knows, by their BCP 47 tags.
public enum CVLanguage: String, Hashable, Sendable, CaseIterable {
    case en, it, de, es, fr, pt
}

/// The kinds of section a CV has.
public enum SectionKind: String, Hashable, Sendable, CaseIterable {
    /// What comes before the first heading: the name, the title, the contacts.
    case header
    case personal
    case summary
    case experience
    case education
    case skills
    case languages
    case certifications
    case interests
    case projects
    case volunteering
    case references
    case drivingLicence
    /// Additional information, awards, publications, annexes.
    case additional
    /// A heading the vocabulary does not know.
    case unknown
}

// MARK: - The vocabulary

/// The closed vocabulary of section headings in English, Italian, German, Spanish, French and Portuguese, with their
/// synonyms and the labels of the Europass, the Italian "formato europeo", the German Lebenslauf and LinkedIn's PDF.
enum SectionVocabulary {

    struct Match: Equatable {
        let kind: SectionKind
        let languages: Set<CVLanguage>
    }

    /// The kind of section a heading names, or nil when the vocabulary does not know it.
    static func kind(ofHeading text: String) -> Match? {
        index[key(text)]
    }

    /// The labels of the Europass that open the languages: "Madrelingua", "Mother tongue(s)", "Altre lingue".
    static func isLanguageLabel(_ text: String) -> Bool {
        languageLabels.contains(key(text))
    }

    /// The form a heading is compared in: folded, its punctuation and symbols spaces, the words that join two nouns
    /// ("e", "and", "und", "y", "et") left out.
    static func key(_ text: String) -> String {
        var cleaned = ""
        for character in text.folded {
            cleaned.append(character.isLetter || character.isNumber ? character : " ")
        }
        return cleaned.split(separator: " ").filter { !joiningWords.contains(String($0)) }.joined(separator: " ")
    }

    private static let joiningWords: Set<String> = ["and", "e", "und", "y", "et", "s"]

    private static let languageLabels: Set<String> = Set([
        "madrelingua", "madrelingue", "lingua madre", "altre lingue", "altra lingua", "mother tongue", "mother tongues",
        "other language", "other languages", "muttersprache", "muttersprachen", "weitere sprachen", "andere sprachen",
        "lengua materna", "lenguas maternas", "otros idiomas", "otras lenguas", "langue maternelle", "langues maternelles",
        "autres langues", "lingua materna", "línguas maternas", "outras línguas", "outros idiomas",
    ].map(key))

    private static let index: [String: Match] = {
        var table: [String: Match] = [:]
        for (kind, byLanguage) in entries {
            for (language, headings) in byLanguage {
                for heading in headings {
                    let k = key(heading)
                    let languages = (table[k]?.languages ?? []).union([language])
                    table[k] = Match(kind: table[k]?.kind ?? kind, languages: languages)
                }
            }
        }
        return table
    }()

    static let entries: [(SectionKind, [(CVLanguage, [String])])] = [
        (.personal, [
            (.en, ["personal information", "personal details", "personal data", "contact", "contacts", "contact information", "contact details", "personal info"]),
            (.it, ["informazioni personali", "dati personali", "contatti", "recapiti", "dati anagrafici", "anagrafica", "contatto"]),
            (.de, ["persönliche daten", "persönliche angaben", "kontakt", "kontaktdaten", "persönliches", "angaben zur person"]),
            (.es, ["información personal", "datos personales", "contacto", "datos de contacto", "información de contacto", "contactar"]),
            (.fr, ["informations personnelles", "coordonnées", "contact", "état civil", "données personnelles"]),
            (.pt, ["informações pessoais", "dados pessoais", "contacto", "contactos", "contato", "contatos", "dados de contacto", "contactar"]),
        ]),
        (.summary, [
            (.en, ["summary", "professional summary", "profile", "professional profile", "about me", "about", "personal statement",
                   "career summary", "objective", "career objective", "overview", "executive summary", "personal profile", "introduction"]),
            (.it, ["profilo", "profilo professionale", "sommario", "sintesi", "chi sono", "su di me", "presentazione", "obiettivo",
                   "obiettivo professionale", "profilo personale", "riepilogo", "in breve"]),
            (.de, ["profil", "kurzprofil", "über mich", "zusammenfassung", "persönliches profil", "berufsprofil", "zielsetzung",
                   "karriereziel", "profil und ziele", "mein profil"]),
            (.es, ["perfil", "perfil profesional", "resumen", "resumen profesional", "sobre mí", "acerca de mí", "objetivo",
                   "objetivo profesional", "extracto", "perfil personal"]),
            (.fr, ["profil", "profil professionnel", "résumé", "à propos", "à propos de moi", "objectif", "objectif professionnel",
                   "présentation", "synthèse", "profil personnel"]),
            (.pt, ["perfil", "perfil profissional", "resumo", "resumo profissional", "sobre mim", "objetivo", "objetivo profissional",
                   "apresentação", "sumário", "perfil pessoal"]),
        ]),
        (.experience, [
            (.en, ["experience", "work experience", "professional experience", "employment", "employment history", "work history",
                   "career history", "career", "relevant experience", "experiences", "professional background", "work"]),
            (.it, ["esperienza", "esperienze", "esperienza lavorativa", "esperienze lavorative", "esperienza professionale",
                   "esperienze professionali", "percorso professionale", "carriera", "attività lavorativa", "esperienze di lavoro"]),
            (.de, ["berufserfahrung", "beruflicher werdegang", "berufspraxis", "berufliche erfahrung", "berufliche stationen",
                   "praxiserfahrung", "erfahrung", "werdegang", "beruflicher hintergrund", "arbeitserfahrung", "berufstätigkeit",
                   "berufliche laufbahn", "berufliche tätigkeiten"]),
            (.es, ["experiencia", "experiencia laboral", "experiencia profesional", "trayectoria profesional", "historial laboral",
                   "experiencias"]),
            (.fr, ["expérience", "expériences", "expérience professionnelle", "expériences professionnelles", "parcours professionnel",
                   "emplois"]),
            (.pt, ["experiência", "experiência profissional", "experiências profissionais", "experiência laboral",
                   "percurso profissional", "histórico profissional", "experiências"]),
        ]),
        (.education, [
            (.en, ["education", "education and training", "academic background", "qualifications", "training", "academic qualifications",
                   "studies", "education training", "academic education"]),
            (.it, ["istruzione", "istruzione e formazione", "formazione", "studi", "percorso di studi", "titoli di studio",
                   "formazione accademica", "percorso formativo", "titolo di studio", "istruzione formazione"]),
            (.de, ["ausbildung", "bildung", "bildungsweg", "schulbildung", "studium", "schul- und berufsausbildung", "akademischer werdegang",
                   "ausbildung und studium", "schule und studium", "schulische ausbildung", "hochschulbildung", "schulischer werdegang",
                   "berufsausbildung", "schul und berufsausbildung", "akademische ausbildung", "studium und ausbildung",
                   "ausbildung und weiterbildung"]),
            (.es, ["formación", "educación", "formación académica", "estudios", "educación y formación", "formación reglada"]),
            (.fr, ["formation", "formations", "éducation", "études", "parcours académique", "diplômes", "éducation et formation",
                   "parcours scolaire"]),
            (.pt, ["formação", "formação académica", "formação acadêmica", "educação", "educação e formação", "habilitações",
                   "habilitações literárias", "estudos", "habilitações académicas"]),
        ]),
        (.skills, [
            (.en, ["skills", "key skills", "core skills", "technical skills", "competencies", "core competencies", "abilities", "expertise",
                   "top skills", "hard skills", "soft skills", "it skills", "digital skills", "tools", "technologies", "skills and competences",
                   "personal skills", "other skills", "skills competences", "technical skills and competences", "computer skills",
                   "job-related skills", "organisational skills", "communication skills",
                   // The stack, the tools and the technologies a CV lists besides its skills
                   "tech stack", "technology stack", "technical stack", "tools and technologies", "technologies and tools",
                   "technical expertise", "technical competencies", "technical proficiencies", "tech skills", "skills and tools",
                   "skills and technologies", "core technologies", "key technologies", "main technologies"]),
            (.it, ["competenze", "competenze tecniche", "abilità", "capacità", "capacità e competenze", "capacità e competenze personali",
                   "capacità e competenze tecniche", "competenze digitali", "competenze informatiche", "conoscenze informatiche",
                   "competenze trasversali", "competenze professionali", "altre competenze", "capacità e competenze organizzative",
                   "capacità e competenze relazionali", "capacità e competenze artistiche", "altre capacità e competenze",
                   "competenze personali", "competenze organizzative", "competenze comunicative", "competenze principali",
                   "tecnologie", "strumenti", "tecnologie utilizzate", "strumenti e tecnologie", "tecnologie e strumenti",
                   "stack tecnologico", "stack tecnico", "tech stack", "conoscenze tecniche", "competenze chiave", "tecnologie principali",
                   "tecnologie chiave"]),
            (.de, ["kenntnisse", "fähigkeiten", "kompetenzen", "fachkenntnisse", "edv-kenntnisse", "it-kenntnisse", "besondere kenntnisse",
                   "fähigkeiten und kenntnisse", "kenntnisse und fähigkeiten", "digitale kompetenzen", "soft skills", "fachliche kompetenzen",
                   "sonstige kenntnisse", "qualifikationen", "fachkompetenzen", "persönliche kompetenzen", "skills", "top-kenntnisse",
                   "top kenntnisse", "technische kenntnisse", "technische fähigkeiten", "technische kompetenzen", "technische skills",
                   "fachliche kenntnisse", "it-kompetenzen", "technologien", "tools", "werkzeuge", "tech-stack", "technologie-stack",
                   "tools und technologien", "technologien und tools", "kernkompetenzen", "schlüsselkompetenzen", "kerntechnologien",
                   "haupttechnologien"]),
            (.es, ["habilidades", "competencias", "aptitudes", "conocimientos", "conocimientos informáticos", "competencias digitales",
                   "habilidades técnicas", "competencias técnicas", "otras habilidades", "aptitudes principales",
                   "conocimientos técnicos", "herramientas", "tecnologías", "tecnologías utilizadas", "herramientas y tecnologías",
                   "tecnologías y herramientas", "stack tecnológico", "stack técnico", "tech stack", "competencias clave",
                   "competencias principales", "habilidades clave", "tecnologías principales", "tecnologías clave"]),
            (.fr, ["compétences", "compétences techniques", "savoir-faire", "aptitudes", "connaissances", "compétences informatiques",
                   "compétences numériques", "outils", "compétences clés", "savoir être", "principales compétences",
                   "technologies", "outils et technologies", "technologies et outils", "stack technique", "stack technologique",
                   "connaissances techniques", "technologies principales", "technologies clés"]),
            (.pt, ["competências", "competências técnicas", "habilidades", "aptidões", "conhecimentos", "conhecimentos informáticos",
                   "competências digitais", "outras competências", "competências pessoais", "principais competências",
                   "ferramentas", "tecnologias", "tecnologias utilizadas", "ferramentas e tecnologias", "tecnologias e ferramentas",
                   "stack tecnológico", "stack técnico", "tech stack", "conhecimentos técnicos", "habilidades técnicas",
                   "competências chave", "tecnologias principais", "tecnologias chave"]),
        ]),
        (.languages, [
            (.en, ["languages", "language skills", "language", "languages spoken", "foreign languages", "language competences"]),
            (.it, ["lingue", "lingue straniere", "conoscenze linguistiche", "competenze linguistiche", "lingua", "lingue conosciute"]),
            (.de, ["sprachen", "sprachkenntnisse", "fremdsprachen", "sprachkompetenzen", "fremdsprachenkenntnisse"]),
            (.es, ["idiomas", "lenguas", "conocimientos de idiomas", "competencias lingüísticas", "idiomas extranjeros"]),
            (.fr, ["langues", "compétences linguistiques", "langues étrangères", "langues parlées"]),
            (.pt, ["línguas", "idiomas", "competências linguísticas", "conhecimentos linguísticos", "línguas estrangeiras"]),
        ]),
        (.certifications, [
            (.en, ["certifications", "certificates", "licenses", "licences", "licenses certifications", "licences certifications",
                   "certifications and licenses", "certifications and licences",
                   "courses", "training courses", "accreditations", "certifications courses", "further training"]),
            (.it, ["certificazioni", "certificati", "attestati", "corsi", "corsi di formazione", "abilitazioni", "corsi e certificazioni",
                   "certificazioni e corsi", "formazione continua"]),
            (.de, ["zertifikate", "zertifizierungen", "weiterbildung", "weiterbildungen", "fortbildungen", "fortbildung", "lehrgänge",
                   "kurse", "nachweise", "zusatzqualifikationen", "zertifikate und weiterbildungen"]),
            (.es, ["certificaciones", "certificados", "cursos", "formación complementaria", "licencias", "cursos y certificaciones"]),
            (.fr, ["certifications", "certificats", "formations complémentaires", "attestations", "habilitations", "certifications et formations"]),
            (.pt, ["certificações", "certificados", "cursos", "formação complementar", "licenças", "cursos e certificações"]),
        ]),
        (.interests, [
            (.en, ["interests", "hobbies", "hobbies and interests", "interests hobbies", "leisure", "personal interests", "activities", "hobbies interests"]),
            (.it, ["interessi", "hobby", "hobby e interessi", "passioni", "tempo libero", "interessi personali"]),
            (.de, ["hobbys", "hobbies", "interessen", "freizeit", "freizeitaktivitäten", "persönliche interessen", "hobbys und interessen"]),
            (.es, ["intereses", "aficiones", "hobbies", "pasatiempos", "intereses personales"]),
            (.fr, ["centres d'intérêt", "centres d'intérêts", "loisirs", "intérêts", "passions", "hobbies", "centre d'intérêt"]),
            (.pt, ["interesses", "hobbies", "passatempos", "lazer", "interesses pessoais"]),
        ]),
        (.projects, [
            (.en, ["projects", "personal projects", "selected projects", "key projects"]),
            (.it, ["progetti", "progetti personali"]),
            (.de, ["projekte", "projekterfahrung", "ausgewählte projekte"]),
            (.es, ["proyectos", "proyectos personales"]),
            (.fr, ["projets", "projets personnels"]),
            (.pt, ["projetos", "projectos", "projetos pessoais"]),
        ]),
        (.volunteering, [
            (.en, ["volunteering", "volunteer experience", "volunteer work", "voluntary work"]),
            (.it, ["volontariato", "attività di volontariato"]),
            (.de, ["ehrenamt", "ehrenamtliches engagement", "ehrenamtliche tätigkeiten", "soziales engagement", "engagement"]),
            (.es, ["voluntariado", "experiencia de voluntariado"]),
            (.fr, ["bénévolat", "engagements", "engagement associatif", "vie associative"]),
            (.pt, ["voluntariado", "trabalho voluntário"]),
        ]),
        (.references, [
            (.en, ["references", "referees", "references available upon request"]),
            (.it, ["referenze", "referenti"]),
            (.de, ["referenzen", "referenzpersonen"]),
            (.es, ["referencias"]),
            (.fr, ["références"]),
            (.pt, ["referências"]),
        ]),
        (.drivingLicence, [
            (.en, ["driving licence", "driving license", "driver's license", "driving licences"]),
            (.it, ["patente", "patente di guida", "patente o patenti", "patenti"]),
            (.de, ["führerschein", "führerscheine", "führerscheinklasse"]),
            (.es, ["permiso de conducir", "carnet de conducir", "carné de conducir", "licencia de conducir"]),
            (.fr, ["permis de conduire", "permis"]),
            (.pt, ["carta de condução", "carteira de motorista", "carta de conducao", "habilitação"]),
        ]),
        (.additional, [
            (.en, ["additional information", "other information", "awards", "honors", "honours", "honors-awards", "publications",
                   "achievements", "memberships", "annexes", "miscellaneous", "awards and honors"]),
            (.it, ["ulteriori informazioni", "altre informazioni", "allegati", "premi", "pubblicazioni", "riconoscimenti", "varie"]),
            (.de, ["sonstiges", "weitere angaben", "zusätzliche informationen", "auszeichnungen", "publikationen", "veröffentlichungen",
                   "mitgliedschaften", "anlagen"]),
            (.es, ["información adicional", "otros datos", "premios", "publicaciones", "logros", "anexos", "otros"]),
            (.fr, ["informations complémentaires", "informations supplémentaires", "prix", "publications", "distinctions", "divers", "annexes"]),
            (.pt, ["informações adicionais", "outras informações", "prémios", "prêmios", "publicações", "anexos", "outros"]),
        ]),
    ]

    /// Common words of each language, to tell the language when the headings do not.
    static let commonWords: [CVLanguage: Set<String>] = [
        .en: ["the", "and", "of", "with", "for", "in", "to", "at", "my", "team"],
        .it: ["di", "il", "la", "per", "con", "nel", "della", "dei", "delle", "presso", "gli"],
        .de: ["und", "der", "die", "das", "mit", "für", "bei", "von", "im", "zur", "zum", "des"].reduce(into: Set<String>()) { $0.insert($1.folded) },
        .es: ["de", "y", "el", "la", "en", "con", "para", "los", "las", "del"],
        .fr: ["de", "et", "le", "la", "les", "des", "en", "pour", "avec", "du", "au"],
        .pt: ["de", "e", "o", "a", "em", "com", "para", "do", "da", "dos", "das", "na", "no"],
    ]
}
