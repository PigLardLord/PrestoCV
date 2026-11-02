import Foundation

/// A sentence of the draft that says the person is, or works as, what no kept title names (#354, the final gate; ADR 0031, O1):
/// "As a nurse, I coordinate patient care." of a person who stated "nursing assistant". The draft infers the skills and the duties
/// typical of a stated role, never a role the person did not state.
///
/// A role is the noun phrase after the words that put one forward: "as" (and "come", "als", "comme", "como") after a form of "work",
/// "start" or "be employed", or opening a clause; French "en tant que" and Italian "in qualità di"; and "I am a", "I have been a" and
/// their kin before an indefinite article (in German before a capitalized noun: "Ich bin Krankenpflegerin."). The phrase is kept when
/// a kept title holds all its words, masculine and feminine read as one ("infermiera" is "infermiere"); a head-first title may go on
/// with words of its own ("programador utilizando"), and a German compound title names its last part ("Gärtnerin" of a
/// "Landschaftsgärtnerin"). A phrase whose head names no trade ("part", "team player", "result") is no role.
enum RoleAssertion {
    /// The first role `sentence` puts forward that no title of `titles` names, in its folded words with the words of `name` left
    /// out; nil when it puts forward none, or when its language is not one of the six.
    static func unkeptRole(in sentence: String, titles: [String], name: String?, language: Vocabulary.Language?) -> String? {
        guard let language else { return nil }
        let tokens = tokens(in: sentence)
        let titleWords = titles.map { Word.words(in: $0).map { gendered($0.folded, in: language) } }.filter { !$0.isEmpty }
        let nameWords = Set(Word.words(in: name ?? "").map(\.folded))
        let headsLast = language == .english || language == .german

        for start in starts(in: tokens, language: language) {
            guard let span = phrase(in: tokens, from: start, language: language) else { continue }
            let phrase = tokens[span].map(\.folded).filter { !nameWords.contains($0) }
            guard let head = headsLast ? phrase.last : phrase.first, !genericWords.contains(head) else { continue }
            let gendered = phrase.map { Self.gendered($0, in: language) }
            if titleWords.contains(where: { Set(gendered).isSubset(of: $0) }) { continue }
            if !headsLast, titleWords.contains(where: { gendered.starts(with: $0) }) { continue }
            if language == .german, gendered.count == 1, titleWords.joined().contains(where: { $0.hasSuffix(gendered[0]) }) { continue }
            return phrase.joined(separator: " ")
        }
        return nil
    }

    // MARK: The words of a sentence

    /// A word of a sentence, as the check reads it.
    private struct Token {
        let folded: String
        let isCapitalized: Bool
        /// Whether a comma, a semicolon or a colon follows it, past the brackets and quotes that close it: a clause starts after it.
        let endsAClause: Bool
    }

    private static func tokens(in sentence: String) -> [Token] {
        let characters = Array(Digits.ascii(sentence))
        return Word.words(in: sentence).map { word in
            var index = word.range.upperBound
            while index < characters.count, ")]}\"'»”’ ".contains(characters[index]) { index += 1 }
            return Token(
                folded: word.folded,
                isCapitalized: characters[word.range.lowerBound].isUppercase,
                endsAClause: word.endsWithABreak || index < characters.count && characters[index] == ":"
            )
        }
    }

    // MARK: Where a role starts

    /// Where a role may start, and whether a bare "as" opening a clause put it forward: English then names a role only before an
    /// article ("As a nurse"), not in "As part of" or "As well as".
    private struct Start {
        let index: Int
        let isBare: Bool
    }

    private static func starts(in tokens: [Token], language: Vocabulary.Language) -> [Start] {
        let words = tokens.map(\.folded)
        var starts: [Start] = []
        for (index, word) in words.enumerated() {
            let following = Array(words.dropFirst(index + 1).prefix(2))
            if word == roleAs[language] {
                let before = index > 0 ? words[index - 1] : nil
                if let before, workWords.contains(before) || word == "als" && germanAlsSubjects.contains(before) {
                    starts.append(Start(index: index + 1, isBare: false))
                } else if index == 0 || tokens[index - 1].endsAClause {
                    starts.append(Start(index: index + 1, isBare: true))
                }
            }
            if language == .french, word == "en", following == ["tant", "que"] || following == ["tant", "qu"] {
                starts.append(Start(index: index + 3, isBare: false))
            }
            if language == .italian, word == "in", following == ["qualita", "di"] {
                starts.append(Start(index: index + 3, isBare: false))
            }
            for lead in beLeads[language] ?? [] where words.dropFirst(index).starts(with: lead) && index + lead.count < words.count {
                let next = index + lead.count
                if indefiniteArticles.contains(words[next]) {
                    starts.append(Start(index: next + 1, isBare: false))
                } else if language == .german, tokens[next].isCapitalized {
                    starts.append(Start(index: next, isBare: false))
                }
            }
        }
        return starts
    }

    /// The words of the role from `start`, past its articles and the qualities said before it, up to a function word, the end of
    /// a clause, a German word in lower case or an English word in -ing or -ly; nil when no role starts there.
    private static func phrase(in tokens: [Token], from start: Start, language: Vocabulary.Language) -> Range<Int>? {
        let words = tokens.map(\.folded)
        var first = start.index
        while first < words.count, articles.contains(words[first]) || qualities.contains(words[first]) { first += 1 }
        guard first < words.count, !stops.contains(words[first]) else { return nil }
        if start.isBare, language == .english, !articles.contains(words[start.index]) { return nil }
        if language == .german, !tokens[first].isCapitalized { return nil }

        var end = first
        while end < words.count {
            if end > first, stops.contains(words[end]) { break }
            if language == .german, !tokens[end].isCapitalized { break }
            if language == .english, end > first, words[end].hasSuffix("ing") || words[end].hasSuffix("ly") { break }
            end += 1
            if tokens[end - 1].endsAClause { break }
        }
        return first..<end
    }

    // MARK: Masculine and feminine

    /// `word` with a feminine or plural ending read as the masculine one, roughly: enough to read "infermiera" as "infermiere" and
    /// "Pflegehelferin" as "Pflegehelfer", not a grammar.
    private static func gendered(_ word: String, in language: Vocabulary.Language) -> String {
        switch language {
        case .italian:
            if word.hasSuffix("trice") { return String(word.dropLast(5)) + "tor" }
            if word.hasSuffix("essa") { return String(word.dropLast(4)) }
            return dropping("aeio", from: word)
        case .spanish, .portuguese:
            return dropping("aoe", from: word)
        case .french:
            for (ending, masculine) in [("ere", "er"), ("euse", "eur"), ("rice", "eur"), ("enne", "en")] where word.hasSuffix(ending) {
                return String(word.dropLast(ending.count)) + masculine
            }
            return dropping("e", from: word)
        case .german:
            return word.hasSuffix("in") && word.count > 5 ? String(word.dropLast(2)) : word
        case .english:
            return word
        }
    }

    /// `word` without its last letter when the letter is one of `endings` and the word is longer than three letters.
    private static func dropping(_ endings: String, from word: String) -> String {
        guard word.count > 3, let last = word.last, endings.contains(last) else { return word }
        return String(word.dropLast())
    }

    // MARK: Vocabulary (as `Word.folded` writes it)

    /// The word before a role, per language: Portuguese "as" is an article, so Portuguese has only "como".
    private static let roleAs: [Vocabulary.Language: String] = [
        .english: "as", .italian: "come", .german: "als", .french: "comme", .spanish: "como", .portuguese: "como",
    ]

    /// The forms of "work", "start" and "be employed" that a role follows: "I worked as", "ho iniziato come", "angestellt als".
    private static let workWords: Set<String> = [
        "work", "works", "worked", "working", "lavoro", "lavorato", "lavoravo", "lavora", "arbeite", "arbeitete", "gearbeitet",
        "arbeitet", "travaille", "travaillais", "trabajo", "trabaje", "trabajaba", "trabajado", "trabalho", "trabalhei", "trabalhava",
        "trabalhado", "started", "began", "start", "iniziato", "cominciato", "comincio", "inizio", "angefangen", "begonnen",
        "commence", "debute", "empece", "comence", "empezado", "comecei", "comecado", "employed", "hired", "assunto", "assunta",
        "impiegato", "impiegata", "angestellt", "beschaftigt", "tatig", "embauche", "embauchee", "contratado", "contratada",
    ]

    /// The German words that "als" follows in a clause whose verb comes later: "Davor habe ich als Monteur gearbeitet".
    private static let germanAlsSubjects: Set<String> = [
        "ich", "habe", "hatte", "war", "bin", "bereits", "zuvor", "davor", "auch", "jahre", "jahren",
    ]

    /// The forms of "I am" and "I have been" that put a role forward before an indefinite article.
    private static let beLeads: [Vocabulary.Language: [[String]]] = [
        .english: [["i", "am"], ["i", "m"], ["i", "was"], ["i", "have", "been"], ["i", "ve", "been"]],
        .italian: [["sono"], ["ero"], ["sono", "stato"], ["sono", "stata"]],
        .german: [["ich", "bin"], ["bin", "ich"], ["ich", "war"], ["war", "ich"]],
        .french: [["je", "suis"], ["j", "etais"], ["j", "ai", "ete"]],
        .spanish: [["soy"], ["era"], ["fui"], ["he", "sido"]],
        .portuguese: [["sou"], ["era"], ["fui"], ["tenho", "sido"]],
    ]

    private static let indefiniteArticles: Set<String> = ["a", "an", "un", "uno", "una", "ein", "eine", "une", "um", "uma"]

    /// The articles and possessives before a role.
    private static let articles: Set<String> = [
        "a", "an", "the", "un", "una", "uno", "l", "il", "lo", "la", "ein", "eine", "einer", "einem", "der", "die", "une", "le", "el",
        "um", "uma", "o", "my", "mio", "mia", "mein", "meine", "meiner", "meinem", "mon", "ma", "mi", "meu", "minha",
    ]

    /// The qualities said before a role, which name no title: "an experienced nurse" is the title "nurse".
    private static let qualities: Set<String> = [
        "experienced", "dedicated", "reliable", "passionate", "motivated", "skilled", "qualified", "committed", "creative", "caring",
        "enthusiastic", "hardworking", "versatile", "seasoned", "competent", "careful", "trained", "young", "esperto", "esperta",
        "appassionato", "appassionata", "motivato", "motivata", "affidabile", "qualificato", "qualificata", "erfahrener", "erfahrene",
        "engagierter", "engagierte", "zuverlassiger", "zuverlassige", "motivierter", "motivierte", "leidenschaftlicher",
        "leidenschaftliche", "experimente", "experimentee", "passionne", "passionnee", "motive", "motivee", "experimentado",
        "experimentada", "apasionado", "apasionada", "experiente", "apaixonado", "apaixonada", "dedicado", "dedicada", "fiable",
        "confiable", "confiavel",
    ]

    /// The function words that end a role: "nurse at Riverside", "infermiera presso l'ospedale".
    private static let stops: Set<String> = [
        "in", "at", "for", "with", "and", "or", "who", "that", "since", "from", "to", "on", "of", "by", "where", "i", "as", "presso",
        "per", "con", "e", "ed", "o", "che", "da", "dal", "dalla", "nel", "nella", "di", "del", "della", "al", "alla", "dove", "come",
        "bei", "fur", "mit", "und", "oder", "der", "die", "das", "seit", "im", "am", "von", "zum", "zur", "wo", "ich", "als", "chez",
        "pour", "avec", "et", "ou", "qui", "que", "depuis", "dans", "au", "aux", "de", "du", "des", "comme", "en", "para", "y",
        "desde", "donde", "em", "no", "na", "com", "do", "onde", "como", "sur",
    ]

    /// The heads that name no trade: a kind of person ("a reliable team player"), a part ("as part of"), or a phrase that only
    /// starts like a role ("as a result", "as well as", "come sempre").
    private static let genericWords: Set<String> = [
        "person", "people", "professional", "individual", "player", "learner", "communicator", "listener", "solver", "thinker",
        "colleague", "persona", "professionista", "mensch", "fachkraft", "profi", "personne", "professionnel", "professionnelle",
        "profesional", "pessoa", "profissional", "teamplayer", "ansprechpartner", "ansprechpartnerin", "ansprechperson", "point",
        "punto", "riferimento", "reference", "contact", "interlocutore", "interlocuteur", "interlocutor", "referente", "part",
        "parte", "teil", "member", "membre", "miembro", "membro", "partie", "team", "squadra", "equipe", "equipo", "result",
        "risultato", "ergebnis", "resultat", "resultado", "rule", "regola", "regel", "regle", "regla", "regra", "whole", "such",
        "well", "soon", "usual", "needed", "follows", "example", "esempio", "beispiel", "exemple", "ejemplo", "exemplo", "sempre",
        "siempre", "toujours", "immer", "always", "consequence", "conseguenza", "folge", "consecuencia", "consequencia", "previsto",
        "richiesto", "prevu", "tale", "tal", "far", "long", "much", "many", "possible", "possibile", "moglich", "posible",
        "possivel", "if", "se", "si", "wenn", "though", "ob", "mitglied", "worker", "lavoratore", "lavoratrice", "travailleur",
        "trabajador", "trabalhador",
    ]
}
