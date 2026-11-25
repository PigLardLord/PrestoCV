/// The closed word lists that tell the parts of an entry apart, in the six languages: roles, organisations, schools,
/// degrees, and the labels of the Europass and the formato europeo.
enum EntryVocabulary {

    // MARK: Roles

    /// Whether a piece reads as a role: it holds a word of a job, such as "Developer", "Infermiera", "Elektrikerin".
    static func isRole(_ text: String) -> Bool {
        let words = text.words.map { $0.folded }
        return words.contains { word in
            roleWords.contains(word) || roleStems.contains { word.hasPrefix($0) } || roleSuffixes.contains { word.hasSuffix($0) && word.count > $0.count + 2 }
        }
    }

    private static let roleWords: Set<String> = Set([
        "developer", "engineer", "manager", "nurse", "consultant", "assistant", "designer", "analyst", "intern", "trainee", "teacher",
        "lead", "head", "director", "coordinator", "specialist", "technician", "electrician", "accountant", "architect", "officer",
        "administrator", "executive", "owner", "founder", "cofounder", "co-founder", "chef", "cook", "waiter", "waitress", "barista", "cashier",
        "clerk", "secretary", "receptionist", "driver", "mechanic", "operator", "supervisor", "advisor", "adviser", "scientist",
        "researcher", "professor", "lecturer", "tutor", "programmer", "tester", "editor", "writer", "translator", "interpreter",
        "pharmacist", "physician", "doctor", "therapist", "caregiver", "carer", "midwife", "paramedic", "salesperson", "agent",
        "representative", "president", "partner", "associate", "student", "apprentice", "volunteer", "freelancer", "freelance", "ceo",
        "cto", "cfo", "coo", "vp", "senior", "junior", "staff", "principal", "worker", "electrician", "plumber", "carpenter",
        "sviluppatore", "sviluppatrice", "ingegnere", "infermiere", "infermiera", "consulente", "assistente", "progettista",
        "analista", "stagista", "tirocinante", "insegnante", "docente", "responsabile", "direttore", "direttrice", "coordinatore",
        "coordinatrice", "specialista", "tecnico", "tecnica", "elettricista", "contabile", "impiegato", "impiegata", "operaio",
        "operaia", "cuoco", "cuoca", "cameriere", "cameriera", "commesso", "commessa", "segretario", "segretaria", "autista",
        "meccanico", "addetto", "addetta", "educatore", "educatrice", "farmacista", "medico", "fisioterapista", "ostetrica",
        "oss", "badante", "geometra", "avvocato", "avvocata", "praticante", "ricercatore", "ricercatrice", "titolare", "socio",
        "amministratore", "amministratrice", "capo", "programmatore", "programmatrice", "barista", "cassiere", "cassiera",
        "receptionist", "magazziniere", "magazziniera", "idraulico", "falegname", "muratore", "venditore", "venditrice",
        "entwickler", "entwicklerin", "ingenieur", "ingenieurin", "berater", "beraterin", "leiter", "leiterin", "projektleiter",
        "projektleiterin", "teamleiter", "teamleiterin", "abteilungsleiter", "abteilungsleiterin", "geschäftsführer",
        "geschäftsführerin", "mitarbeiter", "mitarbeiterin", "sachbearbeiter", "sachbearbeiterin", "praktikant", "praktikantin",
        "werkstudent", "werkstudentin", "auszubildender", "auszubildende", "azubi", "elektriker", "elektrikerin", "elektroniker",
        "elektronikerin", "techniker", "technikerin", "kauffrau", "kaufmann", "lehrer", "lehrerin", "pfleger", "pflegerin",
        "krankenpfleger", "krankenpflegerin", "pflegefachkraft", "pflegefachfrau", "pflegefachmann", "fachkraft", "meister",
        "meisterin", "geselle", "gesellin", "monteur", "monteurin", "koch", "köchin", "kellner", "kellnerin", "verkäufer",
        "verkäuferin", "buchhalter", "buchhalterin", "assistent", "assistentin", "referent", "referentin", "spezialist",
        "spezialistin", "analyst", "analystin", "architekt", "architektin", "designerin", "inhaber", "inhaberin", "gründer",
        "gründerin", "berufskraftfahrer", "fahrer", "fahrerin", "erzieher", "erzieherin", "arzt", "ärztin", "anwalt", "anwältin",
        "desarrollador", "desarrolladora", "ingeniero", "ingeniera", "enfermero", "enfermera", "consultor", "consultora",
        "asistente", "diseñador", "diseñadora", "analista", "becario", "becaria", "profesor", "profesora", "maestro", "maestra",
        "jefe", "jefa", "director", "directora", "coordinador", "coordinadora", "especialista", "técnico", "técnica", "electricista",
        "contable", "contador", "contadora", "administrativo", "administrativa", "cocinero", "cocinera", "camarero", "camarera",
        "dependiente", "dependienta", "secretario", "secretaria", "conductor", "conductora", "mecánico", "responsable", "gerente",
        "programador", "programadora", "vendedor", "vendedora", "auxiliar", "fontanero", "carpintero", "abogado", "abogada",
        "développeur", "développeuse", "ingénieur", "ingénieure", "infirmier", "infirmière", "consultant", "consultante",
        "assistant", "assistante", "concepteur", "conceptrice", "analyste", "stagiaire", "enseignant", "enseignante", "professeur",
        "professeure", "chef", "directeur", "directrice", "coordinateur", "coordinatrice", "spécialiste", "technicien",
        "technicienne", "électricien", "électricienne", "comptable", "employé", "employée", "cuisinier", "cuisinière", "serveur",
        "serveuse", "vendeur", "vendeuse", "secrétaire", "chauffeur", "mécanicien", "mécanicienne", "gérant", "gérante",
        "responsable", "chargé", "chargée", "alternant", "alternante", "apprenti", "apprentie", "avocat", "avocate", "plombier",
        "desenvolvedor", "desenvolvedora", "programador", "programadora", "engenheiro", "engenheira", "enfermeiro", "enfermeira",
        "consultor", "consultora", "assistente", "designer", "analista", "estagiário", "estagiária", "professor", "professora",
        "chefe", "diretor", "diretora", "coordenador", "coordenadora", "especialista", "técnico", "técnica", "eletricista",
        "contabilista", "empregado", "empregada", "cozinheiro", "cozinheira", "empregado de mesa", "vendedor", "vendedora",
        "secretário", "secretária", "motorista", "mecânico", "gerente", "responsável", "rececionista", "recepcionista",
        "canalizador", "carpinteiro", "advogado", "advogada", "operador", "operadora",
    ].map(\.folded))

    private static let roleStems = ["projektleit", "softwareentwick", "pflegefach", "ingegner", "infermier", "sviluppat", "desarroll", "développ", "desenvolv"].map(\.folded)
    /// German compounds end with their role: "Altenpfleger", "Pflegehelferin", "Rettungssanitäter".
    private static let roleSuffixes = [
        "entwickler", "entwicklerin", "leiter", "leiterin", "berater", "beraterin", "techniker", "technikerin", "manager", "engineer",
        "developer", "elektriker", "elektrikerin", "kraft", "kauffrau", "kaufmann", "pfleger", "pflegerin", "helfer", "helferin",
        "sanitäter", "sanitäterin", "arbeiter", "arbeiterin", "fahrer", "fahrerin", "verkäufer", "verkäuferin", "erzieher",
        "erzieherin", "ingenieur", "ingenieurin", "meister", "meisterin", "referent", "referentin", "assistent", "assistentin",
    ].map(\.folded)

    // MARK: Organisations and schools

    /// Whether a piece reads as an organisation: a legal form, or a word of a hospital, a firm or an institution.
    static func isOrganisation(_ text: String) -> Bool {
        let words = text.words.map { $0.folded }
        let compact = text.folded.filter { $0.isLetter || $0 == "." || $0 == " " }
        if legalForms.contains(where: { form in words.contains(form) }) { return true }
        if dottedLegalForms.contains(where: { compact.contains($0) }) { return true }
        return words.contains { organisationWords.contains($0) || organisationStems.contains(where: $0.hasPrefix) }
    }

    /// Whether a piece reads as a school or a university.
    static func isSchool(_ text: String) -> Bool {
        let words = text.words.map { $0.folded }
        return words.contains { word in
            schoolWords.contains(word) || schoolStems.contains(where: word.hasPrefix) || (word.hasSuffix("schule") && word.count > 6)
        }
    }

    /// Whether a piece reads as a degree or a qualification.
    static func isDegree(_ text: String) -> Bool {
        let words = text.words.map { $0.folded }
        return words.contains { degreeWords.contains($0) || degreeStems.contains(where: $0.hasPrefix) }
    }

    /// Whether a piece names a certification by its word: "Certified Scrum Developer", "Certificazione ITIL Foundation",
    /// "Zertifizierung". The nouns of a document ("certificate", "certificato", "certificado", "certificat") are not among them: they name
    /// degrees too ("Graduate Certificate in Data Science").
    static func isCertification(_ text: String) -> Bool {
        text.words.contains { certificationWords.contains($0.folded) }
    }

    private static let certificationWords: Set<String> = Set([
        "certified", "certification", "certifications", "certificazione", "certificazioni", "zertifizierung",
        "zertifizierungen", "zertifiziert", "zertifizierte", "zertifizierter", "zertifikat", "zertifikate", "certificación",
        "certificaciones", "certifié", "certifiée", "certificação", "certificações",
    ].map(\.folded))

    /// Whether the text opens with the word of a degree: "Bachelor of Science in Nursing", "Diplom Elektrotechnik", "MSc Data
    /// Science". The codes of two letters ("BA", "MA", "MS") are not among the openers: they are also a state, or a name
    /// ("MS Office Specialist").
    static func startsWithDegree(_ text: String) -> Bool {
        guard let first = text.words.first?.folded else { return false }
        return degreeStems.contains(where: first.hasPrefix) || degreeOpeners.contains(first)
    }

    /// The codes and words that open a degree besides its stems. "LLM" is not among them: it is also the large language
    /// model a course is named after ("LLM Fine-Tuning"), so it is a degree only where `degreeWords` reads it.
    private static let degreeOpeners: Set<String> = [
        "phd", "ph.d", "mba", "bsc", "msc", "beng", "meng", "llb", "doctor", "doctorate", "doctorado", "doctorat", "doutorado",
        "mestrado", "grado", "licence",
    ]

    /// Whether a line of a section of studies opens with the word of a degree, as `startsWithDegree` reads it, with one
    /// difference: "Licence" opens a study only when a French word follows it ("Licence en Droit", "Licence professionnelle
    /// Logistique", "Licence d'Économie", "Licence ès Lettres"). In English it is a permission to work, a certification
    /// ("Licence to Practise — General Medical Council, 2015").
    static func opensAStudy(_ text: String) -> Bool {
        let words = text.words.map { $0.folded }
        guard let first = words.first else { return false }
        guard first == "licence" else { return startsWithDegree(text) }
        guard let next = words.dropFirst().first else { return false }
        return licenceContinuations.contains(next) || next.hasPrefix("d'")
    }

    /// The French words that follow "Licence" in the name of a degree.
    private static let licenceContinuations: Set<String> = ["en", "de", "du", "des", "es", "professionnelle", "pro"]

    /// Whether the name of a line names a degree by one of its words, wherever it stands ("Certified Nursing Assistant
    /// Diploma", "Certified Diploma in Nursing"), or by "Master" before "of" or "in" ("Master of Science"). Whole words
    /// only, unlike `isDegree`: "Scrum Master" and "LLM Applications" name no degree. "Degree" after a number or an
    /// ordinal is a grade or an angle ("2nd Degree Black Belt", "360 Degree Feedback"), unless "of" or "in" follows it
    /// ("Second Degree in Nursing").
    static func namesADegree(_ text: String) -> Bool {
        let words = text.words.map { $0.folded }
        if words.contains(where: degreeNames.contains) { return true }
        return words.indices.contains { index in
            let next = index + 1 < words.count ? words[index + 1] : nil
            let namesTheSubject = next == "of" || next == "in"
            switch words[index] {
            case "master": return namesTheSubject
            case "degree": return namesTheSubject || index == 0 || !countsAGrade(words[index - 1])
            default: return false
            }
        }
    }

    /// A number or an ordinal, which makes the "Degree" after it a grade or an angle.
    private static func countsAGrade(_ word: String) -> Bool {
        word.first?.isNumber == true || ordinals.contains(word)
    }

    private static let ordinals: Set<String> = [
        "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
    ]

    /// The words that name a degree wherever they stand in a name.
    private static let degreeNames: Set<String> = Set([
        "diploma", "diplom", "diplôme", "diplomado", "diplomatura", "bachelor", "bachelor's", "master's", "laurea",
        "licenciatura", "doctorate", "doctorado", "doctorat", "dottorato", "doutorado", "mestrado", "maestría", "phd", "mba",
        "bsc", "msc", "beng", "meng", "llb", "abitur", "maturità", "baccalauréat", "bachillerato", "ausbildung", "studium",
    ].map(\.folded))

    private static let legalForms: Set<String> = [
        "gmbh", "ag", "kg", "ohg", "ug", "ev", "spa", "srl", "srls", "sas", "snc", "ltd", "limited", "inc", "llc", "llp", "plc", "corp",
        "sa", "sl", "slu", "sarl", "sasu", "lda", "ltda", "bv", "nv", "gbr", "kgaa", "co", "group", "gruppo", "gruppe", "grupo",
        "groupe", "holding", "company", "compagnie", "companhia", "compañía",
    ]

    private static let dottedLegalForms = ["s.p.a", "s.r.l", "s.a.s", "s.n.c", "e.v", "s.a.", "s.l.", "s.a.r.l", "lda.", "inc.", "ltd.", "co."]

    private static let organisationWords: Set<String> = Set([
        "hospital", "ospedale", "krankenhaus", "klinik", "klinikum", "clinica", "clínica", "clinique", "hôpital", "hospital",
        "bank", "banca", "banco", "banque", "studio", "agency", "agenzia", "agentur", "agencia", "agence", "agência",
        "hotel", "restaurant", "ristorante", "restaurante", "café", "cafe", "bar", "pizzeria", "bäckerei", "panificio",
        "cabinet", "kanzlei", "étude", "eletro", "elettro", "atelier", "werkstatt", "officina", "taller", "oficina",
        "labs", "solutions", "systems", "services", "consulting", "technologies", "partners",
        "stiftung", "fondazione", "fundación", "fondation", "fundação", "foundation", "verein", "associazione", "asociación",
        "association", "associação", "comune", "stadt", "ayuntamiento", "mairie", "câmara", "ministry", "ministero", "ministerium",
        "ministerio", "ministère", "ministério", "azienda", "unternehmen", "empresa", "entreprise", "società", "sociedad", "société",
        "sociedade", "cooperativa", "genossenschaft", "coopérative", "werke", "werk", "handwerk", "elektro", "bau", "logistik",
        "logistica", "logística", "logistique", "pflegedienst", "pflegeheim", "altenheim", "rsa", "casa di cura", "residencia",
        "lar", "ehpad", "apotheke", "farmacia", "pharmacie", "farmácia", "supermarkt", "supermercato", "supermercado",
        "supermarché", "negozio", "tienda", "magasin", "loja",
    ].map(\.folded))

    private static let organisationStems = ["elektrotechn", "krankenh", "ospedal"].map(\.folded)

    private static let schoolWords: Set<String> = Set([
        "university", "università", "universität", "universidad", "université", "universidade", "universita", "college", "school",
        "scuola", "schule", "escuela", "école", "escola", "politecnico", "polytechnic", "hochschule", "fachhochschule", "technische",
        "liceo", "istituto", "institute", "institut", "instituto", "gymnasium", "realschule", "gesamtschule", "berufsschule",
        "berufskolleg", "lycée", "colegio", "academy", "accademia", "akademie", "academia", "académie", "conservatorio",
        "conservatory", "iis", "itis", "ipsia", "ies", "iut", "insa", "faculdade", "facultad", "faculté", "facoltà",
        "fakultät", "campus", "uni", "tu", "hs", "eth", "epfl", "kollegschule", "volkshochschule",
    ].map(\.folded))

    private static let schoolStems = ["universit", "hochschul", "politecnic", "fachschul", "berufsschul", "gymnasi"].map(\.folded)

    private static let degreeWords: Set<String> = Set([
        "bachelor", "master", "laurea", "diploma", "dottorato", "phd", "ph.d", "doctorate", "doctorado", "doctorat", "doutoramento",
        "doutorado", "abitur", "ausbildung", "licenciatura", "grado", "máster", "licence", "mestrado", "bsc", "msc", "mba",
        "beng", "meng", "llb", "llm", "matura", "maturità", "maturita", "baccalauréat", "bac", "bachillerato", "fp", "cfgs", "cfgm",
        "bts", "dut", "bep", "staatsexamen", "magister", "promotion", "fachabitur", "mittlere", "reife", "realschulabschluss",
        "hauptschulabschluss", "gesellenbrief", "meisterbrief", "qualifica", "attestato", "certificate", "certificado", "certificat",
        "título", "titolo", "graduate", "degree", "specializzazione", "specialization", "postgraduate", "post-graduação", "pós-graduação",
        "posgrado", "técnico", "tecnico", "corso", "course", "curso", "cours", "lehrgang", "umschulung", "weiterbildung",
        "ingegneria", "informatica", "infermieristica", "economia", "giurisprudenza", "medicina", "engineering", "computer", "science",
        "informatik", "wirtschaftsinformatik", "pflege", "elektrotechnik", "betriebswirtschaft", "bwl", "ingeniería", "informática",
        "enfermería", "derecho", "ingénierie", "informatique", "soins", "infirmiers", "droit", "engenharia", "enfermagem", "direito",
        "gestão", "gestión", "gestion", "management", "studies", "studi", "studien", "estudios", "études", "estudos",
    ].map(\.folded))

    private static let degreeStems = ["laurea", "diplom", "bachelor", "master", "licenci", "ausbildung", "studium", "studiengang", "dottor", "doktor"].map(\.folded)

    // MARK: Connectors between a role and its employer

    /// "Role at Employer" in the six languages: the role is before, the employer after.
    static let roleEmployerConnectors = [" at ", " @ ", " presso ", " bei ", " en ", " chez ", " na ", " no ", " em ", " para ", " für ", " for ", " per "]

    // MARK: The labels of the formato europeo and the Europass

    enum EntryLabel: Equatable {
        case period, employer, sector, role, duties, school, subjects, qualification, level, location
    }

    static func entryLabel(_ text: String) -> EntryLabel? {
        entryLabels[SectionVocabulary.key(text)]
    }

    private static let entryLabels: [String: EntryLabel] = {
        let groups: [(EntryLabel, [String])] = [
            (.period, ["date (da – a)", "date da a", "date", "dates (from – to)", "dates from to", "dates", "periodo", "zeitraum", "datum",
                       "fechas", "fechas de – a", "período", "dates (de – à)", "dates de a", "datas", "datas de a", "da a", "from to"]),
            (.employer, ["nome e indirizzo del datore di lavoro", "nome e indirizzo del datore", "name and address of employer", "datore di lavoro", "employer",
                         "arbeitgeber", "name und adresse des arbeitgebers", "nombre y dirección del empleador", "empleador",
                         "employeur", "nom et adresse de l'employeur", "nome e endereço do empregador", "empregador",
                         "azienda", "company", "unternehmen", "firma", "empresa", "entreprise", "organisation", "organization"]),
            (.sector, ["tipo di azienda o settore", "type of business or sector", "settore", "sector", "branche", "secteur",
                       "tipo de empresa o sector", "type ou secteur d'activité", "tipo de empresa ou setor", "setor"]),
            (.role, ["tipo di impiego", "occupation or position held", "posizione", "ruolo", "funzione", "mansione", "position",
                     "role", "job title", "beruf oder funktion", "funktion", "puesto", "cargo", "poste", "fonction", "função",
                     "cargo ocupado", "posizione ricoperta", "profilo ricoperto", "tätigkeit", "titolo della posizione"]),
            (.duties, ["principali mansioni e responsabilità", "principali mansioni", "main activities and responsibilities", "aufgaben", "tätigkeiten",
                       "principales actividades y responsabilidades", "activités et responsabilités principales",
                       "principais atividades e responsabilidades", "mansioni", "responsabilità", "responsibilities", "aufgabenbereich",
                       "attività", "activities"]),
            (.school, ["nome e tipo di istituto di istruzione o formazione", "nome e tipo di istituto", "name and type of organisation providing education and training",
                       "istituto", "scuola", "università", "institution", "school", "schule", "hochschule", "centro",
                       "établissement", "instituição", "bildungseinrichtung", "nombre y tipo del centro de estudios",
                       "nom et type de l'établissement d'enseignement", "nome e tipo da organização de ensino"]),
            (.subjects, ["principali materie / abilità professionali oggetto dello studio", "principal subjects/occupational skills covered",
                         "principali materie", "materie", "subjects", "fächer", "schwerpunkte", "asignaturas", "matières", "disciplinas"]),
            (.qualification, ["qualifica conseguita", "title of qualification awarded", "titolo", "titolo conseguito", "abschluss",
                              "titulación", "titulación obtenida", "diplôme", "diplôme obtenu", "qualificação", "qualificação atribuída",
                              "titolo di studio", "qualification", "degree", "grado", "grau"]),
            (.level, ["livello nella classificazione nazionale (se pertinente)", "level in national or international classification",
                      "livello nella classificazione nazionale", "livello", "level", "niveau", "nivel", "nível", "voto", "note", "nota",
                      "votazione", "grade"]),
            (.location, ["luogo", "sede", "ort", "location", "lugar", "lieu", "local", "città", "city"]),
        ]
        var table: [String: EntryLabel] = [:]
        for (label, texts) in groups {
            for text in texts { table[SectionVocabulary.key(text)] = label }
        }
        return table
    }()

    // MARK: Personal details

    enum PersonalLabel: Equatable {
        case name, firstName, lastName, address, phone, email, web, birth, nationality, maritalStatus, gender, fax, other
    }

    static func personalLabel(_ text: String) -> PersonalLabel? {
        personalLabels[SectionVocabulary.key(text)]
    }

    private static let personalLabels: [String: PersonalLabel] = {
        let groups: [(PersonalLabel, [String])] = [
            (.name, ["name", "nome", "nome e cognome", "cognome e nome", "nombre", "nombre y apellidos", "nom", "nom et prénom",
                     "nome completo", "full name", "vollständiger name", "nombre completo"]),
            (.firstName, ["vorname", "first name", "prénom", "nome proprio", "primeiro nome"]),
            (.lastName, ["nachname", "last name", "surname", "cognome", "apellidos", "apellido", "nom de famille", "apelido", "sobrenome"]),
            (.address, ["address", "indirizzo", "residenza", "domicilio", "adresse", "anschrift", "wohnort", "dirección", "morada",
                        "endereço", "location", "località", "ort", "ubicación", "localisation", "localização", "città", "city",
                        "stadt", "ciudad", "ville", "cidade", "residence", "wohnhaft", "residente", "home address", "indirizzo di residenza", "comune",
                        "comune di residenza"]),
            (.phone, ["tel", "telefon", "telefono", "telephone", "téléphone", "teléfono", "telefone", "phone", "mobile", "mobil", "handy",
                      "cell", "cellulare", "móvil", "portable", "telemóvel", "celular", "mobile phone", "telefono cellulare",
                      "phone number", "mobile number", "telephone number", "cell phone", "cellphone", "número de teléfono",
                      "teléfono móvil", "número de telefone", "número de telemóvel", "numero di telefono", "numéro de téléphone",
                      "téléphone mobile", "tél", "telefonnummer", "handynummer", "mobiltelefon", "tlf", "tlm", "mob", "fon"]),
            (.email, ["mail", "e-mail", "email", "posta elettronica", "correo", "correo electrónico", "courriel", "correio eletrónico",
                      "correio eletrônico", "adresse e-mail", "indirizzo email", "e-mail-adresse", "email address", "e-mail address",
                      "dirección de correo electrónico", "dirección de correo", "dirección de email", "endereço de correio electrónico",
                      "endereço de correio eletrónico", "endereço de correio eletrônico", "endereço de e-mail", "indirizzo e-mail",
                      "indirizzo di posta elettronica", "adresse électronique", "adresse email", "adresse courriel", "correio electrónico"]),
            (.web, ["website", "sito web", "sito", "webseite", "homepage", "sitio web", "site web", "site", "portfolio", "linkedin",
                    "github", "xing", "web"]),
            (.birth, ["date of birth", "data di nascita", "geburtsdatum", "fecha de nacimiento", "date de naissance",
                      "data de nascimento", "born", "geboren", "geburtsort", "place of birth", "luogo di nascita",
                      "luogo e data di nascita", "geburtsdatum und ort", "geburtsdatum ort", "lugar de nacimiento", "lieu de naissance",
                      "local de nascimento", "nato a", "nata a", "età", "age", "alter", "edad", "idade", "comune di nascita", "provincia di nascita",
                      "stato di nascita", "paese di nascita"]),
            (.nationality, ["nationality", "nazionalità", "staatsangehörigkeit", "nationalität", "nacionalidad", "nationalité",
                            "nacionalidade", "cittadinanza", "citizenship", "staatsbürgerschaft"]),
            (.maritalStatus, ["marital status", "stato civile", "familienstand", "estado civil", "situation familiale"]),
            (.gender, ["sex", "gender", "sesso", "geschlecht", "sexo", "sexe"]),
            (.fax, ["fax", "telefax"]),
        ]
        var table: [String: PersonalLabel] = [:]
        for (label, texts) in groups {
            for text in texts { table[SectionVocabulary.key(text)] = label }
        }
        return table
    }()

    // MARK: Document titles

    static func isDocumentTitle(_ text: String) -> Bool {
        documentTitles.contains(SectionVocabulary.key(text))
    }

    private static let documentTitles: Set<String> = Set([
        "curriculum vitae", "curriculum", "cv", "lebenslauf", "tabellarischer lebenslauf", "resume", "résumé", "europass",
        "formato europeo per il", "formato europeo",
        "curriculum vitae europass", "europass curriculum vitae", "formato europeo per il curriculum vitae", "currículum vitae",
        "currículum", "currículo", "curriculum vitae et studiorum", "cv europass", "mein lebenslauf", "my cv", "il mio cv",
        "il mio curriculum", "mi currículum", "mon cv", "o meu currículo", "meu currículo",
    ].map(SectionVocabulary.key))
}

// MARK: - Sentences

extension EntryVocabulary {

    /// Whether a text starts with a subject pronoun of the six languages ("I led", "Ich leitete", "Io gestivo"): the
    /// positive sign of a sentence, which no noun phrase of a skills list has. The pronoun must be written as one
    /// ("I", "Ich", never "EU", the Portuguese "eu" in capitals). A capitalised next word is a name ("I Corinthians
    /// study") only when `capitalisedNextIsAName` says the line is a list of three or more items; in a line of two
    /// clauses it is a brand used as a verb ("I Google suppliers, compare quotes"). Trade-off: a two-item list that
    /// starts with a numeral ("I Corinthians study, choir singing.") stays whole as text not imported.
    static func startsWithSubject(_ text: String, capitalisedNextIsAName: Bool) -> Bool {
        let words = text.words
        guard let first = words.first, subjectPronouns.contains(first.folded) || first.lowercased() == "n\u{f3}s"
        else { return false }
        let isWrittenAsAWord = first.count == 1 || first.dropFirst().allSatisfy { $0.isLowercase || $0 == "'" || $0 == "\u{2019}" }
        let nextStartsWithACapital = words.dropFirst().first?.first?.isUppercase ?? false
        return isWrittenAsAWord && !(nextStartsWithACapital && capitalisedNextIsAName)
    }

    /// The subjects of the six languages, with the contracted ones of English and French ("I've", "J'ai"); the
    /// Portuguese "n\u{f3}s" is matched with its accent in `startsWithSubject`, as its folded form is a preposition.
    private static let subjectPronouns: Set<String> = Set([
        "i", "we", "ich", "wir", "io", "noi", "yo", "nosotros", "nosotras", "je", "nous", "eu",
        "i've", "i'm", "i'd", "i'll", "we've", "we're", "we'd", "we'll",
        "j'ai", "j'avais", "j'\u{e9}tais",
    ].map(\.folded))
}
