import Foundation

/// What the verbs of a clause make of a mention of an entry (ADR 0023, rule (c)).
///
/// - A **factual verb** is a CV verb in a form the vocabulary lists, or the present or the past of "to be" or of "to have" ("I'm a
///   nurse at Acme", "I have a BLS", "ho lavorato"). The device's lexical class tells which words are verbs in English and German;
///   in the other languages a verb that is not listed is told by its form (`VerbForms`).
/// - The mention is **factual** when every verb before the name, and before the clause's first factual verb, is factual: a verb in
///   another form, an infinitive and a verb after "to", "zu", "di", "de", "per", "para" or "pour" are not, so "I try to work at Acme",
///   "I studied hard to work at Acme" and "Resterò presso Acme" mention nothing. A clause without a verb is factual.
/// - And when every word that leads in to the statement is explained: by the closed vocabulary, a number among its words, or by the
///   entry's or the person's own quotes. The device tags no verb of Italian, Spanish, French or Portuguese, so a word that nothing
///   explains there may be a verb it cannot see: "Cerco lavoro come infermiera", "Sogno Acme dal 2027". The lead-in is the words
///   before the name or before the clause's first factual verb, whichever comes first; what comes after is the statement's own
///   ("I moved from Beta to Acme", "ACLS certifications from the Italian Resuscitation Council").
/// - A verb after both the name and a factual verb is a **purpose or a detail**: it does not undo the mention, and the words from it
///   (or from the "to" or "per" that introduces it) to the end of the clause give no facts. The verb that completes the first factual
///   one is no such verb: "ho lavorato" is one.
/// - The clause must **speak for the person** (`speaksForThePerson`, see `Voice`): its explicit subject is a first-person pronoun, or
///   it has none the way a CV writes ("Worked at Acme"). A noun, a name, a pronoun of the third person and a possession of a person
///   ("A nurse worked at Acme", "My sister is a nurse") are someone else, and a verb form of another person does not stand in a
///   clause with no subject ("ha lavorato", "trabajó").
struct Statement {
    let isFactual: Bool
    /// How many words of the clause give facts: all of them, but for the words of a purpose or a detail after the statement.
    let factualWords: Int
    /// Whether the clause holds a verb: the device's tags, the vocabulary's forms or the endings of a language that has no tags.
    let hasVerbs: Bool
    /// Whether the clause speaks for the person (see `Voice`): its explicit subject is a first-person pronoun, or it has none and its
    /// first verb is no form of another person.
    let speaksForThePerson: Bool
    /// Whether the clause starts with its verb: with no subject of its own it shares the subject of the clause before it.
    let startsWithItsVerb: Bool
    /// Whether the clause names a person other than the one it speaks for (see `Voice.namesAnotherPerson`): a contact in it is not
    /// the person's.
    let namesAnotherPerson: Bool
    /// Whether the clause gives the person's contact: their possession of a contact field, or a verb of contacting whose object is the
    /// person (see `Voice.offersAContact`).
    let offersAContact: Bool

    private init(
        isFactual: Bool, factualWords: Int, hasVerbs: Bool, speaksForThePerson: Bool, startsWithItsVerb: Bool, namesAnotherPerson: Bool,
        offersAContact: Bool
    ) {
        self.isFactual = isFactual
        self.factualWords = factualWords
        self.hasVerbs = hasVerbs
        self.speaksForThePerson = speaksForThePerson
        self.startsWithItsVerb = startsWithItsVerb
        self.namesAnotherPerson = namesAnotherPerson
        self.offersAContact = offersAContact
    }

    /// The same statement, factual only if `condition` holds as well.
    func requiring(_ condition: Bool) -> Statement {
        Statement(
            isFactual: isFactual && condition, factualWords: factualWords, hasVerbs: hasVerbs, speaksForThePerson: speaksForThePerson && condition,
            startsWithItsVerb: startsWithItsVerb, namesAnotherPerson: namesAnotherPerson, offersAContact: offersAContact
        )
    }

    /// - Parameters:
    ///   - words: The words of the clause.
    ///   - name: Where the clause begins to name the entry.
    ///   - quoted: The positions of the words that are part of a quote of the draft: names of entries and of the person, no verbs.
    ///   - own: The positions of the words that are part of a quote of the entry or of the person, which explain themselves; nil to
    ///     ask no word of the lead-in to be explained.
    ///   - language: The language of the description, when it is known.
    init(words: [Word], name: Int, quoted: Set<Int>, own: Set<Int>?, language: Vocabulary.Language?) {
        let verbs = VerbReader(words: words, quoted: quoted, language: language).verbs
        let first = verbs.firstIndex(where: \.isFactual)
        let boundary = first.map { max(name, verbs[$0].index) } ?? Int.max
        let explainedBoundary = min(name, first.map { verbs[$0].index } ?? name)
        let isExplained = own.map { own in
            words.indices.prefix(explainedBoundary).allSatisfy { own.contains($0) || words[$0].isNumber || Vocabulary.explains(words[$0].folded, in: language) }
        } ?? true

        hasVerbs = !verbs.isEmpty
        startsWithItsVerb = verbs.first?.index == 0
        let everyday = words.indices.filter { index in
            !quoted.contains(index) && Vocabulary.isEverydayVerb(words[index].accented, in: language)
                && !(index > 0 && Voice.isNounSign(words[index - 1].accented, in: language))
        }
        let finite = Set(verbs.filter(\.isFinite).map(\.index)).union(everyday)
        speaksForThePerson = Voice.speaks(words: words, verbs: finite, language: language)
        namesAnotherPerson = Voice.namesAnotherPerson(words: words, verbs: finite, language: language)
        offersAContact = Voice.offersAContact(words: words, verbs: finite, language: language)
        isFactual = speaksForThePerson && isExplained && (first == nil ? verbs.isEmpty : !verbs.contains { !$0.isFactual && $0.index < boundary })
        if let first {
            let statement = Self.statement(of: verbs, from: first)
            let purpose = verbs.indices.first { verbs[$0].index > boundary && !statement.contains($0) }.map { verbs[$0].index }
            factualWords = purpose.map { Self.start(of: $0, in: words, language: language) } ?? words.count
        } else {
            factualWords = words.count
        }
    }

    /// The statement of a clause that names no entry: every verb of it comes before a name, so each must be factual.
    ///
    /// - Parameters:
    ///   - own: The quotes that explain themselves; nil to ask no word to be explained.
    ///   - name: Where the name stands: past the end of the clause when it names no entry, at its start to read what comes after the
    ///     statement's first verb as a purpose.
    init(clause: Clause, quotes: [[String]], own: [[String]]? = nil, name: Int = .max, language: Vocabulary.Language?) {
        self.init(words: clause.words, name: name, quoted: clause.positions(inside: quotes), own: own.map { clause.positions(inside: $0) }, language: language)
    }

    /// The statement of a clause that names the entry, or nil when it does not.
    ///
    /// - Parameters:
    ///   - naming: The phrases the clause must all hold to name the entry.
    ///   - quotes: Every quote of the draft and of the person: their words are names, and no verbs.
    ///   - own: The quotes of the entry and of the person: their words explain themselves.
    ///   - standalone: The quotes a phrase may be a part of, so that it does not name the entry (see `Clause.standaloneSpans`).
    init?(
        clause: Clause, naming phrases: [[String]], quotes: [[String]], own: [[String]], standalone: [[String]], language: Vocabulary.Language?
    ) {
        guard let name = clause.nameStart(of: phrases, amongQuotes: standalone) else { return nil }
        self.init(words: clause.words, name: name, quoted: clause.positions(inside: quotes), own: clause.positions(inside: own), language: language)
    }

    /// Where a purpose that begins with the verb at `index` begins: at the word that introduces it ("to support", "per sostenere").
    private static func start(of index: Int, in words: [Word], language: Vocabulary.Language?) -> Int {
        index > 0 && VerbForms.isInfinitiveMarker(words[index - 1].folded, in: language) ? index - 1 : index
    }

    /// The positions, among `verbs`, of the statement: the first factual verb and the verbs that complete it.
    private static func statement(of verbs: [Verb], from first: Int) -> Set<Int> {
        var group: Set<Int> = [first]
        var current = first
        while true {
            let next: Int?
            switch verbs[current].completion {
            case .none:
                next = nil
            case .next:
                next = verbs.indices.dropFirst(current + 1).first { verbs[$0].isFactual }
            case .adjacent:
                next = verbs.indices.dropFirst(current + 1).first { verbs[$0].isFactual && verbs[$0].index == verbs[current].index + 1 }
            }
            guard let next else { return group }
            group.insert(next)
            current = next
        }
    }
}

// MARK: - Verbs

/// What completes a verb: a participle or a gerund that goes with it, and is no verb of its own.
private enum Completion {
    case none
    /// The next verb: the participle of "have worked", "ho lavorato", "habe gearbeitet".
    case next
    /// The verb right after it: the gerund or the participle of "was working", "have been working".
    case adjacent
}

private struct Verb {
    let index: Int
    let isFactual: Bool
    let completion: Completion
    /// Whether the verb can be the one a subject goes with: no infinitive, no gerund that nothing makes finite ("Interests: reading",
    /// "problem solving"), and no level word the device takes for a participle ("Swift (fortgeschritten)").
    var isFinite = true
}

/// The verbs of a clause, each with whether it is factual.
private struct VerbReader {
    let words: [Word]
    let quoted: Set<Int>
    let language: Vocabulary.Language?

    var verbs: [Verb] {
        words.indices.compactMap { index in
            guard !quoted.contains(index), !words[index].isNumber else { return nil }
            return verb(at: index)
        }
    }

    /// The verb at `index`, or nil when the word is no verb.
    private func verb(at index: Int) -> Verb? {
        let word = words[index]
        let isBe = Vocabulary.isBeForm(word.accented, in: language)
        let isAuxiliary = Vocabulary.isAuxiliary(word.accented, in: language)
        let isListed = Vocabulary.isVerb(word.folded, in: language) || isBe || isAuxiliary

        if isInfinitive(at: index, isListed: isListed) { return Verb(index: index, isFactual: false, completion: .none, isFinite: false) }
        if isListed && !isBe && !isAuxiliary && isNoun(at: index) { return nil }
        if isListed {
            return Verb(
                index: index, isFactual: true, completion: isBe ? .adjacent : isAuxiliary ? .next : .none,
                isFinite: isBe || isAuxiliary || isFiniteWhenListed(word)
            )
        }
        if VerbForms.hasTenseEnding(word, in: language) { return Verb(index: index, isFactual: false, completion: .none) }
        if word.isTaggedVerb {
            let isBare = VerbForms.isBareGerund(word, after: index > 0 ? words[index - 1] : nil, in: language)
            return Verb(index: index, isFactual: false, completion: .none, isFinite: !isBare && !Vocabulary.isLevel(word.folded, in: language))
        }
        return nil
    }

    /// Whether a listed form that is no form of "to be" and no auxiliary is a finite verb: in English and German, where the device tags
    /// the verbs, when it tags it (or, in English, when it ends like a past or a third person, which it misses after a name); a base
    /// form that it leaves untagged is a noun ("quality control").
    private func isFiniteWhenListed(_ word: Word) -> Bool {
        guard VerbForms.readsVerbsByTags(in: language) else { return true }
        return word.isTaggedVerb || (language == .english && (word.folded.hasSuffix("ed") || word.folded.hasSuffix("s")))
    }

    /// Whether the word at `index`, a form of a verb of the vocabulary, is a noun: in Italian, Spanish, French and Portuguese it
    /// follows an article, a possessive or a simple preposition ("professora do ensino", "il mio lavoro", "au travail"), and the
    /// device tags no verb there to tell otherwise.
    private func isNoun(at index: Int) -> Bool {
        guard index > 0, VerbForms.readsInfinitivesByEnding(in: language) else { return false }
        return Voice.isNounSign(words[index - 1].accented, in: language)
    }

    /// Whether the verb at `index` is an infinitive: a verb after "to" or "zu"; in Italian, Spanish, French and Portuguese a word that
    /// ends like one, after a word that introduces an infinitive, at the start of the clause, or after a word that is no word of the
    /// vocabulary and no name (an unlisted verb: "intento trabajar", "vou trabalhar"). After an article, a preposition or a pronoun of
    /// the vocabulary it is a noun ("come ingegnere", "au centre").
    private func isInfinitive(at index: Int, isListed: Bool) -> Bool {
        let word = words[index]
        let previous = index > 0 ? words[index - 1] : nil
        let isAfterAMarker = previous.map { VerbForms.isInfinitiveMarker($0.folded, in: language) } ?? false

        if isAfterAMarker && word.isTaggedVerb { return true }
        guard VerbForms.readsInfinitivesByEnding(in: language) else { return isAfterAMarker && isListed }
        guard VerbForms.hasInfinitiveEnding(word, in: language), !Vocabulary.explains(word.folded, in: language) else { return false }
        guard let previous else { return true }
        return isAfterAMarker || (!previous.isNumber && !quoted.contains(index - 1) && !Vocabulary.explains(previous.folded, in: language))
    }
}
