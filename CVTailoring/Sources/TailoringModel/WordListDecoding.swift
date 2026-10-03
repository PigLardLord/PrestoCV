import Foundation

extension LanguageWordLists {
    /// Reads the file of one language (`docs/architecture/word-lists.md`) into its typed lists, or refuses it (R8).
    init(decoding data: Data, language: TailoringLanguage) throws(TailoringModelError) {
        guard data.count <= WordListFormat.maxFileBytes else { throw .corruptWordList(.language(language)) }
        let file: WordListDocument
        do {
            file = try JSONDecoder().decode(WordListDocument.self, from: data)
        } catch let failure as WordListFailure {
            throw failure.error(in: language)
        } catch {
            throw .corruptWordList(.language(language))
        }
        let reading = WordListReading(language: language)
        self.init(
            language: language,
            advert: try reading.advert(file.advert),
            dates: DateWords(months: try reading.months(file.dates.months, .datesMonths)),
            numbers: NumberWords(words: try reading.numbers(file.numbers.words, .numbersWords)),
            spans: try reading.spans(file.spans),
            letter: try reading.letter(file.letter),
            technologies: try reading.texts(file.fields.technologies, .fieldsTechnologies)
        )
    }
}

// MARK: - What the decoder reports

/// Why the decoder stopped, as a code. Anything else it throws is a file that cannot be read.
private enum WordListFailure: Error {
    case missing(WordListKey)

    func error(in language: TailoringLanguage) -> TailoringModelError {
        switch self {
        case .missing(let key): .incompleteWordList(language, key)
        }
    }
}

// MARK: - The file as written

/// A key of a JSON object, which the format names and not a Swift type.
private struct DynamicKey: CodingKey, ExpressibleByStringLiteral {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ stringValue: String) { self.stringValue = stringValue }
    init(stringLiteral value: String) { stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

extension KeyedDecodingContainer where Key == DynamicKey {
    /// Refuses a key that is not among `known`: the format is closed, so a key it does not name is a mistake or a newer
    /// format, and neither is read as if it were not there.
    func allowOnly(_ known: [String]) throws {
        guard allKeys.allSatisfy({ known.contains($0.stringValue) }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "a key the format does not know"))
        }
    }
}

/// A list as the file writes it, before any rule is applied.
private struct RawList<Entry: Decodable>: Decodable {
    let source: String
    let licence: String
    let entries: [Entry]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        try container.allowOnly(WordListFormat.listKeys)
        try self.init(container: container)
    }

    init(container: KeyedDecodingContainer<DynamicKey>) throws {
        source = try container.decode(String.self, forKey: "source")
        licence = try container.decode(String.self, forKey: "licence")
        entries = try container.decode([Entry].self, forKey: "entries")
    }
}

private struct RawStreets: Decodable {
    let list: RawList<String>
    let order: String

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        try container.allowOnly(WordListFormat.streetListKeys)
        list = try RawList(container: container)
        order = try container.decode(String.self, forKey: "order")
    }
}

private struct RawMonth: Decodable {
    let name: String
    let month: Int

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        try container.allowOnly(WordListFormat.monthKeys)
        name = try container.decode(String.self, forKey: "name")
        month = try container.decode(Int.self, forKey: "month")
    }
}

private struct RawNumber: Decodable {
    let word: String
    let value: Int

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        try container.allowOnly(WordListFormat.numberKeys)
        word = try container.decode(String.self, forKey: "word")
        value = try container.decode(Int.self, forKey: "value")
    }
}

private struct RawSynonym: Decodable {
    let forms: [String]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        try container.allowOnly(WordListFormat.synonymKeys)
        forms = try container.decode([String].self, forKey: "forms")
    }
}

/// One group of the file, opened to read its lists by key.
private struct RawGroup {
    let container: KeyedDecodingContainer<DynamicKey>

    /// The group of `first`, which is the list reported missing when the whole group is.
    init(_ root: KeyedDecodingContainer<DynamicKey>, startingWith first: WordListKey) throws {
        guard root.contains(DynamicKey(first.group)) else { throw WordListFailure.missing(first) }
        container = try root.nestedContainer(keyedBy: DynamicKey.self, forKey: DynamicKey(first.group))
        try container.allowOnly(WordListKey.allCases.filter { $0.group == first.group }.map(\.name))
    }

    func list<Value: Decodable>(_ key: WordListKey, as type: Value.Type = Value.self) throws -> Value {
        guard container.contains(DynamicKey(key.name)) else { throw WordListFailure.missing(key) }
        return try container.decode(Value.self, forKey: DynamicKey(key.name))
    }
}

private struct RawAdvert {
    let stopwords, plainWords, dimensions, boilerplate, genderMarkers, instructions, names: RawList<String>
    let streets: RawStreets
    let synonyms: RawList<RawSynonym>
    let requirementHeadings, offerHeadings, structuralHeadings: RawList<String>

    init(_ group: RawGroup) throws {
        stopwords = try group.list(.advertStopwords)
        plainWords = try group.list(.advertPlainWords)
        dimensions = try group.list(.advertDimensions)
        boilerplate = try group.list(.advertBoilerplate)
        genderMarkers = try group.list(.advertGenderMarkers)
        instructions = try group.list(.advertInstructions)
        streets = try group.list(.advertStreets)
        names = try group.list(.advertNames)
        synonyms = try group.list(.advertSynonyms)
        requirementHeadings = try group.list(.advertRequirementHeadings)
        offerHeadings = try group.list(.advertOfferHeadings)
        structuralHeadings = try group.list(.advertStructuralHeadings)
    }
}

private struct RawSpans {
    let floorLeadIns, yearWords, monthWords, tiedCounts: RawList<String>
    let countWords: RawList<RawNumber>

    init(_ group: RawGroup) throws {
        floorLeadIns = try group.list(.spansFloorLeadIns)
        yearWords = try group.list(.spansYearWords)
        monthWords = try group.list(.spansMonthWords)
        countWords = try group.list(.spansCountWords)
        tiedCounts = try group.list(.spansTiedCounts)
    }
}

private struct RawLetter {
    let greetings, salutations, addressees, addresseeNouns, valedictions: RawList<String>
    let salaryExpectationAsks, startDateAsks, statedTermWords: RawList<String>

    init(_ group: RawGroup) throws {
        greetings = try group.list(.letterGreetings)
        salutations = try group.list(.letterSalutations)
        addressees = try group.list(.letterAddressees)
        addresseeNouns = try group.list(.letterAddresseeNouns)
        valedictions = try group.list(.letterValedictions)
        salaryExpectationAsks = try group.list(.letterSalaryExpectationAsks)
        startDateAsks = try group.list(.letterStartDateAsks)
        statedTermWords = try group.list(.letterStatedTermWords)
    }
}

/// The whole file as written.
private struct WordListDocument: Decodable {
    struct Dates { let months: RawList<RawMonth> }
    struct Numbers { let words: RawList<RawNumber> }
    struct Fields { let technologies: RawList<String> }

    let advert: RawAdvert
    let dates: Dates
    let numbers: Numbers
    let spans: RawSpans
    let letter: RawLetter
    let fields: Fields

    init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: DynamicKey.self)
        guard try root.decode(Int.self, forKey: "version") == WordListFormat.version else {
            throw DecodingError.dataCorruptedError(forKey: "version", in: root, debugDescription: "a version this code does not read")
        }
        try root.allowOnly(WordListFormat.rootKeys)
        advert = try RawAdvert(RawGroup(root, startingWith: .advertStopwords))
        dates = Dates(months: try RawGroup(root, startingWith: .datesMonths).list(.datesMonths))
        numbers = Numbers(words: try RawGroup(root, startingWith: .numbersWords).list(.numbersWords))
        spans = try RawSpans(RawGroup(root, startingWith: .spansFloorLeadIns))
        letter = try RawLetter(RawGroup(root, startingWith: .letterGreetings))
        fields = Fields(technologies: try RawGroup(root, startingWith: .fieldsTechnologies).list(.fieldsTechnologies))
    }
}

// MARK: - From the file to the typed lists

/// Turns what the decoder read into the typed lists of one language.
private struct WordListReading {
    let language: TailoringLanguage

    func advert(_ raw: RawAdvert) throws(TailoringModelError) -> AdvertWords {
        AdvertWords(
            stopwords: try texts(raw.stopwords, .advertStopwords),
            plainWords: try texts(raw.plainWords, .advertPlainWords),
            dimensions: try texts(raw.dimensions, .advertDimensions),
            boilerplate: try texts(raw.boilerplate, .advertBoilerplate),
            genderMarkers: try texts(raw.genderMarkers, .advertGenderMarkers),
            instructions: try texts(raw.instructions, .advertInstructions),
            streets: try streets(raw.streets),
            names: try texts(raw.names, .advertNames),
            synonyms: try synonyms(raw.synonyms, .advertSynonyms),
            requirementHeadings: try texts(raw.requirementHeadings, .advertRequirementHeadings),
            offerHeadings: try texts(raw.offerHeadings, .advertOfferHeadings),
            structuralHeadings: try texts(raw.structuralHeadings, .advertStructuralHeadings)
        )
    }

    func spans(_ raw: RawSpans) throws(TailoringModelError) -> SpanWords {
        SpanWords(
            floorLeadIns: try texts(raw.floorLeadIns, .spansFloorLeadIns),
            yearWords: try texts(raw.yearWords, .spansYearWords),
            monthWords: try texts(raw.monthWords, .spansMonthWords),
            countWords: try numbers(raw.countWords, .spansCountWords),
            tiedCounts: try tiedCounts(raw.tiedCounts)
        )
    }

    func letter(_ raw: RawLetter) throws(TailoringModelError) -> LetterWords {
        LetterWords(
            greetings: try texts(raw.greetings, .letterGreetings),
            salutations: try texts(raw.salutations, .letterSalutations),
            addressees: try texts(raw.addressees, .letterAddressees),
            addresseeNouns: try texts(raw.addresseeNouns, .letterAddresseeNouns),
            valedictions: try texts(raw.valedictions, .letterValedictions),
            salaryExpectationAsks: try texts(raw.salaryExpectationAsks, .letterSalaryExpectationAsks),
            startDateAsks: try texts(raw.startDateAsks, .letterStartDateAsks),
            statedTermWords: try texts(raw.statedTermWords, .letterStatedTermWords)
        )
    }

    func texts(_ raw: RawList<String>, _ key: WordListKey) throws(TailoringModelError) -> WordList<String> {
        try check(raw, key, words: raw.entries)
        return WordList(source: raw.source, licence: raw.licence, entries: raw.entries)
    }

    func months(_ raw: RawList<RawMonth>, _ key: WordListKey) throws(TailoringModelError) -> WordList<MonthName> {
        try check(raw, key, words: raw.entries.map(\.name))
        guard raw.entries.allSatisfy({ (1...12).contains($0.month) }) else { throw corrupt }
        guard Set(raw.entries.map(\.month)).count == 12 else { throw .incompleteWordList(language, key) }
        return WordList(source: raw.source, licence: raw.licence, entries: raw.entries.map { MonthName(name: $0.name, month: $0.month) })
    }

    func numbers(_ raw: RawList<RawNumber>, _ key: WordListKey) throws(TailoringModelError) -> WordList<NumberWord> {
        try check(raw, key, words: raw.entries.map(\.word))
        guard raw.entries.allSatisfy({ $0.value >= 0 }) else { throw corrupt }
        return WordList(source: raw.source, licence: raw.licence, entries: raw.entries.map { NumberWord(word: $0.word, value: $0.value) })
    }

    func synonyms(_ raw: RawList<RawSynonym>, _ key: WordListKey) throws(TailoringModelError) -> WordList<SynonymGroup> {
        try check(raw, key, words: raw.entries.flatMap(\.forms))
        guard raw.entries.allSatisfy({ $0.forms.count >= 2 }) else { throw corrupt }
        return WordList(source: raw.source, licence: raw.licence, entries: raw.entries.map { SynonymGroup(forms: $0.forms) })
    }

    /// Each template holds `{count}` and `{employer}` once and no other brace, so a consumer can split it into its words.
    func tiedCounts(_ raw: RawList<String>) throws(TailoringModelError) -> WordList<String> {
        let list = try texts(raw, .spansTiedCounts)
        for template in raw.entries {
            func occurrences(of placeholder: String) -> Int { template.components(separatedBy: placeholder).count - 1 }
            let literal = template.replacingOccurrences(of: "{count}", with: "").replacingOccurrences(of: "{employer}", with: "")
            guard occurrences(of: "{count}") == 1, occurrences(of: "{employer}") == 1, !literal.contains("{"), !literal.contains("}") else {
                throw corrupt
            }
        }
        return list
    }

    func streets(_ raw: RawStreets) throws(TailoringModelError) -> StreetWords {
        guard let order = StreetOrder(rawValue: raw.order) else { throw corrupt }
        return StreetWords(list: try texts(raw.list, .advertStreets), order: order)
    }

    // MARK: The rules every list shares

    private var corrupt: TailoringModelError { .corruptWordList(.language(language)) }

    /// A list states its source and its licence, holds an entry, and each word of it is trimmed, says something once
    /// folded, and is not another word of the list once folded: a repeat would count a word twice.
    private func check<Entry>(_ raw: RawList<Entry>, _ key: WordListKey, words: [String]) throws(TailoringModelError) {
        guard isStated(raw.source), isStated(raw.licence) else { throw corrupt }
        guard !raw.entries.isEmpty else { throw .incompleteWordList(language, key) }
        var folded = Set<String>()
        for word in words {
            guard isStated(word), folded.insert(TextFold.fold(word)).inserted else { throw corrupt }
        }
    }

    /// Not empty, not blank at either end by the model's one rule of trimming, and something once folded.
    private func isStated(_ text: String) -> Bool {
        let content = Bounds.trimmed(text[...])
        return !content.isEmpty && content == text[...] && !TextFold.fold(text).isEmpty
    }
}
