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

    // MARK: What follows a bullet's year

    /// How sure a bullet that opens with a year is of heading an entry.
    enum HeadEvidence {
        /// A count, a quantity, or a sentence: a detail.
        case none
        /// A capitalised word and nothing else says it is a head ("• 2021 Acme"): an entry only in a section of bullets.
        case weak
        /// The year stands alone, a date separator comes before a head, or a word of a school, a qualification, a job or
        /// an organisation follows it ("• 2021 Leeds College").
        case strong
    }

    /// What the text after a bullet's year says, with or without a date separator: a head (a title, a school, an
    /// employer, a degree) makes an entry, a count ("2000 – hours of placement", "1200 Stunden Praktikum") or a
    /// sentence ("2019 led the move", "2019 I led the move") a detail. When the evidence is unclear it is a detail.
    static func headEvidence(after text: String) -> HeadEvidence {
        var rest = Substring(text)
        var separated = false
        while let first = rest.first, first == " " || "|·•—–-,:/".contains(first) {
            if first != " " { separated = true }
            rest = rest.dropFirst()
        }
        guard let opening = rest.first else { return .strong }
        // A symbol after the year ("%", "€", a bracket) is no head
        guard opening.isLetter || opening.isNumber, let lead = rest.words.first else { return .none }
        let words = rest.words.map { $0.folded }
        let folded = words[0]
        let namesAHead = isRole(String(rest)) || isSchool(String(rest)) || isDegree(String(rest)) || isOrganisation(String(rest))
        if countUnits.contains(folded) || sentenceOpeners.contains(folded) || folded.hasPrefix("j'") { return .none }
        if countedNouns.contains(folded) {
            // "2019 – Projects Manager": a job named after what it counts
            return words.count == 2 && isRole(String(words[1])) ? .strong : .none
        }
        if opening.isNumber { return namesAHead ? .strong : .none }
        // A word that names a role, a school or an employer counts only where a head puts it: in a part of its own between the
        // separators, among words that are names or modifiers, never inside prose. Punctuation alone is no evidence.
        let structured = hasHeadStructure(rest)
        if !(lead.first?.isUppercase ?? false) {
            // A lower-case word opens a head only when it is one ("diploma in nursing", not "led the move") or a name
            // particle before an employer or a school ("von Linden GmbH", "di Rossi S.r.l.")
            let opensAHead = isRole(String(lead)) || isSchool(String(lead)) || isDegree(String(lead)) || isOrganisation(String(lead))
                || nameParticles.contains(folded)
            return structured && opensAHead ? .strong : .none
        }
        if structured { return .strong }
        // Prose around a head word ("Auszeichnung für Elektriker", "Von Muster GmbH ausgezeichnet") never heads an entry
        if namesAHead { return .weak }
        // A single word, or words that are all capitalised ("Corso Croce Rossa"), after a separator is a head; a capitalised
        // noun followed by lower-case words ("Prüfungen durchgeführt") is a count with its verb
        return separated && hasHeadShape(rest) ? .strong : .weak
    }

    /// Whether a text is one word or words that are all capitalised.
    private static func hasHeadShape(_ text: Substring) -> Bool {
        let words = text.words
        return words.count == 1 || words.allSatisfy { $0.first?.isUppercase ?? false }
    }

    /// Whether a text is a head by its structure: parts between its separators, each a place, a part that names a role, a
    /// degree, a school or an employer (see `namesAHeadWord`), a capitalised title or name that
    /// no word names (the first part, or the part straight after a role: "Elektriker – Siemens"), or a last city after an
    /// employer that a role opened; at least one part names a head. A comma joins only a city and its region ("Boston, MA"),
    /// never the parts of a head.
    private static func hasHeadStructure(_ text: Substring) -> Bool {
        // Each part with whether a comma (not a dash or a bar) stands before it
        var parts: [String] = []
        var afterComma: [Bool] = []
        var current = ""
        var comma = false
        for character in text.replacingOccurrences(of: " - ", with: " – ") {
            if ",|·•—–/".contains(character) {
                parts.append(current.trimmingCharacters(in: .whitespaces))
                afterComma.append(comma)
                current = ""
                comma = character == ","
            } else {
                current.append(character)
            }
        }
        parts.append(current.trimmingCharacters(in: .whitespaces))
        afterComma.append(comma)
        guard parts.allSatisfy({ !$0.words.isEmpty }) else { return false }
        var index = 0
        var named = false
        var opened = false
        var closed = false
        var nameMayFollow = false
        while index < parts.count {
            // The longest run of parts from here, joined by commas only, that reads as one place
            var reach = index
            while reach + 1 < parts.count, afterComma[reach + 1] { reach += 1 }
            if let last = (index...reach).reversed().first(where: { isOnePlace(parts[index...$0]) }) {
                index = last + 1
                nameMayFollow = false
            } else if let kind = namesAHeadWord(parts[index]) {
                named = true
                if kind == .opening { opened = true } else { closed = true }
                nameMayFollow = kind == .opening && !closed
                index += 1
            } else if parts[index].split(separator: " ").allSatisfy({ isModifier($0) }),
                      nameMayFollow || index == 0 || (closed && opened && index == parts.count - 1) {
                // A title that no word names ("Operatrice – Clinica Esempio"), the name of the employer or school after a role,
                // or the city after a school or an employer that a role opened
                if index == 0 { opened = true }
                nameMayFollow = index == 0
                index += 1
            } else {
                return false
            }
        }
        return named
    }

    private enum HeadPart {
        /// A role or a degree: the school or the employer follows
        case opening
        /// A school or an employer
        case closing
    }

    /// The words that join a head word to what qualifies it ("Diploma in nursing", "Elektriker für Hochspannung").
    private static let connectors: Set<String> = Set([
        // English
        "of", "in", "at", "for", "on", "with", "and",
        // Italian
        "di", "del", "della", "dello", "dei", "degli", "delle", "per", "presso", "con", "a", "nel", "nella", "nei", "nelle", "e",
        // Spanish
        "de", "en", "para", "por", "con", "y",
        // French
        "du", "des", "pour", "chez", "avec", "à", "au", "aux", "et",
        // German
        "für", "im", "am", "bei", "und", "mit", "von", "zum", "zur",
        // Portuguese
        "do", "da", "dos", "das", "em", "no", "na", "nos", "nas", "para", "por", "com", "e",
    ].map(\.folded))

    /// Whether a part names a role, a degree, a school or an employer where a head puts it: before the word of the head only
    /// names and modifiers ("Senior Elektriker", "Leeds College"), after it nothing, names and modifiers, or a connector
    /// that leads to its qualifier ("Corso di infermieristica", "Leeds College of Nursing"). A word of a head inside prose
    /// ("Auszeichnung für Elektriker", "Muster Ltd named supplier") is not one.
    private static func namesAHeadWord(_ part: String) -> HeadPart? {
        var text = part
        while let open = text.firstIndex(of: "("), let close = text[open...].firstIndex(of: ")") {
            text.removeSubrange(open...close)
        }
        let words = text.split(separator: " ")
        for (index, word) in words.enumerated() {
            let word = String(word)
            let closing = isOrganisation(word) || isSchool(word)
            guard closing || isRole(word) || isDegree(word) else { continue }
            guard words[..<index].allSatisfy({ isModifier($0) }) else { continue }
            let after = words[(index + 1)...]
            if let next = after.first, !isModifier(next), !connectors.contains(next.folded), !next.folded.hasPrefix("d'") { continue }
            if let next = after.first, isModifier(next), !after.allSatisfy({ isModifier($0) }) { continue }
            if let next = after.first, !isModifier(next) {
                let qualifier = connectors.contains(next.folded) ? Array(after.dropFirst()) : [Substring(next.dropFirst(2))] + after.dropFirst()
                guard isReadableQualifier(qualifier) else { continue }
            }
            return closing ? .closing : .opening
        }
        return nil
    }

    /// Whether what follows a joining word is read as a qualifier and not as prose: a name (capitalised words and name
    /// particles, joining words only between capitalised words) or a short subject of at most two lower-case words, none an
    /// article, a determiner or a joining word. The qualifier is read, never trusted: a doubtful one is prose.
    private static func isReadableQualifier(_ words: [Substring]) -> Bool {
        guard let first = words.first, let last = words.last else { return false }
        func capitalised(_ word: Substring) -> Bool { word.first.map { $0.isUppercase || !$0.isLetter } ?? false }
        if capitalised(first), capitalised(last),
           words.allSatisfy({ capitalised($0) || nameParticles.contains($0.folded) || connectors.contains($0.folded) }) {
            return true
        }
        return words.count <= 2 && words.allSatisfy { word in
            let folded = word.folded
            return word.first?.isLowercase == true && !determiners.contains(folded) && !connectors.contains(folded)
                && !elidedArticles.contains(where: folded.hasPrefix)
        }
    }

    /// The articles and determiners of the six languages: a short subject that holds one is prose.
    private static let determiners: Set<String> = Set([
        // English
        "a", "an", "the", "all", "any", "each", "every", "some", "this", "that", "these", "those", "my", "our", "your", "his", "her", "its", "their",
        // Spanish
        "el", "la", "los", "las", "un", "una", "unos", "unas", "lo", "al", "del", "este", "esta", "estos", "estas", "mi", "mis", "su", "sus",
        "nuestro", "nuestra", "todo", "toda", "todos", "todas",
        // French
        "le", "les", "une", "ce", "cet", "cette", "ces", "mon", "ma", "mes", "son", "sa", "ses", "notre", "nos", "leur", "leurs", "tout",
        "tous", "toute", "toutes", "du", "des", "au", "aux",
        // German
        "der", "die", "das", "den", "dem", "ein", "eine", "einen", "einem", "einer", "eines", "aller", "alle", "allen", "alles",
        "diese", "dieser", "dieses", "diesen", "mein", "meine", "unser", "unsere", "jede", "jeder", "jedes",
        // Italian
        "il", "gli", "i", "uno", "questo", "questa", "questi", "queste", "mio", "mia", "miei", "mie", "tutti", "tutte", "tutto",
        "ogni", "dei", "degli", "delle", "dello", "della", "nel", "nella", "nei", "nelle", "alla", "alle", "allo",
        // Portuguese
        "o", "os", "as", "um", "uma", "uns", "umas", "estes", "estas", "meu", "minha", "meus", "minhas", "pelo", "pela", "pelos", "pelas",
        "ao", "aos", "do", "da", "dos", "das", "no", "na", "nos", "nas",
    ].map(\.folded))

    /// The articles that lose their vowel before a vowel ("l'", "all'", "un'"): a lower-case word that starts so is prose.
    private static let elidedArticles = ["l'", "all'", "dell'", "nell'", "sull'", "dall'", "un'", "quest'", "d'", "qu'", "l\u{2019}", "d\u{2019}"]

    /// Whether a word is part of a name: capitalised, a particle ("von", "di"), or not a letter ("&", "(").
    private static func isModifier(_ word: Substring) -> Bool {
        guard let first = word.first else { return true }
        return first.isUppercase || !first.isLetter || nameParticles.contains(word.folded)
    }

    /// Whether comma-joined parts make one place: a single part that is a place, or several where each part but the last is a
    /// place on its own and the last is a country or region. Each part is checked alone, so a capitalised word is never a city
    /// because a region follows it: "Auszeichnung, Deutschland" and "Auszeichnung, Bayern, Deutschland" are no place.
    private static func isOnePlace(_ parts: ArraySlice<String>) -> Bool {
        guard parts.count > 1, let region = parts.last else { return Places.isPlaceOnly(parts.joined(separator: ", ")) }
        return Places.isCountryOrRegion(region) && parts.dropLast().allSatisfy { Places.isPlaceOnly($0) }
    }

    /// The lower-case particles of a surname or a firm's name ("von Linden GmbH", "di Rossi S.r.l.", "de la Torre S.L.").
    private static let nameParticles: Set<String> = Set([
        "von", "van", "de", "di", "da", "del", "della", "dei", "degli", "du", "des", "la", "le", "el", "zu", "zur", "der", "den", "dos", "das", "do",
    ].map(\.folded))

    /// The units a number counts, in the six languages: after a year they make a count, never a head.
    private static let countUnits: Set<String> = Set([
        "hour", "hours", "hr", "hrs", "h", "stunde", "stunden", "std", "ora", "ore", "hora", "horas", "heure", "heures",
        "minute", "minutes", "minuten", "minuti", "minutos", "day", "days", "tag", "tage", "tagen", "giorno", "giorni", "día", "días",
        "jour", "jours", "dia", "dias", "week", "weeks", "woche", "wochen", "settimana", "settimane", "semana", "semanas", "semaine",
        "semaines", "km", "kg", "m", "euro", "euros", "eur", "usd", "dollars", "dollar", "percent", "prozent", "percento",
        "porcento", "pourcent", "pieces", "piece", "stück", "stk", "pezzi", "piezas", "pièces", "units", "unit", "unità", "unidades",
        "unités", "einheiten", "lines", "zeilen", "righe", "líneas", "lignes", "words", "wörter", "parole", "palabras", "mots",
    ].map(\.folded))

    /// The nouns a number counts: after a year they make a count unless they name a job ("Projects Manager").
    private static let countedNouns: Set<String> = Set([
        "people", "persons", "persone", "personen", "personas", "personnes", "projects", "projekte", "progetti", "proyectos", "projets",
        "clients", "client", "clienti", "clientes", "kunden", "customers", "kundinnen", "users", "nutzer", "benutzer", "utenti",
        "usuarios", "utilisateurs", "employees", "mitarbeiter", "mitarbeitende", "dipendenti", "empleados", "employés", "patients",
        "patienten", "pazienti", "pacientes", "cases", "fälle", "casi", "casos", "cas", "students", "schüler", "studenti",
        "estudiantes", "étudiants", "members", "mitglieder", "membri", "miembros", "membres", "teams", "orders", "bestellungen",
        "ordini", "pedidos", "commandes", "calls", "anrufe", "chiamate", "llamadas", "appels", "visits", "besuche", "visite", "visitas",
        "visites", "tickets", "stores", "filialen", "negozi", "tiendas", "magasins", "sites", "events", "veranstaltungen", "eventi",
        "eventos", "événements", "years", "jahre", "anni", "años", "ans",
    ].map(\.folded))

    /// The words that open a sentence about the person ("I led", "Ich habe", "Ho completato"): no head.
    private static let sentenceOpeners: Set<String> = Set([
        "i", "we", "my", "our", "ich", "wir", "mein", "meine", "unser", "unsere", "io", "noi", "ho", "abbiamo", "yo", "nosotros",
        "hemos", "je", "nous", "mon",
    ].map(\.folded))

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
