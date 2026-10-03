/// The checks the initialisers of the model share, so a bound is written once (R8).
enum Bounds {
    /// The one check of a text: its size first; then, for a one-line field, that it holds no line break of any kind
    /// (`Character.isNewline`, the rule `Statement` uses); then that it holds no hidden character (`TextRules`).
    static func text(_ value: String, _ field: TailoringModelError.Field,
                     maxBytes: Int = TailoringLimits.maxTextBytes) throws(TailoringModelError) {
        guard value.utf8.count <= maxBytes else { throw .tooLarge(field) }
        if !field.isMultiLine, value.contains(where: \.isNewline) { throw .notOneLine(field) }
        guard !TextRules.hiddenCharacter(in: value, multiLine: field.isMultiLine) else { throw .hiddenCharacter(field) }
    }

    /// An optional text is nil when it is absent, so a present one must say something.
    static func optionalText(_ value: String?, _ field: TailoringModelError.Field) throws(TailoringModelError) {
        if let value { try requiredText(value, field) }
    }

    /// Text that must say something: its size is checked first, then that it holds a character that shows, and then
    /// the check of `text`. So a blank text is empty whatever its controls. The value itself is kept as written.
    static func requiredText(_ value: String, _ field: TailoringModelError.Field,
                             maxBytes: Int = TailoringLimits.maxTextBytes) throws(TailoringModelError) {
        guard value.utf8.count <= maxBytes else { throw .tooLarge(field) }
        guard value.contains(where: { !isBlank($0) }) else { throw .emptyField(field) }
        try text(value, field, maxBytes: maxBytes)
    }

    // MARK: Blank and trimmed

    /// A character that shows nothing: made only of whitespace scalars, or of default-ignorable ones (a zero-width
    /// space, a byte order mark, a word joiner). A space that carries a combining mark is not blank: the mark shows.
    static func isBlank(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { $0.properties.isWhitespace || $0.properties.isDefaultIgnorableCodePoint }
    }

    /// A character made only of whitespace scalars, so nothing of it is left behind when it is taken away.
    static func isSpace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { $0.properties.isWhitespace }
    }

    /// The text without the blank characters at either end. It is the one rule of trimming: statements, the split and
    /// every check that needs text to say something use it.
    static func trimmed(_ text: Substring) -> Substring {
        guard let first = text.firstIndex(where: { !isBlank($0) }), let last = text.lastIndex(where: { !isBlank($0) }) else { return "" }
        return text[first...last]
    }

    static func texts(_ values: [String], _ field: TailoringModelError.Field, atMost limit: Int,
                      _ collection: TailoringModelError.Collection) throws(TailoringModelError) {
        try count(values.count, atMost: limit, collection)
        for value in values { try text(value, field) }
    }

    static func count(_ count: Int, atMost limit: Int, _ collection: TailoringModelError.Collection) throws(TailoringModelError) {
        guard count <= limit else { throw .tooMany(collection) }
    }

    /// What a source CV and a tailored CV hold alike: the summary, and the sections an experience is not part of.
    static func cvSections(summary: String, education: [SourceEducation], skills: [SourceSkill], languages: [SourceLanguage],
                           certifications: [SourceCertification], profiles: [SourceProfile],
                           interests: [String]) throws(TailoringModelError) {
        try text(summary, .summary)
        try count(education.count, atMost: TailoringLimits.maxEntriesPerSection, .education)
        try count(skills.count, atMost: TailoringLimits.maxEntriesPerSection, .skills)
        try count(languages.count, atMost: TailoringLimits.maxEntriesPerSection, .languages)
        try count(certifications.count, atMost: TailoringLimits.maxEntriesPerSection, .certifications)
        try count(profiles.count, atMost: TailoringLimits.maxEntriesPerSection, .profiles)
        try count(interests.count, atMost: TailoringLimits.maxEntriesPerSection, .interests)
        for interest in interests { try text(interest, .interest) }
    }
}

extension TailoringModelError.Field {
    /// Whether a text of this field may hold line breaks and tabs (`TextRules`): a description, the summary, the advert
    /// and the letter note. A statement is a line of a description: a tab is allowed in it, and its breaks are refused
    /// by `Statement` itself as `notOneLine`.
    var isMultiLine: Bool {
        switch self {
        case .description, .summary, .advert, .note, .statement: true
        default: false
        }
    }
}
