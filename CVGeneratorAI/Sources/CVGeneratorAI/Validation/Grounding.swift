import Foundation

/// Which clauses of the description back which entry of a draft (ADR 0023, rule (c)), and what each entry may therefore say.
///
/// - A clause **backs** an entry when it names the entry (its employer, school or certification), says it as a fact (`Statement`:
///   every verb, and every word that leads in to the statement, is accounted for), holds no word of negation, doubt, wish,
///   intention, future or condition, and every word of it is explained: by the closed vocabulary, or by lying inside one of the
///   entry's own quotes. The words of a purpose or a detail after the statement give no facts, and need not be explained.
/// - A clause that backs no entry **joins** an entry when it stands in the same sentence as, and next to, a clause that backs
///   the entry, every word of it is explained by the closed vocabulary or by a quote of one of the entry's achievements, it speaks
///   for the person, and every verb of it is factual: a clause of a purpose gives nothing, nor one about someone else. A clause next to the backing clauses of two entries joins
///   neither, and nor does one whose other neighbour holds a word that nothing explains: it could be that neighbour's.
struct Grounding {
    private typealias Place = DescriptionClauses.Place

    private let clauses: DescriptionClauses
    private let explainer: Explainer
    private let subjects: [Subject]
    private let reading: Reading
    /// The clauses that name each entry, backing it or not.
    private let naming: [Set<Place>]
    /// The clauses that mention each entry by its employer, school or certification, or by its title when it has none.
    private let mentioning: [Set<Place>]
    /// The clauses that back each entry, each as far as it gives facts: up to a purpose or a detail after the statement.
    private let backingFacts: [[Place: Clause]]
    private let backing: [Set<Place>]

    /// - Parameter person: The quotes of the person's own name, place and title.
    init(clauses: DescriptionClauses, explainer: Explainer, subjects: [Subject], person: [[String]]) {
        let reading = Reading(clauses: clauses, language: explainer.language, ofEntries: subjects.flatMap(\.quotes), ofPerson: person)
        self.clauses = clauses
        self.explainer = explainer
        self.subjects = subjects
        self.reading = reading
        naming = subjects.map { Self.namingPlaces(of: $0.names, among: reading.ofEntries, in: clauses) }
        mentioning = subjects.map { Self.namingPlaces(of: $0.mentions, among: reading.ofEntries, in: clauses) }
        backingFacts = zip(subjects, naming).map { Self.backingClauses(of: $0, naming: $1, reading: reading, explainer: explainer) }
        backing = backingFacts.map { Set($0.keys) }
    }

    /// How the clauses of the description read for the entries of a draft: through the quotes of the draft, which name something and
    /// are no verbs, and the language of the description.
    private struct Reading {
        let clauses: DescriptionClauses
        let language: Vocabulary.Language?
        /// The quotes of every entry: what a name may be a part of.
        let ofEntries: [[String]]
        let ofPerson: [[String]]

        var all: [[String]] { ofEntries + ofPerson }

        /// The statement of the clause at `place` when it names the subject by `phrases`, or nil when it does not. The quotes of the
        /// subject and of the person explain themselves. A verbless clause that a comma or a conjunction split off is factual only if
        /// the clause before it is, and one that starts with its verb after a comma or a conjunction speaks for the person only if
        /// the clause before it does: it shares its subject.
        func statement(at place: Place, naming phrases: [[String]], by subject: Subject) -> Statement? {
            let clause = clauses.clause(at: place)
            guard let statement = Statement(
                clause: clause, naming: phrases, quotes: all, own: subject.quotes + ofPerson, standalone: ofEntries, language: language
            ) else { return nil }
            if clause.isAnchored { return statement }
            if !statement.hasVerbs { return statement.requiring(isFactual(before: place)) }
            return statement.startsWithItsVerb ? statement.requiring(speaks(before: place)) : statement
        }

        /// Whether the clause at `place` speaks for the person: on its own, and, when it starts with its verb after a comma or a
        /// conjunction, with the subject of the clause before it.
        func speaks(at place: Place) -> Bool {
            let clause = clauses.clause(at: place)
            let statement = Statement(clause: clause, quotes: all, language: language)
            guard statement.speaksForThePerson else { return false }
            return clause.isAnchored || !(statement.startsWithItsVerb || !statement.hasVerbs) || speaks(before: place)
        }

        private func speaks(before place: Place) -> Bool {
            speaks(at: Place(sentence: place.sentence, clause: place.clause - 1))
        }

        /// Whether the clause at `place` claims a skill, an interest or a language for the person (#202): it speaks for the person,
        /// holds no word that withdraws a claim (`Vocabulary.withdrawals`: "never", "would", "if", but not "can" or "partly"),
        /// follows no clause of its sentence that opens with a word of condition ("If I had time, I would play chess"), and, when it
        /// depends on the clause before it (a clause split off by a comma or a conjunction that has no verb, starts with its verb, or
        /// says nothing as a fact, such as "Spanisch zu lernen"), that clause claims too: "I have never used Java or Swift" claims
        /// neither, and "Ich träume davon, Spanisch zu lernen" no Spanish. A clause that states nothing as a fact shares the
        /// withdrawal of the clause after it: "Spanisch zu lernen, davon träume ich" gives no Spanish either.
        ///
        /// A negation or a hedge that governs a word of level bears on the level alone: "I am not an expert in Swift" and "I have
        /// never been fluent in German" claim Swift and German, and the level, which they deny, is not stated
        /// (`DescriptionText.levels`). A negation of the verb withdraws the claim, though a word of level follows: "I cannot speak
        /// German even at a basic level", "I don't speak French fluently".
        func claims(at place: Place) -> Bool {
            let clause = clauses.clause(at: place)
            guard speaks(at: place), !withdraws(clause) else { return false }
            let supposed = (0..<place.clause).contains { index in
                let opening = clauses.clause(at: Place(sentence: place.sentence, clause: index)).words.first
                return opening.map { Vocabulary.isCondition($0.folded, in: language) } ?? false
            }
            guard !supposed, !(statesNothing(at: place) && isWithdrawnAhead(of: place)) else { return false }
            if clause.isAnchored { return true }

            let statement = Statement(clause: clause, quotes: all, language: language)
            guard statement.startsWithItsVerb || !statement.hasVerbs || !statement.isFactual else { return true }
            return claims(at: Place(sentence: place.sentence, clause: place.clause - 1))
        }

        /// Whether the clause at `place` states nothing as a fact, and takes no fact from a clause before it: it has no verb, or none
        /// that is factual ("Spanisch zu lernen", "Spanish"), and it starts its sentence or a semicolon, or a comma or a conjunction
        /// split it off from a clause that states nothing either. A fragment of a fact ("I speak Italian, English") states its fact.
        private func statesNothing(at place: Place) -> Bool {
            let clause = clauses.clause(at: place)
            let statement = Statement(clause: clause, quotes: all, language: language)
            guard !statement.hasVerbs || !statement.isFactual else { return false }
            return clause.isAnchored || statesNothing(at: Place(sentence: place.sentence, clause: place.clause - 1))
        }

        /// Whether a clause after `place` in its sentence, split off by a comma or a conjunction, withdraws the claim, directly or through
        /// clauses that state nothing as a fact: "Spanisch zu lernen, davon träume ich", "Python, Java and Swift, which I have never
        /// used".
        private func isWithdrawnAhead(of place: Place) -> Bool {
            let next = Place(sentence: place.sentence, clause: place.clause + 1)
            guard next.clause < clauses.sentences[place.sentence].count else { return false }
            let clause = clauses.clause(at: next)
            guard !clause.isAnchored else { return false }
            return withdraws(clause) || (statesNothing(at: next) && isWithdrawnAhead(of: next))
        }

        /// Whether the clause withdraws its claim: some word of it does, and not only negations or hedges (`StatementWords.hedges`)
        /// that each govern a word of level, which deny the level alone.
        private func withdraws(_ clause: Clause) -> Bool {
            let withdrawals = Vocabulary.withdrawals(in: clause.words, language: language)
            guard !withdrawals.isEmpty else { return false }
            guard withdrawals.allSatisfy({ $0 == "n't" || StatementWords.hedges.contains($0) }) else { return true }
            let negations = clause.words.indices.filter { isANegation(at: $0, in: clause.words) }
            return negations.isEmpty || !negations.allSatisfy { governsALevel(from: $0, in: clause.words) }
        }

        /// Whether the word at `index` is a negation or a hedge: one of `StatementWords.hedges`, or the "t" of "n't".
        private func isANegation(at index: Int, in words: [Word]) -> Bool {
            let word = words[index].folded
            if word == "t" {
                return index > 0 && Vocabulary.modality(in: Array(words[(index - 1)...index]), language: language).contains("n't")
            }
            return StatementWords.hedges.contains(word) && !Vocabulary.isOwnWord(word, in: language)
        }

        /// Whether the negation at `index` governs a high level (`LevelHeight`): only the forms of "to be", indefinite articles and
        /// other negations stand between them ("not an expert", "never been fluent", "non sono esperto", "kein Experte", "ne suis pas
        /// expert"). Denying a high level implies some knowledge; denying a low one ("no basic knowledge", "keine Grundkenntnisse")
        /// implies none. A verb or an item between them makes it a negation of the ability: "cannot speak German even at a basic
        /// level".
        private func governsALevel(from index: Int, in words: [Word]) -> Bool {
            let folded = words.map(\.folded)
            for next in words.indices.dropFirst(index + 1) {
                let word = words[next]
                if let height = LevelHeight.ofPhrase(at: next, in: folded) { return height == .high }
                let links = Vocabulary.isBeForm(word.accented, in: language) || EntryWording.isIndefiniteArticle(word.folded, in: language)
                    || isANegation(at: next, in: words)
                guard links else { return false }
            }
            return false
        }

        /// Whether the clause at `place` gives the person's contacts (ADR 0023, rule (b)): it stands before the references, speaks for
        /// the person, names no other person, and has one of the three shapes of a contact.
        /// - A verbless clause, read as a label: its words name a contact or a field, or are function words, numbers or the person's own
        ///   quotes ("Email: me@example.com", "Maria Rossi, +39 ..."). Any other word may be a verb the device does not tag, or a name.
        ///   A label that a comma or a conjunction split off belongs to the clause before it ("..., or on +39 ..."); one that stands on
        ///   its own needs what comes before it to be the person's (`leansOnThePerson`).
        /// - The person's possession of a contact field, a verb of contacting whose object is the person, or the person as reachable
        ///   (`Statement.offersAContact`),
        ///   with nothing else beside them but contact and field words, numbers, function words and the person's own quotes: "Puoi
        ///   contattarmi tramite Anna a ..." gives no contact (see `Voice.standsBesideAContact`).
        func givesContacts(at place: Place) -> Bool {
            let clause = clauses.clause(at: place)
            let statement = Statement(clause: clause, quotes: all, language: language)
            guard !isInTheReferences(place.sentence), speaks(at: place), !statement.namesAnotherPerson else { return false }
            guard isMade(of: clause, by: Voice.standsInALabel) else {
                return statement.offersAContact && isMade(of: clause, by: Voice.standsBesideAContact)
            }
            guard clause.isAnchored else { return givesContacts(at: Place(sentence: place.sentence, clause: place.clause - 1)) }
            return leansOnThePerson(before: place)
        }

        /// Whether an address that stands alone in sentence `sentence`, with no words, is the person's: as a verbless contact, it is
        /// before the references, and what comes before it names no other person.
        func givesAnAddressAlone(inSentence sentence: Int) -> Bool {
            !isInTheReferences(sentence) && leansOnThePerson(before: Place(sentence: sentence, clause: 0))
        }

        /// Whether the sentence at `sentence` is in the references (ADR 0023, rule (b)): it, or a sentence before it, holds a reference
        /// word. A pasted CV puts its references' names and addresses on separate lines, where a clause alone cannot tell whose they are.
        private func isInTheReferences(_ sentence: Int) -> Bool {
            clauses.sentences.prefix(sentence + 1).contains { $0.contains { Voice.holdsAReference($0.words) } }
        }

        /// Whether what the verbless contact at `place` leans on is the person's (ADR 0023, rule (b)): the clauses before it in its
        /// sentence and those of the last sentence before it that has words, each of which speaks for the person and names no other
        /// person. A verbless clause among them that stands alone is explained (see `Voice.explainsBeforeAContact`, and the person's
        /// own quotes), and a fragment of a clause with a verb capitalises only quotes (`capitalisesOnlyQuotes`). "Anna is a nurse.
        /// Email: anna@example.com" gives no email, nor does "Anna Verdi. Email: ...", a bare name, nor "I'm Maria Rossi, a friend of
        /// Anna Verdi. Email: ...", nor "My sister is a nurse. Email: ...", a loss; "I'm Anna Verdi, a nurse in Turin. Email: ..."
        /// keeps its contacts.
        private func leansOnThePerson(before place: Place) -> Bool {
            var places = (0..<place.clause).map { Place(sentence: place.sentence, clause: $0) }
            if let previous = clauses.sentences.indices.prefix(place.sentence).last(where: { !clauses.sentences[$0].isEmpty }) {
                places += clauses.sentences[previous].indices.map { Place(sentence: previous, clause: $0) }
            }
            return places.allSatisfy { other in
                let clause = clauses.clause(at: other)
                let statement = Statement(clause: clause, quotes: all, language: language)
                guard speaks(at: other), !statement.namesAnotherPerson else { return false }
                if statement.hasVerbs { return true }
                return isAFragment(other) ? capitalisesOnlyQuotes(clause) : isMade(of: clause, by: Voice.explainsBeforeAContact)
            }
        }

        /// Whether the verbless clause at `place` is a fragment of a clause with a verb before it in its sentence: a comma or a
        /// conjunction split it off, as it did every verbless clause between them, and it belongs to that clause (ADR 0023, (c)). A
        /// verbless clause that no clause with a verb precedes stands alone.
        private func isAFragment(_ place: Place) -> Bool {
            var index = place.clause
            while index > 0, !clauses.clause(at: Place(sentence: place.sentence, clause: index)).isAnchored {
                index -= 1
                if Statement(clause: clauses.clause(at: Place(sentence: place.sentence, clause: index)), quotes: all, language: language).hasVerbs {
                    return true
                }
            }
            return false
        }

        /// Whether every capitalised word of a fragment is a quote of the draft that the description backs (the person's name, place or
        /// title, an employer, a school) or a contact or field word (ADR 0023, rule (b)): another capitalised word names someone else
        /// ("a friend of Anna Verdi"). A fragment never holds the first word of its sentence.
        private func capitalisesOnlyQuotes(_ clause: Clause) -> Bool {
            let quoted = clause.positions(inside: all)
            return clause.words.indices.allSatisfy { index in
                !clause.isCapitalised(index) || quoted.contains(index) || Voice.standsInALabel(clause.words[index], in: language)
            }
        }

        /// Whether every word of the clause is one of the person's own quotes, or one that `stands` lets stand.
        private func isMade(of clause: Clause, by stands: (Word, Vocabulary.Language?) -> Bool) -> Bool {
            let own = clause.positions(inside: ofPerson)
            return clause.words.indices.allSatisfy { own.contains($0) || stands(clause.words[$0], language) }
        }

        /// Whether the clause before `place` in its sentence is factual: it holds no word of negation, doubt, wish, future or
        /// condition, and, unless a comma or a conjunction split it off and it has no verb, every verb of it is factual and every word
        /// that leads in is explained (the quotes of the draft explain themselves). A verbless clause that was split off is factual if
        /// the clause before it is, and so on up to a clause with a verb or one that stands on its own.
        private func isFactual(before place: Place) -> Bool {
            let previous = Place(sentence: place.sentence, clause: place.clause - 1)
            let clause = clauses.clause(at: previous)
            let statement = Statement(clause: clause, quotes: all, own: all, language: language)

            guard Vocabulary.modality(in: clause.words, language: language).isEmpty else { return false }
            if !statement.hasVerbs && !clause.isAnchored { return isFactual(before: previous) }
            return statement.isFactual
        }
    }

    /// What the description lets the draft say about the entry at `index`.
    func evidence(of index: Int) -> EntryEvidence {
        let subject = subjects[index]
        let joining = joiningPlaces(of: index)
        let pure = joining.filter { clauses.clause(at: $0).words.allSatisfy(explainer.isTimePhrase) }
        let graduating = subject.isEducation ? joining.filter { !pure.contains($0) && explainer.isGraduationPhrase(clauses.clause(at: $0).words) } : []
        let dated = (backing[index].union(pure)).sorted(by: Self.isBefore).map { stated($0, of: index) }
        let graduation = graduating.sorted(by: Self.isBefore).map(clauses.clause(at:))
        let joined = joining.filter { !pure.contains($0) && !graduating.contains($0) }.sorted(by: Self.isBefore)

        return EntryEvidence(
            backing: backing[index].sorted(by: Self.isBefore).map { stated($0, of: index) },
            dated: dated,
            graduation: graduation,
            statesCurrent: statesCurrent(index, joining: joining),
            quotable: ProseQuotes(sources: (dated + graduation).map { ProseQuotes.Source($0) }, language: explainer.language),
            quotableByAchievements: ProseQuotes(sources: joined.map { ProseQuotes.Source(clauses.clause(at: $0)) }, language: explainer.language),
            verbAchievements: Set(subject.achievements.indices.filter { isQuoteOfAVerb(subject.achievements[$0], of: subject) })
        )
    }

    /// What a summary may quote: every clause of the description that speaks for the person, to its end or to where its purpose tail
    /// starts.
    var summaryQuotes: ProseQuotes {
        let sources = clauses.places.filter { reading.speaks(at: $0) }.map { place -> ProseQuotes.Source in
            let clause = clauses.clause(at: place)
            let tail = Statement(clause: clause, quotes: reading.all, name: 0, language: explainer.language).factualWords
            return ProseQuotes.Source(clause, ends: tail < clause.words.count ? [tail, clause.words.count] : nil)
        }
        return ProseQuotes(sources: sources, language: explainer.language)
    }

    /// Whether the clause at `place` claims a skill, an interest or a language for the person: the clauses that `claimedSentences`
    /// keeps.
    func claims(at place: DescriptionClauses.Place) -> Bool {
        reading.claims(at: place)
    }

    /// The description as the person claims skills, interests and languages in it: its sentences, with every clause that does not
    /// speak for the person, or that denies, wishes or supposes, left out.
    var claimedSentences: [String] {
        clauses.sentences(keeping: reading.claims(at:))
    }

    /// The description as the person speaks it: its sentences, with every clause that does not speak for the person left out.
    var spokenSentences: [String] {
        clauses.sentences(keeping: reading.speaks(at:))
    }

    /// The description as it gives the person's contacts: its sentences, with every clause that does not speak for the person, or that
    /// names another person, left out.
    var contactSentences: [String] {
        clauses.sentences(keeping: reading.givesContacts(at:), keepsAnAddress: reading.givesAnAddressAlone(inSentence:))
    }

    /// Whether the description gives `title` (a title, or a degree) for the entry at `index`: in a clause that speaks for the person
    /// and names the entry, or in one that names no other entry and holds nothing but explained words, the person's own quotes among
    /// them. A title that the description gives only in the clause of another entry ("head nurse at Beta"), or in one about someone
    /// else ("my sister is a nurse at Acme"), is not this entry's.
    func supportsTitle(_ title: [String], of index: Int, person: [[String]]) -> Bool {
        let subject = subjects[index]

        return clauses.places.contains { place in
            guard reading.speaks(at: place) else { return false }
            let clause = facts(at: place, naming: subject.names, by: subject)
            guard clause.contains(title) else { return false }
            if !subject.isFoundByItsTitle && naming[index].contains(place) { return true }
            guard !namesAnotherEntry(at: place, than: subject) else { return false }
            if subject.isFoundByItsTitle { return true }

            let covered = clause.positions(inside: subject.quotes + person)
            return clause.words.indices.allSatisfy { covered.contains($0) || explainer.explains(clause.words[$0]) }
        }
    }

    private func namesAnotherEntry(at place: Place, than subject: Subject) -> Bool {
        subjects.indices.contains { subjects[$0].names != subject.names && naming[$0].contains(place) }
    }

    // MARK: - Clauses that back

    private static func namingPlaces(of names: [[String]], among quotes: [[String]], in clauses: DescriptionClauses) -> Set<Place> {
        guard !names.isEmpty else { return [] }

        return Set(clauses.places.filter { place in
            names.allSatisfy { !clauses.clause(at: place).standaloneSpans(of: $0, amongQuotes: quotes).isEmpty }
        })
    }

    private static func backingClauses(of subject: Subject, naming: Set<Place>, reading: Reading, explainer: Explainer) -> [Place: Clause] {
        guard !(subject.isFoundByItsTitle && naming.count > 1) else { return [:] }

        var backing: [Place: Clause] = [:]
        for place in naming {
            let clause = reading.clauses.clause(at: place)
            guard let statement = reading.statement(at: place, naming: subject.names, by: subject), statement.isFactual else { continue }

            let own = clause.positions(inside: subject.quotes + reading.ofPerson)
            let isExplained = clause.words.indices.prefix(statement.factualWords).allSatisfy { own.contains($0) || explainer.explains(clause.words[$0]) }
            let tail = Array(clause.words.dropFirst(statement.factualWords))
            if isExplained, Vocabulary.modality(in: tail, language: explainer.language).isEmpty {
                backing[place] = clause.truncated(to: statement.factualWords)
            }
        }
        return backing
    }

    /// The clause at `place` as far as it gives facts when it names the entry by `phrases`: up to a purpose or a detail after the
    /// statement. A clause that does not name it is whole.
    private func facts(at place: Place, naming phrases: [[String]], by subject: Subject) -> Clause {
        let clause = clauses.clause(at: place)
        let statement = reading.statement(at: place, naming: phrases, by: subject)
        return clause.truncated(to: statement?.factualWords ?? clause.words.count)
    }

    /// The clause at `place` as it states what it backs: cut where a purpose or a detail begins, when some entry is backed by it.
    private func stated(_ place: Place, of index: Int? = nil) -> Clause {
        let entries = index.map { [$0] } ?? Array(backingFacts.indices)
        return entries.lazy.compactMap { backingFacts[$0][place] }.first ?? clauses.clause(at: place)
    }

    // MARK: - Clauses that join

    private func joiningPlaces(of index: Int) -> [Place] {
        let subject = subjects[index]
        let everyBacking = backing.reduce(into: Set<Place>()) { $0.formUnion($1) }

        return clauses.places.filter { place in
            guard !everyBacking.contains(place) else { return false }

            let around = clauses.neighbours(of: place)
            let own = around.filter { backing[index].contains($0) }
            let others = around.filter { !backing[index].contains($0) }
            guard !own.isEmpty, others.allSatisfy({ !everyBacking.contains($0) }) else { return false }

            return ([place] + others).allSatisfy { isExplainedWhenJoining(clauses.clause(at: $0), by: subject) } && isStatedByThePerson(place)
        }
    }

    /// Whether the clause speaks for the person and every verb of it is factual (`Statement`): a clause of a purpose ("to support 3
    /// teams") gives nothing, nor one about someone else. It stands next to a clause that backs the entry, and that clause speaks.
    private func isStatedByThePerson(_ place: Place) -> Bool {
        Statement(clause: clauses.clause(at: place), quotes: reading.all, language: explainer.language).isFactual
    }

    private func isExplainedWhenJoining(_ clause: Clause, by subject: Subject) -> Bool {
        let quoted = clause.positions(inside: subject.achievements.filter { isQuoteOfAVerb($0, of: subject) })
        return clause.words.indices.allSatisfy { quoted.contains($0) || explainer.explains(clause.words[$0]) }
    }

    /// An achievement explains a clause only if it begins with a verb of a CV ("trained", "ho formato", "formé") and holds no
    /// preposition that introduces an employer, read in the language of the description: "Beta employed me" and "at Beta in 2019 I
    /// worked" explain nothing, while "j'ai formé" holds no Italian "ai". A graduation phrase explains nothing of a job.
    private func isQuoteOfAVerb(_ words: [String], of subject: Subject) -> Bool {
        guard !words.contains(where: { Vocabulary.isEmployerPreposition($0, in: explainer.language) }),
              subject.isEducation || !explainer.isGraduationPhrase(folded: words),
              let first = words.first(where: { !Vocabulary.leading.contains($0) }) else { return false }
        return explainer.isVerb(first)
    }

    // MARK: - Now

    /// Whether a clause that backs the entry, with the clauses of nothing but time next to it, says that it goes on. A year counts
    /// for "since" only if it stands in a clause that backs an entry or joins this one: a promise ("and I will stay until 2030") backs
    /// nothing, so its year is nobody's.
    private func statesCurrent(_ index: Int, joining: [Place]) -> Bool {
        let counted = backing.reduce(into: Set(joining)) { $0.formUnion($1) }

        return backing[index].contains { place in
            let neighbours = clauses.neighbours(of: place).filter { joining.contains($0) && clauses.clause(at: $0).words.allSatisfy(explainer.isTimePhrase) }
            let texts = (neighbours + [place]).sorted(by: Self.isBefore).map { stated($0).text }
            let years = Set(clauses.places.filter { $0.sentence == place.sentence && counted.contains($0) }
                .flatMap { stated($0).words }.filter { $0.isNumber && $0.folded.count == 4 }.map(\.folded))
            return PresentStatement.holds(in: texts.joined(separator: " "), sentenceYears: years.count, language: explainer.language)
        }
    }

    /// Whether some clause of the description names the entry, holds no word of negation, doubt or degree, wish or intention, future
    /// or condition, and says it as a fact (`Statement`): a mention of work that is done. An entry the description only denies, hopes
    /// for, promises or plans has none.
    func hasFactualMention(_ index: Int) -> Bool {
        mentioning[index].contains { place in
            let clause = clauses.clause(at: place)
            guard Vocabulary.modality(in: clause.words, language: explainer.language).isEmpty else { return false }
            return reading.statement(at: place, naming: subjects[index].mentions, by: subjects[index])?.isFactual == true
        }
    }

    private static func isBefore(_ first: Place, _ second: Place) -> Bool {
        (first.sentence, first.clause) < (second.sentence, second.clause)
    }
}
