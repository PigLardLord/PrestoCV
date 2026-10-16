import Foundation

/// Whose voice a clause is in (ADR 0023, rule (c), "The explicit subject").
///
/// The subject is the noun phrase before the clause's first verb, past a phrase of time or place that comes first ("In Rome my sister
/// speaks"); in German, when such a phrase comes first, it is the phrase right after the verb. Only a first-person pronoun is the
/// person. A noun ("a nurse"), a name ("Alice"), a pronoun of the third person or a possession ("my sister") is someone else, even
/// when the draft quotes that very word as a title: the clause speaks for someone else.
///
/// - What is no subject: a number, a function word or a word of time, and the phrase a preposition opens, with a possessive right
///   after it ("in Rome", "dal 2016", "seit 2016", "as a nurse", "in my free time"); in German, what a possessive before the verb owns
///   is an object ("2012 meinen Abschluss gemacht"). A clause with no subject ("Worked at Acme", "Dal 2016 lavoro presso Acme") speaks
///   the way a CV writes, and, in the languages that drop the pronoun, the form of its first verb tells whether it is the person's
///   ("ho lavorato", not "ha lavorato"). English and French keep their subject: there only a pure time phrase may come before a verb
///   with no subject ("Since 2016 worked at Acme"), and anything else hides one ("In Rome Anna speaks French").
/// - A noun before a verb is a subject only when the verb can take one, and only a verb is one: a list item ("quality control",
///   "direzione lavori", "Interests: reading") is no clause with a subject (see `Statement` for the verbs).
/// - Two exceptions are the person: a possession of one of the person's own fields ("my email", "il mio inglese", "meine E-Mail":
///   a closed list of field words per language), and a clause addressed to the reader whose verb of contacting has the person as its
///   object ("You can reach me at ...", "Puoi contattarmi", "mi potete contattare": a closed list of those verbs per language). A
///   possession of a person ("my sister") is never one, nor is a third party right after the verb of contacting ("You can reach my
///   manager through me at ..."). A clause with no subject that asks the reader to contact a third party ("Contact my agent at ...",
///   "Feel free to contact my manager at ...") is someone else's too.
/// - A clause with no verb (a list, a fragment) has no explicit subject: it is someone else's when it holds a pronoun of the third
///   person, starts with a possession of a person, or, unless the person says it, holds a verb of contacting that reaches someone
///   else ("Puoi contattare il mio responsabile").
enum Voice {
    /// What the words before a verb (or after it, in German) say about the subject.
    private enum Subject {
        /// A pronoun of the first person, or a possession of one of the person's own fields.
        case person
        /// A pronoun of the third person or a possession of a person.
        case someoneElse
        /// A noun or a name, and nothing else: the subject of a verb that a noun can be the subject of ("Alice managed", "ha lavorato"),
        /// the first words of a list item otherwise ("direzione lavori").
        case noun
        /// The reader is addressed ("you").
        case reader
        /// No subject at all.
        case none
    }

    /// Where a phrase that a preposition opens stands, among the words being read.
    private enum Phrase {
        case outside
        /// The preposition was read, not yet the phrase's own words.
        case opened
        /// Inside the phrase's own words: a place, a name.
        case inside
    }

    /// Whether a clause speaks for the person.
    ///
    /// - Parameters:
    ///   - words: The words of the clause.
    ///   - verbs: The positions of its verbs.
    ///   - language: The language of the description, when it is known.
    static func speaks(words: [Word], verbs: Set<Int>, language: Vocabulary.Language?) -> Bool {
        let rules = language.flatMap { Self.words[$0] } ?? everyWord
        guard let first = verbs.min() else { return speaksWithoutAVerb(words, rules: rules, language: language) }

        let afterTheVerb = words[(first + 1)...]
        var subject = read(words[..<first], rules: rules, language: language)
        // A German clause with a phrase of time or place before its verb has its subject right after the verb.
        if language == .german, subject != .person, first > 0 {
            let next = read(subjectPhrase(after: afterTheVerb, rules: rules), rules: rules, language: language)
            if next == .person { return true }
            if subject == .none { subject = next }
        }

        switch subject {
        case .person: return true
        case .someoneElse: return false
        case .noun: return !Vocabulary.canTakeANounSubject(words[first].accented, in: language)
        case .reader: return contacted(in: words, verbs: verbs, rules: rules, language: language, isAddressed: true) == .person
        case .none:
            if Vocabulary.isBeForm(words[first].accented, in: language), hasAnotherSubject(afterTheVerb, rules: rules, language: language) { return false }
            if contacted(in: words, verbs: verbs, rules: rules, language: language, isAddressed: false) == .someoneElse { return false }
            if hidesASubject(words[..<first], language: language) { return false }
            return !Vocabulary.isOtherPerson(words[first].accented, in: language)
        }
    }

    /// Whether a clause gives the person's contact in one of the shapes of ADR 0023, rule (b): the person's possession of a contact
    /// field ("My email is me@example.com", "My portfolio is https://example.com"), a verb of contacting whose object is the person
    /// ("You can reach me at ...", "Contattami a ..."), or a form of being reachable ("I can be reached at ...", "Sono raggiungibile
    /// a ..."), whose subject the clause's speaking for the person tells (see `Grounding`). A label is the third shape (see `standsInALabel`); any other clause gives no
    /// contact, even one the person speaks ("I am at me@example.com", "I worked with the team at team@acme.com").
    ///
    /// - Parameters:
    ///   - words: The words of the clause.
    ///   - verbs: The positions of its verbs.
    ///   - language: The language of the description, when it is known.
    static func offersAContact(words: [Word], verbs: Set<Int>, language: Vocabulary.Language?) -> Bool {
        let rules = language.flatMap { Self.words[$0] } ?? everyWord
        if contacted(in: words, verbs: verbs, rules: rules, language: language, isAddressed: false) == .person { return true }
        if words.contains(where: { rules.reachable.contains($0.folded) }) { return true }

        return words.indices.contains { index in
            guard rules.possessives.contains(words[index].accented), owns(index, in: words[...], rules: rules) else { return false }
            let owned = words[..<endOfPossession(after: index, in: words, verbs: verbs)]
            return isOwn(index, in: owned, rules: rules, language: language)
                && owned[(index + 1)...].prefix { !rules.prepositions.contains($0.accented) }.contains { rules.contactFields.contains($0.folded) }
        }
    }

    /// Whether a word may stand in a label that gives the person's contact (ADR 0023, rule (b), "a verbless clause": "Email:
    /// me@example.com", "Telefono: +39 ...", "Contact details: ..."): a word that names a contact or a field of the person, a number, or a
    /// function word or a word of time that is no verb ("I am at me@example.com" is no label). A label is too short to tell its
    /// language by, so a word that names a contact in any of the six languages stands in one ("Courriel", "Sito web").
    static func standsInALabel(_ word: Word, in language: Vocabulary.Language?) -> Bool {
        let rules = language.flatMap { Self.words[$0] } ?? everyWord
        if namesAContact(word, rules: rules) { return true }
        let isAVerb = word.isTaggedVerb || Vocabulary.isVerb(word.folded, in: language) || Vocabulary.isBeForm(word.accented, in: language)
            || Vocabulary.isAuxiliary(word.accented, in: language)
        return !isAVerb && Vocabulary.isNeutral(word.folded, in: language)
    }

    /// Whether a word explains a verbless clause that a verbless contact leans on, before it in its sentence or in the sentence before
    /// it (ADR 0023, rule (b)): a word of a label, or a function word or a form of "to be" of any of the six languages, as such a
    /// sentence is often too short to tell its language by ("Sono Maria Rossi" is read as Portuguese). A name is none: "Anna Verdi.
    /// Email: anna@example.com" gives no email. The person's own quotes explain such a clause too (see `Grounding`).
    static func explainsBeforeAContact(_ word: Word, in language: Vocabulary.Language?) -> Bool {
        standsInALabel(word, in: language) || Vocabulary.isNeutral(word.folded, in: nil) || Vocabulary.isBeForm(word.accented, in: nil)
    }

    /// Whether a word may stand in a clause that gives the person's contact as their possession of a field or a verb of contacting
    /// (ADR 0023, rule (b)): a contact or field word, a number, a function or time word, or one of the words those shapes are made of,
    /// that is a possessive or an object pronoun of the person, a form of "to be", a verb of contacting with the words before its
    /// object, a form of being reachable, a pronoun of the reader and the words of the reader's lead-in ("You can", "Feel free to",
    /// "Non esitate a"). A name or any
    /// other noun is none: "Puoi contattarmi tramite Anna a ..." gives no contact. The person's own quotes stand there too (see
    /// `Grounding`).
    static func standsBesideAContact(_ word: Word, in language: Vocabulary.Language?) -> Bool {
        let rules = language.flatMap { Self.words[$0] } ?? everyWord
        if namesAContact(word, rules: rules) || Vocabulary.isNeutral(word.folded, in: language) || Vocabulary.isBeForm(word.accented, in: language) {
            return true
        }
        return rules.possessives.contains(word.accented) || rules.objects.contains(word.accented) || rules.reader.contains(word.accented)
            || isContactForm(word, rules: rules) || rules.beforeTheObject.contains(word.accented) || rules.leadIns.contains(word.folded)
            || rules.reachable.contains(word.folded)
    }

    /// Whether the words hold a word of a references section ("Reference", "Referente", "Referenz", "Référence"): from the sentence
    /// that holds one to the end of the description, no contact is the person's (ADR 0023, rule (b)). A references section is short,
    /// and often pasted in another language than the rest, so a word of any of the six languages counts.
    static func holdsAReference(_ words: [Word]) -> Bool {
        words.contains { everyWord.references.contains($0.folded) }
    }

    /// Whether a word names a contact or a field, or is a number: a word of a contact in any shape. A word that names a contact counts
    /// in any of the six languages, as a label is too short to tell its language by ("Courriel", "Sito web").
    private static func namesAContact(_ word: Word, rules: Words) -> Bool {
        word.isNumber || everyWord.contactFields.contains(word.folded) || rules.fields.contains(word.folded)
    }

    /// Whether a clause names a person other than the one it speaks for (ADR 0023, rule (b)): a contact in it is not the person's. That
    /// is a pronoun of a third person anywhere in it ("in touch with him"), but for the reader of a German imperative ("Erreichen Sie
    /// mich"); a possession of a person anywhere in it ("through my manager"), or an owner that a genitive names ("Anna's email"); or a
    /// noun or a name that a verb of contacting in it reaches ("I suggest you contact Anna at ...").
    ///
    /// - Parameters:
    ///   - words: The words of the clause.
    ///   - verbs: The positions of its verbs.
    ///   - language: The language of the description, when it is known.
    static func namesAnotherPerson(words: [Word], verbs: Set<Int>, language: Vocabulary.Language?) -> Bool {
        let rules = language.flatMap { Self.words[$0] } ?? everyWord

        return words.indices.contains { index in
            let word = words[index]
            if rules.otherPeople.contains(word.accented) {
                return !(index > 0 && isContactForm(words[index - 1], rules: rules) && rules.beforeTheObject.contains(word.accented))
            }
            if isPossessive(word, rules: rules), owns(index, in: words[...], rules: rules) {
                return !isOwn(index, in: words[..<endOfPossession(after: index, in: words, verbs: verbs)], rules: rules, language: language)
            }
            if rules.genitives.contains(word.accented), index > 0 {
                return isAnOwner(index - 1, in: words, verbs: verbs, rules: rules, language: language)
            }
            guard isContactVerb(index, in: words, verbs: verbs, rules: rules, language: language, isAddressed: false) else { return false }
            return object(ofContactVerbAt: index, in: words, rules: rules, language: language) == .someoneElse
        }
    }

    /// Where what the possessive at `index` owns ends: at the next verb, or at the end of the clause. German puts what a possessive owns
    /// before the verb that ends the clause ("Du kannst mir an meine E-Mail-Adresse schreiben").
    private static func endOfPossession(after index: Int, in words: [Word], verbs: Set<Int>) -> Int {
        words.indices.first { $0 > index && (verbs.contains($0) || words[$0].isTaggedVerb) } ?? words.endIndex
    }

    /// Whether the word at `index`, before a genitive, names an owner other than the person: a noun or a name ("Anna's", "Acme's"),
    /// not a function word ("it's", "what's"), a field ("my email's"), a number or a verb ("let's").
    private static func isAnOwner(_ index: Int, in words: [Word], verbs: Set<Int>, rules: Words, language: Vocabulary.Language?) -> Bool {
        let word = words[index]
        guard !word.isNumber, !verbs.contains(index), !word.isTaggedVerb, !rules.fields.contains(word.folded) else { return false }
        return !Vocabulary.isNeutral(word.folded, in: language) && !rules.firstPerson.contains(word.accented)
    }

    /// Whether a form of a verb after `previous` is a noun: in Italian, Spanish, French and Portuguese, where the device tags no verb,
    /// after an article, a possessive or a simple preposition ("do ensino", "il mio lavoro", "au travail"). `previous` is a word as
    /// `Word.accented` writes it.
    static func isNounSign(_ previous: String, in language: Vocabulary.Language?) -> Bool {
        language.flatMap { words[$0] }?.nounSigns.contains(previous) ?? false
    }

    // MARK: - Reading

    /// Whether a clause that holds no verb speaks for the person: it shows no subject that is someone else, and, unless the person says
    /// it ("je", "io"), no verb of contacting in it reaches someone else ("Puoi contattare il mio responsabile", "Vous pouvez contacter
    /// mon responsable"): the device tags no verb of those languages, and "puoi" or "pouvez" is in no list.
    private static func speaksWithoutAVerb(_ words: [Word], rules: Words, language: Vocabulary.Language?) -> Bool {
        if hasAnotherSubject(words[...], rules: rules, language: language) { return false }
        if words.contains(where: { rules.firstPerson.contains($0.accented) }) { return true }
        return contacted(in: words, verbs: [], rules: rules, language: language, isAddressed: false) != .someoneElse
    }

    /// Whether the words of a clause that holds no verb show a subject that is someone else: a pronoun of the third person, or a
    /// possession of a person that starts the clause ("My sister", "Il mio responsabile Anna"). A possessive further on is an object:
    /// "2012 meinen Abschluss".
    private static func hasAnotherSubject(_ words: ArraySlice<Word>, rules: Words, language: Vocabulary.Language?) -> Bool {
        if words.contains(where: { rules.thirdPerson.contains($0.accented) }) { return true }
        guard let possessive = leadingPossessive(in: words, rules: rules) else { return false }
        return !isOwn(possessive, in: words, rules: rules, language: language)
    }

    private static func read(_ words: ArraySlice<Word>, rules: Words, language: Vocabulary.Language?) -> Subject {
        let possessive = leadingPossessive(in: words, rules: rules)
        var hasReader = false
        var hasSomeoneElse = false
        var hasNoun = false
        var phrase = Phrase.outside

        for index in words.indices {
            let word = words[index]
            if rules.firstPerson.contains(word.accented) { return .person }

            if rules.thirdPerson.contains(word.accented) {
                hasSomeoneElse = true
                phrase = .outside
            } else if rules.reader.contains(word.accented) {
                hasReader = true
                phrase = .outside
            } else if index == possessive || (phrase != .opened && startsTheSubject(index, in: words, rules: rules, language: language)) {
                if isOwn(index, in: words, rules: rules, language: language) { return .person }
                hasSomeoneElse = true
                phrase = .outside
            } else if word.isNumber {
                phrase = .outside
            } else if rules.prepositions.contains(word.accented) || isPossessive(word, rules: rules) {
                phrase = .opened
            } else if Vocabulary.isNeutral(word.folded, in: language) {
                if phrase == .inside { phrase = .outside }
            } else if phrase == .outside {
                hasNoun = true
            } else {
                phrase = .inside
            }
        }
        return hasReader ? .reader : hasSomeoneElse ? .someoneElse : hasNoun ? .noun : .none
    }

    private static func isPossessive(_ word: Word, rules: Words) -> Bool {
        rules.possessives.contains(word.accented) || rules.otherPossessives.contains(word.accented)
    }

    /// Whether the possessive at `index`, which no preposition opens a phrase for, starts the subject after a phrase of time or place
    /// ("In Rome my sister speaks", "Dal 2016 la mia collega lavora"): it owns the next word, which is no preposition. A possessive
    /// right after a preposition belongs to the preposition's phrase ("in my free time"). German is the exception: there the subject
    /// is right after the verb (`subjectPhrase`), and what a possessive before the verb owns is an object ("2012 meinen Abschluss
    /// gemacht").
    private static func startsTheSubject(_ index: Int, in words: ArraySlice<Word>, rules: Words, language: Vocabulary.Language?) -> Bool {
        language != .german && isPossessive(words[index], rules: rules) && owns(index, in: words, rules: rules)
    }

    /// Whether the possessive at `index` owns something: the next word, which is no preposition. One that ends the words, or stands
    /// before a preposition, is a word of another kind ("mi sono laureata", "l'azienda mia di Roma").
    private static func owns(_ index: Int, in words: ArraySlice<Word>, rules: Words) -> Bool {
        words.indices.contains(index + 1) && !rules.prepositions.contains(words[index + 1].accented)
    }

    /// Whether the words before the first verb of a clause with no subject hide one, in the languages that keep their subject (ADR 0023,
    /// rule (c)): anything but a pure time phrase (years and the words of the time-phrase list) comes first, and no first-person pronoun
    /// is among it. A phrase of place does not tell where it ends: "In Rome Anna speaks French" has Anna for its subject, and so the
    /// rare "In Rome worked at Acme" is someone else's too, while "Since 2016 worked at Acme" is the person's. English and French: German
    /// reads its subject right after the verb (`subjectPhrase`), where "In Berlin arbeitete Anna" has Anna for it, and a German verb with
    /// no subject after it ends a clause of a CV ("Bei Acme gearbeitet", "2012 meinen Abschluss gemacht").
    private static func hidesASubject(_ words: ArraySlice<Word>, language: Vocabulary.Language?) -> Bool {
        guard language == .english || language == .french else { return false }
        return !words.allSatisfy { $0.isNumber || Vocabulary.isTimePhrase($0.folded, in: language) }
    }

    /// The position, among `words`, of the possessive that starts the clause (past an article), if there is one: it owns what follows,
    /// so a possessive that ends the words is none (Italian "mi sono laureata" is "I graduated", not "my ...").
    private static func leadingPossessive(in words: ArraySlice<Word>, rules: Words) -> Int? {
        let start = words.startIndex + (words.first.map { rules.articles.contains($0.accented) } == true ? 1 : 0)
        return words.indices.contains(start + 1) && isPossessive(words[start], rules: rules) ? start : nil
    }

    /// Whether the possessive at `index` is the person's, owning one of their own fields: a possessive of the first person that owns
    /// nothing but fields ("my email"). One of the third person ("her email") owns whatever it owns for someone else.
    private static func isOwn(_ index: Int, in words: ArraySlice<Word>, rules: Words, language: Vocabulary.Language?) -> Bool {
        rules.possessives.contains(words[index].accented) && isOwnField(words[(index + 1)...], rules: rules, language: language)
    }

    /// Whether what a possessive owns is one of the person's own fields: nothing but field words, and words that qualify them ("my
    /// phone number", "my current job"), with one field word at least. What follows a preposition is a complement, and owned by no
    /// one: "my job at Acme" owns a job, "my sister at Acme" a sister.
    private static func isOwnField(_ owned: ArraySlice<Word>, rules: Words, language: Vocabulary.Language?) -> Bool {
        let possessed = owned.prefix { !rules.prepositions.contains($0.accented) }
        return possessed.contains { rules.fields.contains($0.folded) }
            && possessed.allSatisfy { rules.fields.contains($0.folded) || Vocabulary.isNeutral($0.folded, in: language) }
    }

    /// The phrase right after the verb, where German puts the subject when a phrase of time or place comes first: up to the next
    /// preposition.
    private static func subjectPhrase(after words: ArraySlice<Word>, rules: Words) -> ArraySlice<Word> {
        let end = words.indices.first { rules.prepositions.contains(words[$0].accented) } ?? words.endIndex
        return words[words.startIndex..<end]
    }

    // MARK: - Contacting

    /// Whom a verb of contacting reaches.
    private enum Contacted {
        case person
        case someoneElse
    }

    /// Whom the clause's verb of contacting reaches: the person, as its object ("reach me", "contattarmi", "contactez-moi") or as the
    /// object pronoun before it ("mi potete contattare", "vous pouvez me contacter", "Du kannst mich unter ... erreichen"); someone
    /// else, as the object right after it ("reach my manager through me": a first-person word further on is no object of it, nor is one
    /// a preposition owns); nil when the clause has no such verb, or the verb no object. A verb of contacting addresses the reader
    /// whether the clause names them ("You can reach"), tells them by the form of a verb ("Puoi contattare", "Puede contactar") or
    /// speaks to them in the imperative ("Contact my agent", "Feel free to contact my manager"), unless it is the purpose of the
    /// person's own statement (`isAPurpose`). A verb of a CV ("write") takes its work directly ("Write documentation at Acme"), and
    /// reaches someone else only through the preposition it takes ("Write to my manager").
    ///
    /// - Parameter isAddressed: Whether the clause names the reader as its subject. When it does not, in English and German, whose
    ///   verbs the device tags, a form of contacting is a verb only when the device tags it so: "Contact details" is a noun.
    private static func contacted(in words: [Word], verbs: Set<Int>, rules: Words, language: Vocabulary.Language?, isAddressed: Bool) -> Contacted? {
        let verb = words.indices.first { index in
            isContactVerb(index, in: words, verbs: verbs, rules: rules, language: language, isAddressed: isAddressed)
                && !isAPurpose(index, in: words, language: language)
        }
        return verb.flatMap { object(ofContactVerbAt: $0, in: words, rules: rules, language: language) }
    }

    /// Whether the word is a form of a verb of contacting, as the lists write it.
    private static func isContactForm(_ word: Word, rules: Words) -> Bool {
        rules.contactVerbs.contains(word.folded) || rules.contactingThePerson.contains(word.folded)
    }

    /// Whether the word at `index` is a verb of contacting: a form of one, and, in English and German when the clause does not name the
    /// reader, a verb the device tags (see `contacted`).
    private static func isContactVerb(
        _ index: Int, in words: [Word], verbs: Set<Int>, rules: Words, language: Vocabulary.Language?, isAddressed: Bool
    ) -> Bool {
        guard isContactForm(words[index], rules: rules) else { return false }
        return isAddressed || !VerbForms.readsVerbsByTags(in: language) || verbs.contains(index) || words[index].isTaggedVerb
    }

    /// Whom the verb of contacting at `verb` reaches (see `contacted`).
    private static func object(ofContactVerbAt verb: Int, in words: [Word], rules: Words, language: Vocabulary.Language?) -> Contacted? {
        if rules.contactingThePerson.contains(words[verb].folded) { return .person }
        // An object pronoun right before the verb is its object: what follows is a complement ("vous pouvez me contacter à Turin").
        if verb > 0, rules.objects.contains(words[verb - 1].accented), !(verb > 1 && isOwnedByAPreposition(words[verb - 2], rules: rules, language: language)) {
            return .person
        }

        var next = verb + 1
        while words.indices.contains(next), rules.beforeTheObject.contains(words[next].accented) { next += 1 }
        if words.indices.contains(next), let object = object(at: next, in: words, rules: rules, language: language) {
            let isWork = object == .someoneElse && next == verb + 1 && Vocabulary.isVerb(words[verb].folded, in: language)
            return isWork ? nil : object
        }

        let isAfterAnObjectPronoun = words.indices.prefix(verb).contains { index in
            rules.objects.contains(words[index].accented) && !(index > 0 && isOwnedByAPreposition(words[index - 1], rules: rules, language: language))
        }
        return isAfterAnObjectPronoun ? .person : nil
    }

    /// Whether `word`, before an object pronoun, is a preposition that owns it ("through me", "über mich"), and no infinitive marker
    /// that introduces the verb after it ("à me contacter", "em me contatar").
    private static func isOwnedByAPreposition(_ word: Word, rules: Words, language: Vocabulary.Language?) -> Bool {
        rules.prepositions.contains(word.accented) && !VerbForms.isInfinitiveMarker(word.folded, in: language)
    }

    /// Whether the verb of contacting at `index` is the purpose of the person's own statement: an infinitive marker introduces it, after a
    /// verb the vocabulary lists ("Worked at Acme to contact new clients", "Ho lavorato presso Acme per contattare i clienti", "Mi
    /// occupo di contattare i clienti"). After any other verb it is the reader's: "Feel free to contact my manager", "Non esitate a
    /// contattare il mio responsabile".
    private static func isAPurpose(_ index: Int, in words: [Word], language: Vocabulary.Language?) -> Bool {
        guard index > 0, VerbForms.isInfinitiveMarker(words[index - 1].folded, in: language) else { return false }
        return words.prefix(index - 1).contains { word in
            Vocabulary.isVerb(word.folded, in: language) || Vocabulary.isBeForm(word.accented, in: language) || Vocabulary.isAuxiliary(word.accented, in: language)
        }
    }

    /// What the word right after a verb of contacting makes of its object: the person, as a first-person object or a possession of
    /// one of their own fields ("email my personal address"); none, as a number, a preposition or a field word ("Call +39 ...",
    /// "Contact email: ..."); someone else otherwise, as an article, a noun, a name, a pronoun or a possession of a person ("reach my
    /// manager", "contactar a mi jefe").
    private static func object(at index: Int, in words: [Word], rules: Words, language: Vocabulary.Language?) -> Contacted? {
        let word = words[index]
        if rules.objects.contains(word.accented) { return .person }
        if word.isNumber || rules.prepositions.contains(word.accented) || rules.fields.contains(word.folded) { return nil }
        return isPossessive(word, rules: rules) && isOwn(index, in: words[...], rules: rules, language: language) ? .person : .someoneElse
    }
}
