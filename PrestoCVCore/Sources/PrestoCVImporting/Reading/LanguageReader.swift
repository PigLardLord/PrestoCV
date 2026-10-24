import PrestoCVDomain

/// Reads languages and their levels. A level is kept only when the text states a CEFR level or that the language is
/// native; any other words of a level are kept as words, with no level, and flagged (ADR 0027).
enum LanguageReader {

    static func read(_ section: Section, into findings: inout Findings) {
        for block in section.blocks where !findings.consumedBlocks.contains(block.index) {
            if block.kind == .tableHeader {
                findings.leaveOut(block, .markup)
                continue
            }
            var cells = section.cells(of: block, in: findings.document)
            var nativeLabel: Piece?
            if let first = cells.first, SectionVocabulary.isLanguageLabel(first.text) {
                if isNative(first.text) { nativeLabel = first }
                cells.removeFirst()
            }
            let items = cells.flatMap { $0.split(by: [", ", "; ", " • ", " · ", " | ", "\t"]) }
            read(items, nativeLabel: nativeLabel, section: section, into: &findings)
        }
    }

    /// The items of one row: a language starts at its name, and the items after it in the row give its level. An item
    /// with no language before it in the row is a level of the language of the rows before, as in a Europass grid.
    /// - Parameter nativeLabel: The row's label, when it says the languages are mother tongues: it is their level's
    ///   evidence.
    private static func read(_ items: [Piece], nativeLabel: Piece?, section: Section, into findings: inout Findings) {
        var current: Int?
        var notes: [Int: [Piece]] = [:]
        defer { unplace(notes, section: section, into: &findings) }
        for item in items {
            if let name = languageName(in: item) {
                var language = ImportedLanguage(name: name.quote())
                if let nativeLabel {
                    language.level = Sourced(value: .native, spans: [nativeLabel.span], reading: .languageLevel)
                }
                findings.cv.languages.append(language)
                let index = findings.cv.languages.count - 1
                current = index
                describe(index, with: item.removing([range(of: name, in: item)]), nativeLabel: nativeLabel, notes: &notes, section: section, into: &findings)
            } else if let current {
                describe(current, with: [item], nativeLabel: nativeLabel, notes: &notes, section: section, into: &findings)
            } else if !attachLevel(item, section: section, into: &findings) {
                // A grid of levels, or the words of a level, under the language before it; otherwise text not imported
                findings.unplace(item, in: section)
            }
        }
    }

    /// Gives a language the level its parts state, or the words of one. A language has one level: what else a part says
    /// stays visible as text not imported, and so does a second level.
    private static func describe(
        _ index: Int, with parts: [Piece], nativeLabel: Piece?, notes: inout [Int: [Piece]], section: Section, into findings: inout Findings
    ) {
        for part in parts {
            let language = findings.cv.languages[index]
            if let (level, rest) = level(in: part) {
                // The row's label gives a language its level only until the language states one itself
                let isFromLabel = nativeLabel.map { language.level?.spans == [$0.span] } ?? false
                guard language.level == nil || isFromLabel else {
                    notes[index, default: []].append(part)
                    continue
                }
                if let words = language.levelWords { findings.unplace(words, in: section) }
                findings.cv.languages[index].level = level
                findings.cv.languages[index].levelWords = nil
                if !rest.isEmpty { notes[index, default: []].append(part) }
            } else if let words = levelWordsPiece(part), language.level == nil {
                addWords(words, to: index, into: &findings)
            } else {
                notes[index, default: []].append(part)
            }
        }
    }

    /// What the row of a language says besides its level, as text not imported with the language it is about: for each
    /// language one quote from its name to the end of its last note when they share a line, the notes alone otherwise.
    private static func unplace(_ notes: [Int: [Piece]], section: Section, into findings: inout Findings) {
        for index in notes.keys.sorted() {
            let parts = notes[index] ?? []
            guard let first = parts.first, let last = parts.last else { continue }
            unplace(parts, from: first.span.lowerBound, to: last.span.upperBound, ofLanguage: index, section: section, into: &findings)
        }
    }

    /// One note of a language of an earlier row, with its language when they share a line.
    private static func unplace(_ part: Piece, ofLanguage index: Int, section: Section, into findings: inout Findings) {
        unplace([part], from: part.span.lowerBound, to: part.span.upperBound, ofLanguage: index, section: section, into: &findings)
    }

    private static func unplace(
        _ parts: [Piece], from start: Int, to end: Int, ofLanguage index: Int, section: Section, into findings: inout Findings
    ) {
        if let name = findings.cv.languages[index].name.spans.first, name.lowerBound <= start {
            let span = SourceSpan(name.lowerBound, end)
            let text = findings.document.text(of: span)
            if !text.contains("\n") { return findings.unplace(Piece(text: text, span: span), in: section) }
        }
        for part in parts { findings.unplace(part, in: section) }
    }

    /// The words of a level, after the ones the language has.
    private static func addWords(_ words: Sourced<String>, to index: Int, into findings: inout Findings) {
        guard let existing = findings.cv.languages[index].levelWords else {
            findings.cv.languages[index].levelWords = words
            return
        }
        let check: CheckReason = existing.check == .levelsDiffer || words.check == .levelsDiffer ? .levelsDiffer : .levelNotCEFR
        findings.cv.languages[index].levelWords = Sourced(value: existing.value + "\n" + words.value, spans: existing.spans + words.spans, check: check)
    }

    // MARK: Names

    /// The first language a piece names, as written.
    static func languageName(in piece: Piece) -> Piece? {
        piece.text.words.first { names.contains($0.folded) }.map { piece.sub($0.startIndex..<$0.endIndex) }
    }

    private static func range(of name: Piece, in item: Piece) -> Range<String.Index> {
        let scalars = item.text.unicodeScalars
        let lower = scalars.index(scalars.startIndex, offsetBy: name.span.lowerBound - item.span.lowerBound)
        let upper = scalars.index(scalars.startIndex, offsetBy: name.span.upperBound - item.span.lowerBound)
        return lower..<upper
    }

    private static let names: Set<String> = Set([
        "english", "inglese", "englisch", "inglés", "anglais", "inglês",
        "italian", "italiano", "italienisch", "italien", "italiana",
        "german", "tedesco", "deutsch", "alemán", "allemand", "alemão",
        "spanish", "spagnolo", "spanisch", "español", "castellano", "espagnol", "espanhol",
        "french", "francese", "französisch", "francés", "français", "francês",
        "portuguese", "portoghese", "portugiesisch", "portugués", "portugais", "português",
        "dutch", "olandese", "niederländisch", "neerlandés", "néerlandais", "holandês", "neerlandês",
        "chinese", "cinese", "chinesisch", "chino", "chinois", "chinês", "mandarin", "mandarino", "mandarín",
        "japanese", "giapponese", "japanisch", "japonés", "japonais", "japonês",
        "arabic", "arabo", "arabisch", "árabe", "arabe",
        "russian", "russo", "russisch", "ruso", "russe",
        "polish", "polacco", "polnisch", "polaco", "polonais",
        "romanian", "rumeno", "rumänisch", "rumano", "roumain", "romeno",
        "greek", "greco", "griechisch", "griego", "grec", "grego",
        "turkish", "turco", "türkisch", "turc",
        "catalan", "catalano", "katalanisch", "catalán", "català", "catalão",
        "swedish", "svedese", "schwedisch", "sueco", "suédois",
        "ukrainian", "ucraino", "ukrainisch", "ucraniano", "ukrainien",
        "albanian", "albanese", "albanisch", "albanés", "albanais", "albanês",
        "korean", "coreano", "koreanisch", "coréen",
        "hindi", "galician", "gallego", "galego", "valenciano", "valencian", "valencià", "basque", "euskera", "danish", "danese", "dänisch", "danés", "danois",
        "norwegian", "norvegese", "norwegisch", "noruego", "norvégien", "finnish", "finlandese", "finnisch", "finlandés", "finnois",
        "hungarian", "ungherese", "ungarisch", "húngaro", "hongrois", "czech", "ceco", "tschechisch", "checo", "tchèque",
        "croatian", "croato", "kroatisch", "croata", "croate", "serbian", "serbo", "serbisch", "serbio", "serbe",
    ].map(\.folded))

    // MARK: Levels

    /// A CEFR level, or the words of a native language, in a piece, and the rest of the piece. Different CEFR levels
    /// give none.
    private static func level(in piece: Piece) -> (level: Sourced<LanguageProficiency>, rest: [Piece])? {
        if isNative(piece.text) {
            return (Sourced(value: .native, spans: [piece.span], reading: .languageLevel), [])
        }
        let levels = cefrLevels(in: piece)
        guard let first = levels.first, levels.allSatisfy({ $0.1 == first.1 }) else { return nil }
        return (Sourced(value: first.1, spans: levels.map(\.0.span), reading: .languageLevel), piece.removing(levels.map { range(of: $0.0, in: piece) }))
    }

    /// Every CEFR level a piece states, with where.
    static func cefrLevels(in piece: Piece) -> [(Piece, LanguageProficiency)] {
        var found: [(Piece, LanguageProficiency)] = []
        let text = piece.text
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            if next < text.endIndex, "ABCabc".contains(text[index]), "12".contains(text[next]) {
                let before = index == text.startIndex ? nil : text[text.index(before: index)]
                let afterIndex = text.index(after: next)
                let after = afterIndex == text.endIndex ? nil : text[afterIndex]
                if !(before?.isLetter ?? false) && !(before?.isNumber ?? false) && !(after?.isLetter ?? false) && !(after?.isNumber ?? false),
                   let level = LanguageProficiency(rawValue: text[index...next].lowercased()) {
                    found.append((piece.sub(index..<afterIndex), level))
                }
            }
            index = next
        }
        return found
    }

    static func isNative(_ text: String) -> Bool {
        let key = SectionVocabulary.key(text)
        return nativeWords.contains { key == $0 || key.hasPrefix($0 + " ") || key.hasSuffix(" " + $0) || key.contains(" " + $0 + " ") }
    }

    private static let nativeWords: [String] = [
        "native", "native speaker", "native or bilingual", "mother tongue", "mother tongues", "madrelingua", "lingua madre", "nativo",
        "nativa", "muttersprache", "muttersprachlich", "muttersprachler", "muttersprachlerin", "lengua materna", "langue maternelle",
        "maternelle", "natif", "língua materna", "native language",
    ].map(SectionVocabulary.key)

    /// The words of a level that are no CEFR level, as written, flagged for the review.
    private static func levelWordsPiece(_ piece: Piece) -> Sourced<String>? {
        let key = SectionVocabulary.key(piece.text)
        guard !key.isEmpty, piece.words.count <= 6 else { return nil }
        let isLevel = levelWords.contains { key == $0 || key.hasPrefix($0 + " ") || key.hasSuffix(" " + $0) }
            || SkillLevelWords.isLevel(piece.text)
        return isLevel ? piece.quote(check: .levelNotCEFR) : nil
    }

    private static let levelWords: [String] = [
        "fluent", "fluently", "bilingual", "business fluent", "professional working", "full professional", "limited working",
        "elementary", "conversational", "working knowledge", "basic knowledge", "scolastico", "fluente", "ottimo", "buono",
        "discreto", "sufficiente", "elementare", "base", "bilingue", "fließend", "verhandlungssicher", "gute kenntnisse",
        "sehr gute kenntnisse", "grundkenntnisse", "fortgeschritten", "konversationssicher", "fluido", "nivel alto", "nivel medio",
        "nivel básico", "avanzado", "intermedio", "básico", "courant", "bilingue", "notions", "intermédiaire", "avancé",
        "scolaire", "professionnel", "fluente", "avançado", "intermédio", "básico", "eccellente", "excellent", "good", "very good",
        "proficiency", "proficient", "capacità di lettura", "capacità di scrittura", "capacità di espressione orale",
        "comprensione", "parlato", "scritto", "listening", "reading", "writing", "speaking", "spoken interaction",
        "spoken production",
    ].map(SectionVocabulary.key)

    /// A piece of levels under a language that has none yet: a Europass grid ("B2 B2 B1 B1 B2"), or the words of a
    /// level on a line of their own.
    private static func attachLevel(_ piece: Piece, section: Section, into findings: inout Findings) -> Bool {
        guard let last = findings.cv.languages.indices.last, findings.cv.languages[last].level == nil else { return false }
        let levels = cefrLevels(in: piece)
        if !levels.isEmpty {
            let rest = piece.removing(levels.map { range(of: $0.0, in: piece) })
            guard rest.allSatisfy({ levelWordsPiece($0) != nil }) else { return false }
            if levels.allSatisfy({ $0.1 == levels[0].1 }) {
                if let words = findings.cv.languages[last].levelWords { findings.unplace(words, in: section) }
                findings.cv.languages[last].level = Sourced(value: levels[0].1, spans: levels.map(\.0.span), reading: .languageLevel)
                findings.cv.languages[last].levelWords = nil
                if !rest.isEmpty { unplace(piece, ofLanguage: last, section: section, into: &findings) }
            } else {
                addWords(piece.quote(check: .levelsDiffer), to: last, into: &findings)
            }
            return true
        }
        if let words = levelWordsPiece(piece) {
            addWords(words, to: last, into: &findings)
            return true
        }
        return false
    }
}
