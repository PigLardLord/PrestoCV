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

    /// The longest head, in characters and in words ("Bachelor of Science in Computer Engineering – University of Leeds, Leeds"
    /// has 76 and 12): what follows a bullet's year beyond it gives no evidence of a head.
    private static let maxHeadCharacters = 160
    private static let maxHeadWords = 24

    /// What the text after a bullet's year says, with or without a date separator: a head (a title, a school, an
    /// employer, a degree) makes an entry, a count ("2000 – hours of placement", "1200 Stunden Praktikum") or a
    /// sentence ("2019 led the move", "2019 I led the move") a detail. When the evidence is unclear it is a detail.
    static func headEvidence(after text: String) -> HeadEvidence {
        // A head is short: a longer text is prose or a list, never scanned, so the work per bullet is constant
        guard text.count <= maxHeadCharacters, text.words.count <= maxHeadWords else { return .none }
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
    private static let headConnectors: Set<String> = Set([
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

    /// Connectors that introduce an employer and nothing else. "en", "em", "na", "de", "di", "for", "per" and the like also
    /// introduce a field or a duty ("Técnico em Enfermagem"), so Spanish and Portuguese have none.
    private static let employerConnectors: Set<String> = Set(["at", "presso", "bei", "chez"].map(\.folded))

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
            // A sector or activity word ("Bau", "Studio") followed by a connector is no head word: it opens a duty
            if closing, !isRole(word), !isDegree(word), !legalForms.contains(word.folded), !namesInstitutionByItself(word.folded),
               let next = after.first, headConnectors.contains(next.folded) || next.folded.hasPrefix("d'") { continue }
            if let next = after.first, !isModifier(next), !headConnectors.contains(next.folded), !next.folded.hasPrefix("d'") { continue }
            if let next = after.first, isModifier(next), !after.allSatisfy({ isModifier($0) }) { continue }
            if let next = after.first, !isModifier(next) {
                let joined = headConnectors.contains(next.folded)
                let qualifier = joined ? Array(after.dropFirst()) : [Substring(next.dropFirst(2))] + after.dropFirst()
                let employer = joined && employerConnectors.contains(next.folded)
                guard isReadableQualifier(qualifier, afterRole: isRole(word), afterEmployerConnector: employer) else { continue }
            }
            return closing ? .closing : .opening
        }
        return nil
    }

    /// Whether what follows a joining word is read as a qualifier and not as prose: a name (capitalised words and name
    /// particles, joining words only between capitalised words) or a short subject of at most two lower-case words, none an
    /// article, a determiner or a joining word. The qualifier is read, never trusted: a doubtful one is prose.
    /// After a role a name that holds a lower-case word (a joining word, a particle, an article) is a name only when it names an
    /// institution: "Maintenance of Plants" is as much a duty as a name. Capitalised words only ("Ospedale San Esempio") read as
    /// a name, and so does any qualifier after a degree ("Technik und Wirtschaft"). After a role that is so only when the
    /// connector introduces an employer and nothing else (`employerConnectors`): "Tecnico per Banco di Prova" is a duty.
    private static func isReadableQualifier(_ words: [Substring], afterRole: Bool, afterEmployerConnector: Bool) -> Bool {
        guard let first = words.first, let last = words.last else { return false }
        func capitalised(_ word: Substring) -> Bool { word.first.map { $0.isUppercase || !$0.isLetter } ?? false }
        if capitalised(first), capitalised(last),
           words.allSatisfy({ capitalised($0) || nameParticles.contains($0.folded) || headConnectors.contains($0.folded) }),
           (readsAsAName(words, capitalised: capitalised) && !(afterRole && words.contains { !capitalised($0) })) || (namesAnInstitution(words) && (!afterRole || afterEmployerConnector)) {
            return true
        }
        return words.count <= 2 && words.allSatisfy { word in
            let folded = word.folded
            return word.first?.isLowercase == true && !determiners.contains(folded) && !headConnectors.contains(folded)
                && !elidedArticles.contains(where: folded.hasPrefix)
        }
    }

    /// Whether words are a school or an employer name ("Universität der Künste"): a school or organisation word with only names
    /// and modifiers before it, after it only capitalised words, particles, joining words and articles, ending on a capitalised
    /// word. Such a name keeps its articles, which a duty read as a name would not. One pass, no recursion.
    private static func namesAnInstitution(_ words: [Substring]) -> Bool {
        guard let last = words.last, last.first?.isUppercase == true,
              let head = words.firstIndex(where: { namesInstitutionByItself($0.folded) }),
              words[..<head].allSatisfy({ isModifier($0) }) else { return false }
        return words[(head + 1)...].allSatisfy { word in
            let folded = word.folded
            return word.first.map { $0.isUppercase || !$0.isLetter } == true || nameParticles.contains(folded)
                || headConnectors.contains(folded) || determiners.contains(folded)
        }
    }

    /// Whether capitalised words read as a name and not as a duty joined like prose ("Prüfung und Wartung der Anlagen",
    /// German capitalises its nouns): no lower-case article or determiner, except a particle right after another one
    /// ("van der"), and at most one run of joining words or particles between the capitalised words. A joining word that
    /// is also a contracted article ("delle", "du") joins and does not count as an article.
    private static func readsAsAName(_ words: [Substring], capitalised: (Substring) -> Bool) -> Bool {
        var runs = 0
        var previousWasLower = false
        var previousFolded = ""
        for word in words {
            let folded = word.folded
            if capitalised(word) {
                previousWasLower = false
            } else {
                if !previousWasLower { runs += 1 }
                let article = determiners.contains(folded) && !headConnectors.contains(folded)
                let afterParticle = previousWasLower && nameParticles.contains(previousFolded)
                if article && !afterParticle { return false }
                previousWasLower = true
            }
            previousFolded = folded
        }
        return runs <= 1
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
        if hasLegalForm(text) { return true }
        return words.contains { organisationWords.contains($0) || organisationStems.contains(where: $0.hasPrefix) }
    }

    /// Whether the vocabulary explains a whole line, so that the line denotes no person: it carries a legal form, opens with
    /// a word of an organisation or a school, has such a word before a connector ("Ospedale di Erfurt"), or every one of its
    /// words is a role, a role modifier, an organisation or school word, a connector or a known place ("Senior Nurse",
    /// "Head Cook"). One word no list explains ("Priya Cook", "Luca Fabbro") leaves the line a possible person: a surname
    /// may be a trade, a firm's word or a school's.
    static func explainsWholeLine(_ text: String) -> Bool {
        let words = text.words.map(String.init)
        guard !words.isEmpty else { return false }
        if hasLegalForm(text) { return true }
        let folded = words.map { $0.folded }
        let namesAnInstitution = { (word: String) in isOrganisation(word) || isSchool(word) }
        if namesAnInstitution(words[0]) { return true }
        if folded.indices.dropLast().contains(where: { namesAnInstitution(words[$0]) && connectors.contains(folded[$0 + 1]) }) { return true }
        // A place word explains a word only after a role or an institution word, never as the first one: a given name may be
        // a city too ("Charlotte Baker"), and nothing outside the ambiguous word then says it is a place (#328).
        return words.indices.allSatisfy { index in
            let word = words[index]
            let followsARoleOrInstitution = words[..<index].contains { isRole($0) || namesAnInstitution($0) }
            return connectors.contains(folded[index]) || roleModifiers.contains(folded[index]) || isRole(word)
                || namesAnInstitution(word) || (followsARoleOrInstitution && Places.isPlaceOnly(word))
        }
    }

    /// The words that qualify a role without being one.
    private static let roleModifiers: Set<String> = Set([
        "senior", "junior", "head", "chief", "lead", "assistant", "deputy", "vice", "general", "associate", "trainee", "acting",
        "leitende", "leitender", "leitung", "stellvertretende", "stellvertretender", "oberarzt", "erste", "erster", "kaufmännische",
        "capo", "vice", "primo", "prima", "aiuto", "responsabile", "junior", "jefe", "jefa", "adjunto", "adjunta", "chef", "adjoint",
    ].map(\.folded))

    /// The words that join the parts of a role or an organisation.
    private static let connectors: Set<String> = Set([
        "of", "the", "and", "for", "at", "in", "&", "für", "der", "die", "das", "und", "des", "di", "del", "della", "dei", "delle",
        "e", "ed", "de", "la", "le", "el", "y", "du", "et", "da", "do", "dos", "das", "per", "al", "alla", "zu", "zur", "zum", "im",
    ].map(\.folded))

    /// Whether a piece carries a legal form ("GmbH", "Ltd", "S.r.l.", "Inc.").
    private static func hasLegalForm(_ text: String) -> Bool {
        let words = text.words.map { $0.folded }
        let compact = text.folded.filter { $0.isLetter || $0 == "." || $0 == " " }
        return legalForms.contains(where: { words.contains($0) }) || dottedLegalForms.contains(where: { compact.contains($0) })
    }

    /// Whether a folded word names an institution by itself, so that "Universität der Künste" is a name and "Bau der Anlagen"
    /// is not: only the nouns of ``institutionWords`` and ``institutionStems``, never a sector word, an activity or an adjective.
    private static func namesInstitutionByItself(_ word: String) -> Bool {
        institutionWords.contains(word) || institutionStems.contains(where: word.hasPrefix)
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
        "bank", "cassa", "caisse", "sparkasse", "banca", "banco", "banque", "studio", "agency", "agenzia", "agentur", "agencia", "agence", "agência",
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

    /// The organisation words that also end a functional title ("Manager for Systems and Integration", "Lead for Logistics and
    /// Services"): alone they do not make a name an employer.
    private static let genericOrganisationWords: Set<String> = Set([
        "labs", "solutions", "systems", "services", "consulting", "technologies", "partners", "logistik", "logistica", "logística",
        "logistique", "werk", "werke", "bau", "elektro", "handwerk",
    ].map(\.folded))

    /// Whether a piece reads as an organisation by a legal form or by a word that is not generic vocabulary.
    static func isOrganisationBeyondGenericWords(_ text: String) -> Bool {
        let words = text.words.map { $0.folded }
        let compact = text.folded.filter { $0.isLetter || $0 == "." || $0 == " " }
        if legalForms.contains(where: { words.contains($0) }) || dottedLegalForms.contains(where: { compact.contains($0) }) { return true }
        return words.contains { !genericOrganisationWords.contains($0) && (organisationWords.contains($0) || organisationStems.contains(where: $0.hasPrefix)) }
    }

    /// Whether a name holds a lowercase linking particle between its capitalised words ("Systems and Integration").
    static func hasLinkingParticle(_ text: String) -> Bool {
        text.words.contains { linkingParticles.contains($0.lowercased()) || $0.first?.isLowercase == true && $0.contains("'") }
    }

    private static let organisationStems = ["elektrotechn", "krankenh", "ospedal"].map(\.folded)

    private static let schoolWords: Set<String> = Set([
        "university", "università", "universität", "universidad", "université", "universidade", "universita", "college", "school",
        "scuola", "schule", "escuela", "école", "escola", "politecnico", "polytechnic", "hochschule", "fachhochschule", "technische",
        "liceo", "istituto", "institute", "institut", "instituto", "gymnasium", "realschule", "gesamtschule", "berufsschule",
        "berufskolleg", "lycée", "colegio", "academy", "accademia", "akademie", "academia", "académie", "conservatorio",
        "conservatory", "iis", "itis", "ipsia", "ies", "iut", "insa", "faculdade", "facultad", "faculté", "facoltà",
        "fakultät", "campus", "uni", "tu", "hs", "eth", "epfl", "kollegschule", "volkshochschule",
    ].map(\.folded))

    /// Nouns that name an institution by themselves, in the six languages (schools, hospitals, associations,
    /// ministries). Narrower than `schoolWords` and `organisationWords`, which also hold sector and activity words.
    private static let institutionWords: Set<String> = Set([
        // English
        "school", "college", "academy", "institute", "faculty", "conservatory", "hospital", "clinic",
        "association", "ministry", "company",
        // Italian
        "scuola", "liceo", "accademia", "istituto", "facoltà", "conservatorio", "ospedale", "clinica",
        "associazione", "ministero", "comune", "azienda", "società",
        // Spanish
        "escuela", "colegio", "academia", "instituto", "facultad", "conservatorio", "hospital", "clínica",
        "asociación", "ministerio", "municipio", "ayuntamiento", "empresa", "sociedad",
        // French
        "école", "lycée", "collège", "académie", "institut", "faculté", "conservatoire", "hôpital", "clinique",
        "association", "ministère", "mairie", "entreprise", "société",
        // German
        "schule", "gymnasium", "akademie", "institut", "fakultät", "konservatorium", "krankenhaus", "klinik", "klinikum",
        "stiftung", "verein", "ministerium", "gemeinde", "stadtverwaltung", "unternehmen",
        // Portuguese
        "escola", "liceu", "academia", "instituto", "faculdade", "conservatório", "hospital", "clínica",
        "associação", "ministério", "prefeitura", "empresa", "sociedade",
    ].map(\.folded))

    private static let institutionStems = [
        "universit", "hochschul", "fachhochschul", "politecnic", "gymnasi", "berufsschul", "fachschul", "krankenh",
    ].map(\.folded)

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

    /// The connectors that also occur inside a title ("Teacher for Special Needs"): read only when nothing else can hold the employer.
    static let weakConnectors = [" para ", " für ", " for ", " per "]

    /// The lowercase words that link the capitalised words of an organisation's name: "Bank of Scotland", "Cassa di Risparmio",
    /// "Banco do Brasil", "Institut für Informatik". An elided one ("d'Épargne", "l'Avenir") is a particle with its noun.
    static let linkingParticles: Set<String> = [
        "of", "and", "for", "de", "del", "della", "di", "da", "do", "dos", "das", "du", "des", "la", "le", "el", "van", "von", "der",
        "den", "für", "zu", "zur", "zum", "y", "e", "et", "en", "d'", "l'", "dell'", "all'",
    ]

    /// Whether every word of a name starts with a capital, a lowercase linking particle between two capitalised words being
    /// one too: "Bank of Scotland" is a name, "Systems integration" is a title's tail.
    static func isCapitalisedName(_ text: String) -> Bool {
        let words = text.words.map(String.init)
        guard words.first?.first?.isUppercase == true else { return false }
        return words.indices.allSatisfy { index in
            let word = words[index]
            if word.first?.isUppercase == true { return true }
            if linkingParticles.contains(word.lowercased()) { return index + 1 < words.count && words[index + 1].first?.isUppercase == true }
            guard let apostrophe = word.firstIndex(where: { $0 == "'" || $0 == "\u{2019}" }) else { return false }
            let particle = word[...apostrophe].lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
            return linkingParticles.contains(particle) && word[word.index(after: apostrophe)...].first?.isUppercase == true
        }
    }

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
                     "nome completo", "full name", "vollständiger name", "nombre completo", "surname first name", "first name surname",
                     "cognome nome", "nome cognome", "nachname vorname", "vorname nachname", "apellidos nombre", "nombre apellidos",
                     "apellido nombre", "nombre apellido", "nom prénom", "prénom nom", "apelido nome", "nome apelido", "apelidos nome",
                     "sobrenome nome", "nome sobrenome"]),
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
            (.maritalStatus, ["marital status", "stato civile", "familienstand", "estado civil", "situation familiale", "état civil", "etat civil"]),
            (.gender, ["sex", "gender", "sesso", "geschlecht", "sexo", "sexe"]),
            (.fax, ["fax", "telefax"]),
        ]
        var table: [String: PersonalLabel] = [:]
        for (label, texts) in groups {
            for text in texts { table[SectionVocabulary.key(text)] = label }
        }
        return table
    }()

    // MARK: The values of the closed details

    /// Whether a text reads as the value of a closed personal detail (a gender, a marital status, a nationality), as
    /// opposed to the words of a job title that start with the label ("Gender Pay Analyst").
    static func looksLikeValue(_ text: String, of label: PersonalLabel) -> Bool {
        let key = SectionVocabulary.key(text)
        switch label {
        case .gender: return genderValues.contains(key)
        case .maritalStatus: return maritalValues.contains(key)
        case .nationality: return looksLikeNationality(text)
        default: return true
        }
    }

    private static let genderValues: Set<String> = Set([
        "male", "female", "m", "f", "w", "h", "man", "woman", "non-binary", "nonbinary", "non binary", "non binaire", "nichtbinär",
        "nicht binär", "non binario", "no binario", "não binário", "nao binario", "diverse", "other", "x", "maschio", "femmina",
        "maschile", "femminile", "uomo", "donna", "männlich", "weiblich", "divers", "mann", "frau", "masculino", "feminino",
        "femenino", "hombre", "mujer", "masculin", "féminin", "homme", "femme", "masculina", "feminina", "m/f", "m/w", "m/w/d",
    ].map(SectionVocabulary.key))

    private static let maritalValues: Set<String> = Set([
        "single", "married", "divorced", "widowed", "separated", "partnered", "celibe", "nubile", "coniugato", "coniugata",
        "coniugato/a", "sposato", "sposata", "sposato/a", "divorziato", "divorziata", "vedovo", "vedova", "separato", "separata",
        "convivente", "libero", "libera", "ledig", "verheiratet", "geschieden", "verwitwet", "getrennt lebend", "soltero", "soltera",
        "casado", "casada", "divorciado", "divorciada", "viudo", "viuda", "separado", "separada", "célibataire", "marié", "mariée",
        "divorcé", "divorcée", "veuf", "veuve", "séparé", "séparée", "pacsé", "pacsée", "solteiro", "solteira", "viúvo", "viúva",
        "in partnership", "civil partnership", "in a relationship", "domestic partnership", "cohabiting", "unmarried",
        "in unione civile", "unito civilmente", "unita civilmente", "unione civile", "in coppia", "fidanzato", "fidanzata",
        "lebenspartnerschaft", "in partnerschaft", "eingetragene lebenspartnerschaft", "lebensgemeinschaft", "in einer beziehung", "unión libre", "pareja de hecho", "en pareja", "unión de hecho", "union libre", "en couple",
        "concubinage", "vie maritale", "união de facto", "união estável", "união estavel", "em união de facto", "namorando",
        "em relacionamento",
    ].map(SectionVocabulary.key))

    /// A nationality is one word ("German", "Tedesca"), or a few of them in a list ("German, Italian"), or a country's name
    /// of two words ("South African"); a few words of a job ("Law Associate") or a role word alone are not.
    private static func looksLikeNationality(_ text: String) -> Bool {
        guard !text.contains(where: \.isNumber) else { return false }
        let parts = nationalityParts(of: text)
        guard (1...4).contains(parts.count) else { return false }
        return parts.allSatisfy(isOneNationality)
    }

    /// The words of each nationality of a list, which punctuation or the language's joining word ("and", "und", "e", "y",
    /// "et") separates. Told before the key drops the joining words.
    private static func nationalityParts(of text: String) -> [[String]] {
        var parts: [[String]] = []
        for list in text.split(whereSeparator: { ",/;&".contains($0) }) {
            var part: [String] = []
            for token in list.split(separator: " ") {
                if joiningNationalityWords.contains(token.folded) {
                    parts.append(part)
                    part = []
                } else {
                    part.append(SectionVocabulary.key(String(token)))
                }
            }
            parts.append(part)
        }
        return parts.map { $0.filter { !$0.isEmpty } }.filter { !$0.isEmpty }
    }

    private static let joiningNationalityWords: Set<String> = ["and", "und", "e", "y", "et"]

    /// One nationality: one word ("German"), or a country's name of two words ("South African"); a role word is not one.
    private static func isOneNationality(_ words: [String]) -> Bool {
        if words.contains(where: nonNationalityWords.contains) { return false }
        return words.count == 1 || (words.count == 2 && nationalityPrefixes.contains(words[0]))
    }

    private static let nationalityPrefixes: Set<String> = Set([
        "south", "north", "new", "sri", "costa", "puerto", "saudi", "hong", "east", "west", "sud", "nord", "süd", "sur", "norte",
        "dominican", "central", "san", "el", "united", "czech", "ivory", "burkina", "papua",
    ].map(SectionVocabulary.key))

    private static let nonNationalityWords: Set<String> = Set([
        "manager", "analyst", "engineer", "developer", "designer", "consultant", "specialist", "director", "lead", "officer",
        "assistant", "associate", "teacher", "advisor", "adviser", "coordinator", "berater", "leiter", "analista", "ingeniero",
        "responsable", "consulente", "gestore", "direttore", "tecnico", "técnico", "ingegnere", "sviluppatore",
    ].map(SectionVocabulary.key))

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
