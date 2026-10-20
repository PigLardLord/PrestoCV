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
            var cells = Piece.cells(of: block, in: findings.document)
            var nativeLabel: Piece?
            if let first = cells.first, SectionVocabulary.isLanguageLabel(first.text) {
                if isNative(first.text) { nativeLabel = first }
                cells.removeFirst()
            }
            for cell in cells {
                read(cell, nativeLabel: nativeLabel, section: section, into: &findings)
            }
        }
    }

    /// - Parameter nativeLabel: The row's label, when it says the languages are mother tongues: it is their level's
    ///   evidence.
    private static func read(_ cell: Piece, nativeLabel: Piece?, section: Section, into findings: inout Findings) {
        let items = cell.split(by: [", ", "; ", " • ", " · ", " | ", "\t"])
        for item in items {
            guard let name = languageName(in: item) else {
                // A grid of levels, or the words of a level, under the language before it
                if !attachLevel(item, into: &findings) { findings.unplace(item, in: section) }
                continue
            }
            var language = ImportedLanguage(name: name.quote())
            let rest = item.removing([range(of: name, in: item)])
            if let nativeLabel {
                language.level = Sourced(value: .native, spans: [nativeLabel.span], reading: .languageLevel)
            }
            var leftover: [Piece] = []
            for part in rest {
                if let level = level(in: part) {
                    language.level = level
                } else if let words = levelWordsPiece(part) {
                    if language.levelWords == nil { language.levelWords = words }
                } else {
                    leftover.append(part)
                }
            }
            if language.level != nil { language.levelWords = nil }
            findings.cv.languages.append(language)
            for part in leftover { findings.unplace(part, in: section) }
        }
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
        "hindi", "galician", "gallego", "galego", "basque", "euskera", "danish", "danese", "dänisch", "danés", "danois",
        "norwegian", "norvegese", "norwegisch", "noruego", "norvégien", "finnish", "finlandese", "finnisch", "finlandés", "finnois",
        "hungarian", "ungherese", "ungarisch", "húngaro", "hongrois", "czech", "ceco", "tschechisch", "checo", "tchèque",
        "croatian", "croato", "kroatisch", "croata", "croate", "serbian", "serbo", "serbisch", "serbio", "serbe",
    ].map(\.folded))

    // MARK: Levels

    /// A CEFR level, or the words of a native language, in a piece. Different CEFR levels give none.
    private static func level(in piece: Piece) -> Sourced<LanguageProficiency>? {
        if isNative(piece.text) {
            return Sourced(value: .native, spans: [piece.span], reading: .languageLevel)
        }
        let levels = cefrLevels(in: piece)
        guard let first = levels.first, levels.allSatisfy({ $0.1 == first.1 }) else { return nil }
        return Sourced(value: first.1, spans: [first.0.span], reading: .languageLevel)
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
    private static func attachLevel(_ piece: Piece, into findings: inout Findings) -> Bool {
        guard let last = findings.cv.languages.indices.last, findings.cv.languages[last].level == nil else { return false }
        let levels = cefrLevels(in: piece)
        if !levels.isEmpty {
            let rest = piece.removing(levels.map { range(of: $0.0, in: piece) })
            guard rest.allSatisfy({ levelWordsPiece($0) != nil }) else { return false }
            if levels.allSatisfy({ $0.1 == levels[0].1 }) {
                findings.cv.languages[last].level = Sourced(value: levels[0].1, spans: levels.map(\.0.span), reading: .languageLevel)
                findings.cv.languages[last].levelWords = nil
            } else {
                findings.cv.languages[last].levelWords = piece.quote(check: .levelsDiffer)
            }
            return true
        }
        if let words = levelWordsPiece(piece) {
            if let existing = findings.cv.languages[last].levelWords {
                findings.cv.languages[last].levelWords = Sourced(
                    value: existing.value + "\n" + words.value, spans: existing.spans + words.spans, check: .levelNotCEFR
                )
            } else {
                findings.cv.languages[last].levelWords = words
            }
            return true
        }
        return false
    }
}
