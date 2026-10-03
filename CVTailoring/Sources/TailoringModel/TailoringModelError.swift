/// Why a value of the tailoring model cannot be built. Every case is a code that names the place; the wording is
/// produced at the edges (R7, R13). Nothing here carries a string.
public enum TailoringModelError: Error, Hashable, Sendable {
    /// A language tag that is none of the six (ADR 0013). It never falls back to English.
    case unsupportedLanguage
    /// A field that must say something is empty, or only whitespace.
    case emptyField(Field)
    /// A text that must be one line holds a line break of any kind: a line feed, a carriage return, a vertical tab, a
    /// form feed, NEL, or the line and paragraph separators U+2028 and U+2029.
    case notOneLine(Field)
    /// A field that holds a character that hides what a text says (`TextRules`).
    case hiddenCharacter(Field)
    /// A field longer than `TailoringLimits.maxTextBytes`, or an advert longer than `TailoringLimits.maxAdvertBytes` (R8).
    case tooLarge(Field)
    /// A section with more entries than `TailoringLimits` allows (R8).
    case tooMany(Collection)
    /// A skill level outside 1 to 5.
    case invalidSkillLevel
    /// A question whose kind and scope disagree: a letter field asked about something else, or the letter asked about
    /// something that is not a letter field.
    case mismatchedScope
    /// A reference to an experience or a statement the snapshot does not have.
    case referenceOutOfRange
    /// A year outside 1900 to 2200, or a month outside 1 to 12.
    case invalidDate
    /// A period that ends before it starts.
    case invalidPeriod
    /// A word-list file the format cannot read (`docs/architecture/word-lists.md`): not JSON, an unsupported version, a
    /// key the format does not know, a list without its source or licence, an entry that is empty, hides a character,
    /// is not trimmed or repeated, a file that is too large, or an index that names a language with no file. The list is
    /// named when the fault is in one, and nil for a fault of the file: its version, its size, its JSON, a key at the top
    /// or in a group.
    case corruptWordList(WordListFile, WordListKey?)
    /// A word-list file that lacks a list the format requires, or holds a list with no entry, or no name for a month.
    case incompleteWordList(TailoringLanguage, WordListKey)

    /// The text fields of the model, by what they hold, not by which type holds them.
    public enum Field: CaseIterable, Hashable, Sendable {
        case fullName, professionalTitle, email, phone, location, website
        case skillName, languageName, platform, link
        case degree, school, certificationName, issuer, description
        case role, company, statement
        case summary, interest
        case contactName, title, surname, addressLine, reference, position, subject, opening, paragraph, closing, attachment
        case salaryExpectation, startDate, note, advert
        case argument, reportItem, term, request
    }

    /// The lists of the model, by what they hold, not by which type holds them.
    public enum Collection: Hashable, Sendable {
        case experiences, education, skills, languages, certifications, profiles, interests
        case statements, lines, sources
        case addressLines, paragraphs, attachments
        case cut, moved, reworded
    }
}
