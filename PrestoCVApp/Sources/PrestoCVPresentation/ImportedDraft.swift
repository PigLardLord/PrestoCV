// What an import gives the screen (#396): the draft for the editor and what the person should check. The CV of the
// import goes into the draft and nowhere else; nothing here holds a domain or port type (R1, R5).

/// The draft an import gave: the editor's start, the review of what was read, and whether the CV can be saved.
public struct ImportedDraft: Sendable {
    /// Always a draft that nothing stored: the editor stores it the first time it writes it.
    public let start: EditorStart
    public let review: ImportReview
    /// Why the editor cannot store the CV as it is, or nil when it can.
    public let saving: SaveStatus?

    init(start: EditorStart, review: ImportReview, saving: SaveStatus?) {
        self.start = start; self.review = review; self.saving = saving
    }
}

/// What the person should check after an import: the values read by a guess, in the order the import gave them, and
/// the text that fits nowhere, whole and ready to copy.
public struct ImportReview: Hashable, Sendable {
    public let entries: [ReviewEntry]
    /// Empty when the import placed everything.
    public let notImported: String
    public let source: ImportSource

    init(entries: [ReviewEntry], notImported: String, source: ImportSource) {
        self.entries = entries; self.notImported = notImported; self.source = source
    }
}

/// A value to check: where it is, why, and the text as the person wrote it.
public struct ReviewEntry: Hashable, Sendable {
    public let field: ReviewedField
    public let reason: ReviewReason
    public let text: String

    init(field: ReviewedField, reason: ReviewReason, text: String) {
        self.field = field; self.reason = reason; self.text = text
    }
}

/// Where in the CV a value to check is. Entries are counted from one, as the person counts them on the screen.
public enum ReviewedField: Hashable, Sendable {
    case name, title, location, summary
    case experience(Int)
    case experiencePeriod(Int)
    case education(Int)
    case educationPeriod(Int)
    case educationLocation(Int)
    /// The position in the draft's languages.
    case language(Int)
    /// The n-th language of the text, which the draft does not hold; its words are in the text not imported.
    case languageNotKept(Int)
    case certificationYear(Int)
}

/// Why a value should be checked.
public enum ReviewReason: Hashable, Sendable, CaseIterable {
    case nameByPosition, titleByPosition, locationByPosition, summaryWithoutHeading
    case roleOrEmployerByOrder, entryBoundsUnsure
    /// The dates could not be made a period, such as an end before the start.
    case periodUnreadable
    /// The period has no end; the draft does not call it current.
    case periodOpenEnd
    /// A single date is no period; the draft keeps none.
    case periodNotARange
    /// The level is in words that are no CEFR level, so the draft does not hold it.
    case levelNotCEFR
    /// The text gives the language different levels, so the draft does not hold it.
    case levelsDiffer
    /// The text states no level for the language.
    case levelMissing
    /// The draft's education has no place; the text's place is in the text not imported.
    case locationNotKept
    /// The certification's year is no year the draft can hold.
    case yearUnreadable
}
