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
    /// The names of the employers and schools of the draft.
    private let holders: [[String]]
    /// The clauses of the description that belong to each job (ADR 0031): read once, after the entries.
    private(set) var attribution = Attribution()

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
        holders = subjects.compactMap(\.holder)
        attribution = attributing()
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

        /// The positions of the words of the clause at `place` that claim a skill, an interest, a language, or the person's title or
        /// place (#202): none when the clause claims nothing (`claims(at:)`); otherwise every word before a relative that brings in
        /// another subject ("I work with a colleague who speaks French", see `RelativeClauses`), but for the words inside quotation
        /// marks (`QuotedSpeech`), which are someone else's, or only quoted.
        func claimedWords(at place: Place) -> Set<Int> {
            guard claims(at: place) else { return [] }
            let clause = clauses.clause(at: place)
            let end = RelativeClauses.start(in: clause, language: language) ?? clause.words.count
            return Set(0..<end).subtracting(clauses.quotedWords(at: place))
        }

        /// Whether the clause at `place` claims a skill, an interest or a language for the person (#202): it speaks for the person,
        /// holds no word that withdraws a claim (`Vocabulary.withdrawals`: "never", "would", "if", but not "can" or "partly"), asks
        /// nothing (its sentence ends with a question mark), stands on no line that another person's line introduces ("My
        /// colleague wrote:"), follows no clause of its sentence that opens with a word of condition ("If I had time, I would play
        /// chess"), and, when it depends on the clause before it (a clause split off by a comma or a conjunction that has no verb,
        /// starts with its verb, or says nothing as a fact, such as "Spanisch zu lernen"), that clause claims to its last word:
        /// "I have never used Java or Swift" claims neither, "Ich träume davon, Spanisch zu lernen" no Spanish, and "a colleague who
        /// speaks French and German" no German. A clause that states nothing as a fact shares the withdrawal of the clause after it:
        /// "Spanisch zu lernen, davon träume ich" gives no Spanish either.
        ///
        /// A negation or a hedge that governs a word of level bears on the level alone: "I am not an expert in Swift" and "I have
        /// never been fluent in German" claim Swift and German, and the level, which they deny, is not stated
        /// (`DescriptionText.levels`). A negation of the verb withdraws the claim, though a word of level follows: "I cannot speak
        /// German even at a basic level", "I don't speak French fluently".
        private func claims(at place: Place) -> Bool {
            let clause = clauses.clause(at: place)
            guard speaks(at: place), !withdraws(clause), !asks(at: place), !isIntroduced(place.sentence) else { return false }
            let supposed = (0..<place.clause).contains { index in
                let opening = clauses.clause(at: Place(sentence: place.sentence, clause: index)).words.first
                return opening.map { Vocabulary.isCondition($0.folded, in: language) } ?? false
            }
            guard !supposed, !(statesNothing(at: place) && isWithdrawnAhead(of: place)) else { return false }
            if clause.isAnchored { return true }

            let statement = Statement(clause: clause, quotes: all, language: language)
            guard statement.startsWithItsVerb || !statement.hasVerbs || !statement.isFactual else { return true }
            let previous = Place(sentence: place.sentence, clause: place.clause - 1)
            return claimedWords(at: previous).contains(clauses.clause(at: previous).words.count - 1)
        }

        /// Whether the clause at `place` asks rather than claims: its sentence ends with a question mark ("Do I speak French?",
        /// "Parlo francese e tedesco, giusto?"). A question mark inside a sentence ends no clause.
        private func asks(at place: Place) -> Bool {
            clauses.sentences[place.sentence].last?.endsAQuestion == true
        }

        /// Whether the sentence at `sentence` stands on the line right after a line that ends with a colon and that does not speak for
        /// the person ("My colleague wrote:", "Il mio collega ha scritto:"): it gives another person's words, all its sentences. A line
        /// the person speaks introduces the person's own ("My languages:", "Skills:", "I worked with my team on:").
        private func isIntroduced(_ sentence: Int) -> Bool {
            guard let line = clauses.lineStart(of: sentence), line > 0 else { return false }
            let before = clauses.sentences[line - 1]
            guard before.last?.endsWithAColon == true else { return false }
            return before.indices.contains { !speaks(at: Place(sentence: line - 1, clause: $0)) }
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
        // The clauses attributed to the job by continuation give the second pass context, never a date or a quote:
        // the contract keeps a year of a joined clause from the job ("and graduated in 2012", "and trained 3 teachers in 2018").
        let attributed = subject.isEducation ? [] : attributedContinuations(of: index)
        let found = (backing[index].union(pure)).sorted(by: Self.isBefore).map { stated($0, of: index) }
        // ADR 0031, D1: a year in a relative clause that only continues the sentence naming the job counts for its dates.
        let continuedDated = subject.isEducation ? [] : relativeContinuations(of: index).map(clauses.clause(at:))
        // A year written with a word of graduating or completing ("2016 ... abgeschlossen") is the year the study ended, whichever
        // clause writes it: it is never the start. So for a study such a clause is a graduation clause, not a dated one.
        let completes = found.map { subject.isEducation && $0.words.contains(where: explainer.saysGraduating) }
        let dated = found.indices.filter { !completes[$0] }.map { found[$0] }
        let graduation = graduating.sorted(by: Self.isBefore).map(clauses.clause(at:)) + found.indices.filter { completes[$0] }.map { found[$0] }
        let joined = joining.filter { !pure.contains($0) && !graduating.contains($0) }.sorted(by: Self.isBefore)

        return EntryEvidence(
            backing: backing[index].sorted(by: Self.isBefore).map { stated($0, of: index) },
            dated: dated,
            graduation: graduation,
            statesCurrent: statesCurrent(index, joining: joining),
            quotable: ProseQuotes(sources: (dated + graduation).map { ProseQuotes.Source($0) }, language: explainer.language),
            quotableByAchievements: ProseQuotes(sources: joined.map { ProseQuotes.Source(clauses.clause(at: $0)) }, language: explainer.language),
            verbAchievements: Set(subject.achievements.indices.filter { isQuoteOfAVerb(subject.achievements[$0], of: subject) }),
            holders: holders,
            ownHolder: subject.holder,
            context: backing[index].union(mentioning[index]).union(joining).union(attributed).sorted(by: Self.isBefore).map {
                Self.withoutTrailingConjunction(clauses.clause(at: $0).source.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)))
            },
            quotableByAttribution: subject.isEducation ? nil : ownAttributedQuotes(of: index),
            continuedDated: continuedDated,
            ownClauseQuotes: subject.isEducation ? nil : ownClauseQuotes(of: index)
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

    /// The positions of the words of the clause at `place` that claim a skill, an interest or a language for the person: the words
    /// that `claimedSentences` keeps.
    func claimedWords(at place: DescriptionClauses.Place) -> Set<Int> {
        reading.claimedWords(at: place)
    }

    /// The description as the person claims skills, interests and languages in it: its sentences, with every clause that does not
    /// speak for the person, or that denies, wishes, supposes or asks, left out, and every word of another subject or inside
    /// quotation marks.
    var claimedSentences: [String] {
        clauses.sentences(keepingWords: reading.claimedWords(at:))
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
    /// else ("my sister is a nurse at Acme"), is not this entry's, nor is a word of the name of an employer or a school
    /// ("contabile" in "Studio Contabile Merlini"), nor the whole of the entry's own ("contabile" for a job at "Contabile", unless the
    /// clause writes it once more): it stands as the title only outside those names. A clause of no entry says
    /// what the person is now ("I am a nurse in Leeds"): for a job that the description says is over it states no title, so the
    /// title stands there only if the clause of the job gives it. A degree persists.
    func supportsTitle(_ title: [String], of index: Int, person: [[String]]) -> Bool {
        let subject = subjects[index]

        return clauses.places.contains { place in
            guard reading.speaks(at: place) else { return false }
            let clause = facts(at: place, naming: subject.names, by: subject)
            let spans = clause.spans(of: title, besideNames: holders, ownName: subject.holder)
            guard !spans.isEmpty else { return false }
            guard !subject.isEducation || spans.contains(where: { !isOnlyVerbs($0, in: clause) }) else { return false }
            if !subject.isFoundByItsTitle && naming[index].contains(place) { return true }
            guard !namesAnotherEntry(at: place, than: subject) else { return false }
            if subject.isFoundByItsTitle { return true }

            let covered = clause.positions(inside: subject.quotes + person)
            guard clause.words.indices.allSatisfy({ covered.contains($0) || explainer.explains(clause.words[$0]) }) else { return false }
            return subject.isEducation || !hasEnded(index)
        }
    }

    /// Whether the words of `span` in `clause`, the standalone occurrence of a degree, are nothing but finite verbs and function words
    /// as the clause reads them ("terminé" in "estudié en la escuela y terminé en 2017"): what the person did names no qualification.
    /// A verb beside a noun ("Titulado en Magisterio") and a word the vocabulary lists as a verb but the clause uses as a noun
    /// ("o curso", "eine Lehre") are no such span. The other quotes of the draft are names, so no verbs; the span's own words are read.
    private func isOnlyVerbs(_ span: Range<Int>, in clause: Clause) -> Bool {
        let quoted = clause.positions(inside: reading.all).subtracting(span)
        let verbs = Statement.finiteVerbs(in: clause.words, quoted: quoted, language: explainer.language)
        return span.contains(where: verbs.contains)
            && span.allSatisfy { verbs.contains($0) || Vocabulary.isNeutral(clause.words[$0].folded, in: explainer.language) }
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
        statesCurrent(periods(of: backing[index], joining: joining), counting: Set(joining))
    }

    /// Whether one of `periods` says that its entry goes on, its years counted in the clauses that back an entry and in `counted`.
    private func statesCurrent(_ periods: [(place: Place, text: String)], counting counted: Set<Place>) -> Bool {
        let counted = backing.reduce(into: counted) { $0.formUnion($1) }

        return periods.contains { period in
            let years = Set(clauses.places.filter { $0.sentence == period.place.sentence && counted.contains($0) }
                .flatMap { stated($0).words }.filter { $0.isNumber && $0.folded.count == 4 }.map(\.folded))
            return PresentStatement.holds(in: period.text, sentenceYears: years.count, language: explainer.language)
        }
    }

    /// Whether the description says that the job at `index` is over: no clause of it says the job goes on, and some clause of it,
    /// with the clauses of nothing but time next to it, writes two years or an end and no word for the present
    /// (`PresentStatement.ended`). Its clauses are those that back it, or, when none does, those that state it as a fact
    /// (`factualMentions`) with the clauses of nothing but time next to them that back no entry: "Antes, de 2015 a 2019, trabalhei
    /// na agência Pixel Gaúcho" says the job at Pixel is over although "agência" leaves its clause unexplained (#354). A job no
    /// clause states as a fact, one without dates in the past tense, and one that ends "até 2018" (the word is also "even") are not
    /// found over, and keep what they keep.
    private func hasEnded(_ index: Int) -> Bool {
        let isBacked = !backing[index].isEmpty
        let places = isBacked ? backing[index] : factualMentions(of: index)
        let joining = isBacked ? joiningPlaces(of: index) : timePlaces(beside: places)
        let found = periods(of: places, joining: joining)
        return !statesCurrent(found, counting: places.union(joining)) && found.contains { PresentStatement.ended(in: $0.text) }
    }

    /// The clauses next to `places` that hold nothing but time words and back no entry.
    private func timePlaces(beside places: Set<Place>) -> [Place] {
        let everyBacking = backing.reduce(into: Set<Place>()) { $0.formUnion($1) }
        return places.flatMap(clauses.neighbours(of:)).filter { place in
            !everyBacking.contains(place) && clauses.clause(at: place).words.allSatisfy(explainer.isTimePhrase)
        }
    }

    /// The time each of `places` gives: the clause as it states the entry, with the clauses of nothing but time of `joining` next to
    /// it.
    private func periods(of places: Set<Place>, joining: [Place]) -> [(place: Place, text: String)] {
        places.sorted(by: Self.isBefore).map { place in
            let neighbours = clauses.neighbours(of: place).filter { joining.contains($0) && clauses.clause(at: $0).words.allSatisfy(explainer.isTimePhrase) }
            let texts = (neighbours + [place]).sorted(by: Self.isBefore).map { stated($0).text }
            return (place, texts.joined(separator: " "))
        }
    }

    /// Whether some clause of the description names the entry, holds no word of negation, doubt or degree, wish or intention, future
    /// or condition, and says it as a fact (`Statement`): a mention of work that is done. An entry the description only denies, hopes
    /// for, promises or plans has none.
    func hasFactualMention(_ index: Int) -> Bool {
        !factualMentions(of: index).isEmpty
    }

    /// The clauses that state the entry as a fact (`hasFactualMention`).
    private func factualMentions(of index: Int) -> Set<Place> {
        mentioning[index].filter { place in
            let clause = clauses.clause(at: place)
            guard Vocabulary.modality(in: clause.words, language: explainer.language).isEmpty else { return false }
            return reading.statement(at: place, naming: subjects[index].mentions, by: subjects[index])?.isFactual == true
        }
    }

    private static func isBefore(_ first: Place, _ second: Place) -> Bool {
        (first.sentence, first.clause) < (second.sentence, second.clause)
    }
}

// MARK: - The clauses of each job (ADR 0031)

extension Grounding {
    /// The clauses that belong to the jobs by rules (a)-(c): (a) a clause names the job's employer; (b) a clause that
    /// names no employer and continues the clause that names one, in the same sentence ("where...", a gerund, a verb that opens it);
    /// (c) the shared tail of a sentence that names several employers in a row. A clause that claims nothing is never attributed.
    struct Attribution {
        /// The jobs each attributed clause belongs to.
        var jobsOf: [DescriptionClauses.Place: [Int]] = [:]
        /// The clauses attributed by rule (b) or (c).
        var continuations: Set<DescriptionClauses.Place> = []
        /// The clauses attributed by rule (a).
        var naming: Set<DescriptionClauses.Place> = []
        /// A job named in a verbless clause coordinated after another job's naming clause: that job, the head of the sentence.
        var head: [Int: Int] = [:]
    }

    /// The jobs among the subjects: those with an employer.
    var jobSubjects: [Int] {
        subjects.indices.filter { subjects[$0].holder != nil && !subjects[$0].isEducation }
    }

    private static let relativeWords: Set<String> = ["where", "wherein", "dove", "ove", "wo", "wobei", "où", "donde", "onde"]

    private func attributing() -> Attribution {
        let jobs = jobSubjects
        var result = Attribution()
        let language = explainer.language
        let bySentence = Dictionary(grouping: clauses.places, by: \.sentence)
        for sentence in bySentence.keys.sorted() {
            var chain: [Int] = []
            var last: [Int]?
            var previousNaming = false
            var chainHead: Int?
            for place in bySentence[sentence, default: []].sorted(by: { $0.clause < $1.clause }) {
                let clause = clauses.clause(at: place)
                let statement = Statement(clause: clause, quotes: reading.all, language: language)
                let named = jobs.filter { mentioning[$0].contains(place) }
                var allowed: [Int] = []
                var isContinuation = false
                var coordinated: [Int] = []
                if !named.isEmpty {
                    if !clause.isAnchored && !statement.hasVerbs && previousNaming, last != nil {
                        chain = Array(Set(chain).union(named)).sorted()
                        coordinated = named
                    } else {
                        chain = named
                        chainHead = named.count == 1 ? named[0] : nil
                    }
                    last = named
                    allowed = named
                    previousNaming = true
                } else if let lastJobs = last, Self.continues(clause, statement, language) {
                    allowed = chain.count > 1 ? chain : lastJobs
                    isContinuation = true
                    previousNaming = false
                } else {
                    chain = []
                    last = nil
                    previousNaming = false
                    chainHead = nil
                }
                guard !allowed.isEmpty, !reading.claimedWords(at: place).isEmpty else { continue }
                result.jobsOf[place] = allowed
                if isContinuation { result.continuations.insert(place) } else { result.naming.insert(place) }
                if let chainHead { for job in coordinated where job != chainHead { result.head[job] = chainHead } }
            }
        }
        return result
    }

    private static func continues(_ clause: Clause, _ statement: Statement, _ language: Vocabulary.Language?) -> Bool {
        guard !clause.isAnchored, let first = clause.words.first else { return false }
        if relativeWords.contains(first.accented) || isGerund(clause.words, language) { return true }
        return statement.startsWithItsVerb
    }

    private static func isGerund(_ words: [Word], _ language: Vocabulary.Language?) -> Bool {
        guard let first = words.first?.folded else { return false }
        switch language {
        case .english: return first.count > 4 && first.hasSuffix("ing")
        case .italian: return first.hasSuffix("ando") || first.hasSuffix("endo")
        case .spanish: return first.hasSuffix("ando") || first.hasSuffix("iendo") || first.hasSuffix("yendo")
        case .portuguese: return first.hasSuffix("ando") || first.hasSuffix("endo") || first.hasSuffix("indo")
        case .french: return first == "en" && words.count > 1 && words[1].folded.hasSuffix("ant")
        case .german: return first.hasSuffix("end")
        case nil: return false
        }
    }

    /// The clauses attributed to the job at `index` alone, by naming its employer or by a relative word.
    func ownAttributedQuotes(of index: Int) -> ProseQuotes {
        let places = attribution.jobsOf.keys.filter { place in
            guard attribution.jobsOf[place] == [index] else { return false }
            if attribution.naming.contains(place) { return true }
            guard let first = clauses.clause(at: place).words.first else { return false }
            return Self.relativeWords.contains(first.accented)
        }.sorted(by: Self.isBefore)
        return ProseQuotes(sources: places.map { ProseQuotes.Source(clauses.clause(at: $0)) }, language: explainer.language)
    }

    /// ADR 0031, D1: the clauses that only continue the sentence naming the job at `index`: a relative clause attributed to it
    /// alone ("..., where I rigged the lights until 2016"), and the continuations right after it attributed to it alone, each naming
    /// no entry and stating no wish, doubt or future. A chain that names another employer is attributed to both: it gives no year.
    func relativeContinuations(of index: Int) -> [DescriptionClauses.Place] {
        let language = explainer.language
        let own = attribution.continuations.filter { place in
            attribution.jobsOf[place] == [index]
                && !mentioning.contains { $0.contains(place) }
                && Vocabulary.modality(in: clauses.clause(at: place).words, language: language).isEmpty
        }
        var result: [DescriptionClauses.Place] = []
        for place in own.sorted(by: Self.isBefore) {
            if let first = clauses.clause(at: place).words.first, Self.relativeWords.contains(first.accented) {
                result.append(place)
            } else if let previous = result.last, previous.sentence == place.sentence, previous.clause == place.clause - 1 {
                result.append(place)
            }
        }
        return result
    }

    /// ADR 0031, D3: every clause attributed to the job at `index`, shared tails among them: what a duty may quote word for word.
    func ownClauseQuotes(of index: Int) -> ProseQuotes {
        let places = attribution.jobsOf.keys.filter { attribution.jobsOf[$0]?.contains(index) == true }.sorted(by: Self.isBefore)
        return ProseQuotes(sources: places.map { ProseQuotes.Source(clauses.clause(at: $0)) }, language: explainer.language)
    }

    /// A clause's text without the conjunction it ends with ("setting up the PA systems and").
    static func withoutTrailingConjunction(_ text: String) -> String {
        var words = text.split(separator: " ", omittingEmptySubsequences: true)
        while let last = words.last, conjunctions.contains(last.lowercased()) { words.removeLast() }
        return words.joined(separator: " ").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
    }

    /// The continuation clauses attributed to the job at `index`.
    func attributedContinuations(of index: Int) -> [DescriptionClauses.Place] {
        attribution.continuations.filter { attribution.jobsOf[$0]?.contains(index) == true }.sorted(by: Self.isBefore)
    }

    private static let conjunctions: Set<String> = ["and", "e", "ed", "und", "et", "y", "or", "o", "oder", "ou"]

    /// The duties the person said for the job at `index`, copied from the description: each continuation clause
    /// attributed to it, and each later clause that names its employer again with no year in it, cut to its duty.
    func pinnedDuties(of index: Int) -> [PinnedDuty] {
        let firstNamed = attribution.naming.filter { attribution.jobsOf[$0]?.contains(index) == true }.map(\.sentence).min()
        let places = attribution.jobsOf.keys.filter { attribution.jobsOf[$0]?.contains(index) == true }.sorted(by: Self.isBefore)
        let pieces = places.compactMap { place -> (place: Place, text: String)? in
            let clause = clauses.clause(at: place)
            let words = clause.words
            var start = 0
            if attribution.naming.contains(place) {
                guard let firstNamed, place.sentence > firstNamed, place.clause == 0, attribution.jobsOf[place]?.count == 1,
                      !words.contains(where: \.isNumber) else { return nil }
                let names = Set(subjects[index].mentions.flatMap { $0 })
                guard let end = words.lastIndex(where: { names.contains($0.folded) }) else { return nil }
                start = end + 1
            } else if !attribution.continuations.contains(place) {
                return nil
            }
            return duty(of: clause, from: start).map { (place, $0) }
        }
        // Two duties of one sentence joined by a conjunction stay one duty ("I rigged the lights and loaded the
        // trucks"), so neither is a piece without its subject.
        var joined: [(place: Place, text: String, parts: [String])] = []
        for piece in pieces {
            // The conjunction is not one of the clause's words: it ends the clause as the sentence has it.
            if let last = joined.last, last.place.sentence == piece.place.sentence, last.place.clause + 1 == piece.place.clause,
               let conjunction = clauses.clause(at: last.place).source.split(whereSeparator: \.isWhitespace).last.map(String.init),
               Self.conjunctions.contains(conjunction.lowercased()),
               let head = piece.text.first {
                let nextClause = clauses.clause(at: piece.place)
                let firstWord = String(piece.text.prefix { !$0.isWhitespace })
                let lowered = String(head).lowercased() + firstWord.dropFirst()
                let written = nextClause.written(from: 0, to: nextClause.words.count)
                let start = written.split(separator: " ").contains { $0 == lowered } ? String(head).lowercased() : String(head)
                joined[joined.count - 1] = (
                    piece.place, String(last.text.dropLast()) + " " + conjunction + " " + start + piece.text.dropFirst(), last.parts + [piece.text]
                )
            } else {
                joined.append((piece.place, piece.text, [piece.text]))
            }
        }
        return joined.map { PinnedDuty(text: $0.text, parts: $0.parts) }
    }

    /// A duty the person said, whole, and the pieces it joins (one when it joins none).
    struct PinnedDuty: Sendable, Equatable {
        let text: String
        let parts: [String]

        /// The whole duty when `accepts` keeps it, otherwise each piece it keeps.
        func kept(by accepts: (String) -> String?) -> [String] {
            if let whole = accepts(text) { return [whole] }
            return parts.count > 1 ? parts.compactMap(accepts) : []
        }
    }

    private func duty(of clause: Clause, from first: Int) -> String? {
        let words = clause.words
        let language = explainer.language
        var start = first
        var end = words.count
        while end > start, Self.conjunctions.contains(words[end - 1].folded) { end -= 1 }
        while end > start, explainer.isTimePhrase(words[end - 1]) { end -= 1 }
        var moved: String?
        if start < end, Self.relativeWords.contains(words[start].accented) {
            start += 1
            // German puts the verb last after "wo": "wo ich Anlagen installiere" is "Ich installiere Anlagen".
            if language == .german, start < end - 2, words[start].folded == "ich" {
                moved = "Ich " + clause.written(from: end - 1, to: end) + " " + clause.written(from: start + 1, to: end - 1)
            }
        }
        guard end - start >= 2 else { return nil }
        let text = moved ?? clause.written(from: start, to: end)
        guard let head = text.first else { return nil }
        return String(head).uppercased() + text.dropFirst() + "."
    }

    /// The sentences in which the person says what they do and what they are like at work, with no job (#354, round 1): "I mix on
    /// digital consoles and edit the sound effects for the shows.", "Sono preciso e mi piace lavorare in squadra." Each clause of
    /// them speaks for the person, belongs to no job, names no entry and gives no link or capitalised word of the person's name,
    /// place or title, one of them claims something, and the sentence holds no number and no word of wish, doubt, future or search
    /// ("I am now looking for a technical manager role"): the skills requests read them, which no job's request reads.
    func ownSentences() -> [String] {
        ownSentencePlaces().compactMap(text(of:))
    }

    /// The text of the clauses at `places`, whole, or nil when it is empty.
    private func text(of places: [Place]) -> String? {
        let text = places.map { clauses.clause(at: $0).source }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:")))
        return text.isEmpty ? nil : text
    }

    /// The clauses of each of the person's own sentences (`ownSentences`), in their order.
    private func ownSentencePlaces() -> [[Place]] {
        let language = explainer.language
        let personWords = Set(reading.ofPerson.flatMap { $0 })
        let bySentence = Dictionary(grouping: clauses.places, by: \.sentence)
        return bySentence.keys.sorted().compactMap { sentence -> [Place]? in
            let places = bySentence[sentence, default: []].sorted { $0.clause < $1.clause }
            let words = places.flatMap { clauses.clause(at: $0).words }
            guard !places.isEmpty, Vocabulary.modality(in: words, language: language).isEmpty,
                  !words.contains(where: { Self.searchWords.contains($0.folded) || $0.isNumber }),
                  // A clause that names the person ("Je suis Maria Rossi") or gives a link says nothing of their work.
                  places.allSatisfy({ place in
                      let clause = clauses.clause(at: place)
                      return clause.links.isEmpty && !clause.words.indices.dropFirst().contains { i in
                          personWords.contains(clause.words[i].folded) && clause.isCapitalised(i)
                      }
                  }),
                  places.contains(where: { !reading.claimedWords(at: $0).isEmpty }),
                  places.allSatisfy({ place in
                      reading.speaks(at: place) && attribution.jobsOf[place] == nil && !mentioning.contains { $0.contains(place) }
                  }) else { return nil }
            return places
        }
    }

    /// ADR 0031, D7: the person's own sentences (`ownSentences`) that say, in the present and in the first person, what they do at
    /// work (`GeneralDuty`), each a duty of the current job, word for word.
    func generalDuties() -> [PinnedDuty] {
        generalDutyPlaces().compactMap(text(of:)).map { sentence in
            let text = sentence.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            let duty = text.prefix(1).uppercased() + text.dropFirst() + "."
            return PinnedDuty(text: duty, parts: [duty])
        }
    }

    /// The clauses of the duties the person said with no job (`generalDuties`), as the current job's own quotes: the job's rule
    /// keeps them as it keeps the clauses attributed to it.
    var generalDutyQuotes: ProseQuotes {
        ProseQuotes(sources: generalDutyPlaces().flatMap { $0 }.map { ProseQuotes.Source(clauses.clause(at: $0)) }, language: explainer.language)
    }

    private func generalDutyPlaces() -> [[Place]] {
        ownSentencePlaces().filter { places in text(of: places).map { GeneralDuty.holds($0, language: explainer.language) } ?? false }
    }

    /// The words that say the person looks for something, in the six languages: what follows is no work of theirs.
    private static let searchWords: Set<String> = [
        "looking", "seeking", "searching", "cerco", "cercando", "suche", "suchen", "busco", "buscando", "procuro", "procurando",
        "cherche", "recherche",
    ]

    /// The first clause that speaks for the person, starts its sentence, names no entry and belongs to no job: what the
    /// person says their field is ("I have worked in live sound for theatres").
    func fieldClause() -> String? {
        let personWords = Set(reading.ofPerson.flatMap { $0 })
        return clauses.places.first { place in
            let clause = clauses.clause(at: place)
            return clause.isAnchored && reading.speaks(at: place) && !reading.claimedWords(at: place).isEmpty
                && attribution.jobsOf[place] == nil && !mentioning.contains { $0.contains(place) }
                && !clause.words.contains(where: \.isNumber) && clause.words.count >= 4
                // A clause that names the person ("Je suis Maria Rossi") is no field.
                && !clause.words.indices.dropFirst().contains { i in
                    personWords.contains(clause.words[i].folded) && clause.written(from: i, to: i + 1).first?.isUppercase == true
                }
        }.map { place in
            let clause = clauses.clause(at: place)
            var end = clause.words.count
            while end > 0, Self.conjunctions.contains(clause.words[end - 1].folded) { end -= 1 }
            return clause.written(from: 0, to: end)
        }
    }
}
