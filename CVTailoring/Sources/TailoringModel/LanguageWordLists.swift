/// A list of one language's words, with where it comes from and under which licence (ADR 0013). Every list of a file
/// states both, so a list is never anonymous and a licence is never assumed.
public struct WordList<Entry: Hashable & Sendable>: Hashable, Sendable {
    /// Where the entries come from, as free text: a repository, a commit, the list inside it.
    public let source: String
    /// The SPDX identifier of the licence the entries are under.
    public let licence: String
    public let entries: [Entry]
}

/// A month name or abbreviation as a CV writes it, with its month, 1 to 12.
public struct MonthName: Hashable, Sendable {
    public let name: String
    public let month: Int
}

/// A number written in words, with its value.
public struct NumberWord: Hashable, Sendable {
    public let word: String
    public let value: Int
}

/// Forms that mean the same thing, as a term and its other spellings: "ci/cd" and "continuous integration".
public struct SynonymGroup: Hashable, Sendable {
    public let forms: [String]
}

/// Where a language writes the word of a street in an address.
public enum StreetOrder: String, CaseIterable, Hashable, Sendable {
    /// Joined to the name, or after an adjective of the town: "Hauptstraße 1", "Frankfurter Str. 5".
    case joined
    /// After the name, with the number first: "221B Baker Street".
    case after
    /// Before the name, with the number last: "Via Roma 1".
    case before
}

/// The words a street's name carries, and where the language writes them.
public struct StreetWords: Hashable, Sendable {
    public let list: WordList<String>
    public let order: StreetOrder
}

/// What an advert says that is not about the job, and how it names its sections.
public struct AdvertWords: Hashable, Sendable {
    /// Words that carry no information about a role, however often they appear.
    public let stopwords: WordList<String>
    /// Words of an advert's prose that a tailoring may write although the CV does not, and the ranking still counts.
    public let plainWords: WordList<String>
    /// Nouns that name what a claim measures: "performance", "stability".
    public let dimensions: WordList<String>
    /// Phrases that belong to the posting and not to the job: "equal opportunity", "full time".
    public let boilerplate: WordList<String>
    /// Gender markers a job title carries in words: "all genders".
    public let genderMarkers: WordList<String>
    /// What an advert asks of the applicant and not of the job: "please state", "notice period".
    public let instructions: WordList<String>
    public let streets: StreetWords
    /// Names written in several words that are read whole: "github actions", "time series".
    public let names: WordList<String>
    public let synonyms: WordList<SynonymGroup>
    /// Headings under which an advert states what it will not compromise on.
    public let requirementHeadings: WordList<String>
    /// Headings under which an advert talks about itself: what it offers, who it is.
    public let offerHeadings: WordList<String>
    /// Headings that organise an advert without demanding or offering anything: "tech stack".
    public let structuralHeadings: WordList<String>
}

/// The month names of a language, and the words of a period written in text.
public struct DateWords: Hashable, Sendable {
    public let months: WordList<MonthName>
    /// How a period says it has not ended: "present", "ongoing".
    public let presentWords: WordList<String>
    /// How a period says it began and has not ended, before its start: "since".
    public let sinceWords: WordList<String>
    /// The words that stand between the two dates of a period: "to".
    public let rangeSeparatorWords: WordList<String>
    /// The units of the length a period may carry after its dates: "years", "mos".
    public let durationUnitWords: WordList<String>
}

/// The numbers a language writes in words.
public struct NumberWords: Hashable, Sendable {
    public let words: WordList<NumberWord>
}

/// How a language states a span of time: a floor, a count tied to a role.
public struct SpanWords: Hashable, Sendable {
    /// What opens a floor before its count: "over", "more than", "at least".
    public let floorLeadIns: WordList<String>
    public let yearWords: WordList<String>
    public let monthWords: WordList<String>
    /// The counts written in words, as far as a CV ever writes one.
    public let countWords: WordList<NumberWord>
    /// How a count is tied to an employer, with `{count}` and `{employer}`: "{count} of them at {employer}".
    public let tiedCounts: WordList<String>
}

/// How a letter greets, closes, and how an advert asks it for a figure.
public struct LetterWords: Hashable, Sendable {
    /// The words that open a salutation, before whom it greets: "dear", "hello".
    public let greetings: WordList<String>
    /// Salutations that stand on their own: "to whom it may concern".
    public let salutations: WordList<String>
    /// The words that, after a greeting, make it a salutation: forms of address, titles, groups.
    public let addressees: WordList<String>
    /// The nouns an addressee ends in, up to two words after a greeting: "team", "manager".
    public let addresseeNouns: WordList<String>
    /// How a letter signs off: "kind regards", "yours sincerely".
    public let valedictions: WordList<String>
    /// How an advert asks for a salary expectation: "salary expectations", "desired salary".
    public let salaryExpectationAsks: WordList<String>
    /// How an advert asks for a start date: "earliest start date", "notice period".
    public let startDateAsks: WordList<String>
    /// Words right after an ask that show the advert states its own term and asks nothing: "is", "of".
    public let statedTermWords: WordList<String>
}

/// Every word list of one language (ADR 0013), validated when it was read (R8). Only the decoder makes one, so a value
/// of this type always holds every list, each with its source and its licence.
public struct LanguageWordLists: Hashable, Sendable {
    public let language: TailoringLanguage
    public let advert: AdvertWords
    public let dates: DateWords
    public let numbers: NumberWords
    public let spans: SpanWords
    public let letter: LetterWords
    /// The names of technologies that are never ordinary words of the language, so a mention is held to the source
    /// however it is written. Read from `fields.technologies`.
    public let technologies: WordList<String>
}
