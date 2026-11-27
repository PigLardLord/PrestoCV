/// What an import produced: the CV it read, the values to check, the text it could not place and the noise it left
/// out, over the source document they all point into (ADR 0027).
public struct ImportResult: Hashable, Sendable {
    public let document: SourceDocument
    public internal(set) var cv: ImportedCV
    /// The language the CV is written in, told by the core's vocabulary; nil when it cannot tell.
    public let language: CVLanguage?
    /// Text that fits no field, in reading order.
    public internal(set) var unplaced: [UnplacedText]
    public let leftOut: [LeftOutText]
    /// The fields whose values the final gate refused, their text kept as text not imported. Always empty, unless a
    /// rule has a defect: the contract table requires it empty.
    public internal(set) var ungrounded: [String] = []

    package init(document: SourceDocument, cv: ImportedCV, language: CVLanguage?, unplaced: [UnplacedText], leftOut: [LeftOutText]) {
        self.document = document
        self.cv = cv
        self.language = language
        self.unplaced = unplaced
        self.leftOut = leftOut
    }

    /// The values the person should check, each with its reason, in the order of the CV.
    public var reviewList: [ReviewItem] { ReviewItem.items(of: cv) }
}

/// A value of an import the person should check.
public struct ReviewItem: Hashable, Sendable {
    public enum Field: Hashable, Sendable {
        case name, title, location, summary
        /// An experience entry, by its place in the list.
        case experience(Int)
        case experiencePeriod(Int)
        case education(Int)
        case educationPeriod(Int)
        case language(Int)
        /// A certification, by its place in the list.
        case certification(Int)
    }

    public let field: Field
    public let reason: CheckReason
    /// The value as the text states it.
    public let text: String

    static func items(of cv: ImportedCV) -> [ReviewItem] {
        var items: [ReviewItem] = []
        func add(_ field: Field, _ value: Sourced<String>?) {
            if let value, let reason = value.check { items.append(ReviewItem(field: field, reason: reason, text: value.value)) }
        }
        add(.name, cv.person.name)
        add(.title, cv.person.title)
        add(.location, cv.person.location)
        add(.summary, cv.person.summary)
        for (index, entry) in cv.experience.enumerated() {
            if let reason = entry.check {
                items.append(ReviewItem(field: .experience(index), reason: reason, text: [entry.role?.value, entry.employer?.value].compactMap { $0 }.joined(separator: " — ")))
            }
            add(.experience(index), entry.location)
            if let period = entry.period, let reason = period.check {
                items.append(ReviewItem(field: .experiencePeriod(index), reason: reason, text: [entry.role?.value, entry.employer?.value].compactMap { $0 }.joined(separator: " — ")))
            }
        }
        for (index, entry) in cv.education.enumerated() {
            if let reason = entry.check {
                items.append(ReviewItem(field: .education(index), reason: reason, text: [entry.degree?.value, entry.school?.value].compactMap { $0 }.joined(separator: " — ")))
            }
            add(.education(index), entry.location)
            if let period = entry.period, let reason = period.check {
                items.append(ReviewItem(field: .educationPeriod(index), reason: reason, text: [entry.degree?.value, entry.school?.value].compactMap { $0 }.joined(separator: " — ")))
            }
        }
        for (index, language) in cv.languages.enumerated() {
            if let words = language.levelWords, let reason = words.check {
                items.append(ReviewItem(field: .language(index), reason: reason, text: language.name.value + " — " + words.value))
            }
        }
        for (index, certification) in cv.certifications.enumerated() {
            if let reason = certification.check {
                items.append(ReviewItem(field: .certification(index), reason: reason, text: [certification.name.value, certification.issuer?.value].compactMap { $0 }.joined(separator: " — ")))
            }
        }
        return items
    }
}
