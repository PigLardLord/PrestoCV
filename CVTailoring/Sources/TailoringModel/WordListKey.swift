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
    case spansEmployerEndWords = "spans.employerEndWords"
    case letterGreetings = "letter.greetings"
    case letterSalutations = "letter.salutations"
    case letterAddressees = "letter.addressees"
    case letterAddresseesAtClauseEnd = "letter.addresseesAtClauseEnd"
    case letterAddresseeNouns = "letter.addresseeNouns"
    case letterValedictions = "letter.valedictions"
    case letterSalaryExpectationAsks = "letter.salaryExpectationAsks"
    case letterStartDateAsks = "letter.startDateAsks"
    case letterStatedTermWords = "letter.statedTermWords"
    case letterFormsOfAddress = "letter.formsOfAddress"
    case letterAcademicTitles = "letter.academicTitles"
    case letterNotGivenNames = "letter.notGivenNames"
    case provenanceNotPlurals = "provenance.notPlurals"
    case provenanceLegalForms = "provenance.legalForms"
    case provenanceFirstPerson = "provenance.firstPerson"
    case provenanceRanks = "provenance.ranks"
    case fieldsTechnologies = "fields.technologies"

    /// Whether a language may leave the list with no entry. A list a language has no use for is empty and not missing:
    /// the three that only English fills today (`docs/architecture/word-lists.md`). Every other list must hold an entry,
    /// so a truncated file is refused as incomplete.
    var mayBeEmpty: Bool {
        switch self {
        case .letterAddresseesAtClauseEnd, .provenanceFirstPerson, .provenanceNotPlurals: true
        default: false
        }
    }

    /// The group of the file the list belongs to: `advert`, `dates`, `numbers`, `spans`, `letter`, `provenance` or `fields`.
    var group: String { String(rawValue.prefix { $0 != "." }) }

    /// The name of the list inside its group.
    var name: String { String(rawValue.drop { $0 != "." }.dropFirst()) }
}
