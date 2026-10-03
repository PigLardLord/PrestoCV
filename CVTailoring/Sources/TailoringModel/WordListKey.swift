/// One of the files of the word lists (ADR 0013): the index of the languages, or the file of one language.
public enum WordListFile: Hashable, Sendable {
    case index
    case language(TailoringLanguage)
}

/// A list of a language's word-list file, named by its place in the file: the group and the list, joined by a dot.
/// Every file holds each of these lists, and no other (`docs/architecture/word-lists.md`).
public enum WordListKey: String, CaseIterable, Hashable, Sendable {
    case advertStopwords = "advert.stopwords"
    case advertPlainWords = "advert.plainWords"
    case advertDimensions = "advert.dimensions"
    case advertBoilerplate = "advert.boilerplate"
    case advertGenderMarkers = "advert.genderMarkers"
    case advertInstructions = "advert.instructions"
    case advertStreets = "advert.streets"
    case advertNames = "advert.names"
    case advertSynonyms = "advert.synonyms"
    case advertRequirementHeadings = "advert.requirementHeadings"
    case advertOfferHeadings = "advert.offerHeadings"
    case advertStructuralHeadings = "advert.structuralHeadings"
    case datesMonths = "dates.months"
    case datesPresentWords = "dates.presentWords"
    case datesSinceWords = "dates.sinceWords"
    case datesRangeSeparatorWords = "dates.rangeSeparatorWords"
    case datesDurationUnitWords = "dates.durationUnitWords"
    case numbersWords = "numbers.words"
    case spansFloorLeadIns = "spans.floorLeadIns"
    case spansYearWords = "spans.yearWords"
    case spansMonthWords = "spans.monthWords"
    case spansCountWords = "spans.countWords"
    case spansTiedCounts = "spans.tiedCounts"
    case letterGreetings = "letter.greetings"
    case letterSalutations = "letter.salutations"
    case letterAddressees = "letter.addressees"
    case letterAddresseeNouns = "letter.addresseeNouns"
    case letterValedictions = "letter.valedictions"
    case letterSalaryExpectationAsks = "letter.salaryExpectationAsks"
    case letterStartDateAsks = "letter.startDateAsks"
    case letterStatedTermWords = "letter.statedTermWords"
    case fieldsTechnologies = "fields.technologies"

    /// The group of the file the list belongs to: `advert`, `dates`, `numbers`, `spans`, `letter` or `fields`.
    var group: String { String(rawValue.prefix { $0 != "." }) }

    /// The name of the list inside its group.
    var name: String { String(rawValue.drop { $0 != "." }.dropFirst()) }
}
