public import PrestoCVDomain

// MARK: - A value with its evidence

/// A value of an import with the spans of the source it was quoted from (ADR 0027). A value is the text of its spans,
/// or, when `reading` names a rule, what that closed rule read in them. The import never writes a value of its own.
public struct Sourced<Value: Hashable & Sendable>: Hashable, Sendable {
    public let value: Value
    public let spans: [SourceSpan]
    /// The closed rule that read the value in its spans; nil when the value is their text.
    public let reading: ReadingRule?
    /// Why the person should check the value; nil when the rules are sure of it.
    public internal(set) var check: CheckReason?

    package init(value: Value, spans: [SourceSpan], reading: ReadingRule? = nil, check: CheckReason? = nil) {
        self.value = value
        self.spans = spans
        self.reading = reading
        self.check = check
    }
}

/// The closed rules that read a value in the text.
public enum ReadingRule: String, Hashable, Sendable {
    /// A date or a period, by `DateReader`.
    case period
    /// A CEFR level, or a native language.
    case languageLevel
    /// A web address written without its scheme, read as an https address.
    case webAddress
    /// The year of a date.
    case year
}

/// Why a value of an import should be checked by the person.
public enum CheckReason: String, Hashable, Sendable, CaseIterable {
    /// The name was taken from its place at the top, with no label or mark that says it is the name, or a heading that
    /// closed the head could have been it.
    case nameByPosition
    /// The professional title was taken from its place under the name.
    case titleByPosition
    /// The place was taken from its place among the contacts, with no label; or an entry's place was kept whole, as no
    /// rule told where it starts.
    case locationByPosition
    /// The summary was taken from prose at the top, under no heading.
    case summaryWithoutHeading
    /// Nothing told the role from the employer: the CV's own order did.
    case roleOrEmployerByOrder
    /// Nothing in the section told whether the lines next to the entry's dates are its own or the entry's beside it:
    /// the more common layout decided.
    case entryBoundsUnsure
    /// A date the rules could not make a period of, such as an end before the start.
    case periodUnreadable
    /// A period without an end: "2019 –".
    case periodOpenEnd
    /// A language's level in words that are no CEFR level, such as "fluent" or "buono".
    case levelNotCEFR
    /// A Europass grid that gives the language different levels.
    case levelsDiffer
}

// MARK: - The imported CV

/// What an import read, every value with its evidence. The app maps it to a CV the person reviews before saving it.
public struct ImportedCV: Hashable, Sendable {
    public var person = ImportedPerson()
    public var experience: [ImportedExperience] = []
    public var education: [ImportedEducation] = []
    public var skills: [Sourced<String>] = []
    public var languages: [ImportedLanguage] = []
    public var certifications: [ImportedCertification] = []
    public var interests: [Sourced<String>] = []

    public init() {}
}

public struct ImportedPerson: Hashable, Sendable {
    public var name: Sourced<String>?
    public var title: Sourced<String>?
    public var email: Sourced<EmailAddress>?
    public var phone: Sourced<PhoneNumber>?
    public var location: Sourced<String>?
    public var links: [ImportedLink] = []
    public var summary: Sourced<String>?

    public init() {}
}

/// A web address of the person, and what it is.
public struct ImportedLink: Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case linkedIn, gitHub, xing, website
    }

    public let address: Sourced<WebLink>
    public let kind: Kind
}

public struct ImportedExperience: Hashable, Sendable {
    public var role: Sourced<String>?
    public var employer: Sourced<String>?
    public var location: Sourced<String>?
    public var period: Sourced<ImportedPeriod>?
    /// The lines under the entry: its bullets and its prose, in order.
    public var details: [Sourced<String>] = []
    /// Why the person should check the entry as a whole.
    public var check: CheckReason?
}

public struct ImportedEducation: Hashable, Sendable {
    public var degree: Sourced<String>?
    public var school: Sourced<String>?
    public var location: Sourced<String>?
    public var period: Sourced<ImportedPeriod>?
    public var details: [Sourced<String>] = []
    public var check: CheckReason?
}

public struct ImportedLanguage: Hashable, Sendable {
    public var name: Sourced<String>
    /// Only a CEFR level, or a native language, that the text states.
    public var level: Sourced<LanguageProficiency>?
    /// The words that give a level the rules do not read as CEFR: "fluent", "buono", "Professional working". Only
    /// when the language has no level: words beside a level are text not imported.
    public var levelWords: Sourced<String>?
    /// The heading of the section the language stands in, as the CV writes it; nil when the section has none. A language
    /// the CV cannot take is shown under it, where the CV wrote it (#452).
    public var heading: String?
}

public struct ImportedCertification: Hashable, Sendable {
    public var name: Sourced<String>
    public var issuer: Sourced<String>?
    public var year: Sourced<Int>?
}

// MARK: - What was not imported

/// Text that fits no field. It is shown to the person, ready to copy, never dropped (ADR 0027).
public struct UnplacedText: Hashable, Sendable {
    /// The section it was in, and its heading's text.
    public let section: SectionKind
    public let heading: String?
    public let text: String
    public let span: SourceSpan
}

/// A value of an imported CV with its place in the CV: `experience[0].role`. The trace of a test build lists them
/// (ADR 0032); the grounding counts their spans; the app's mirror-completeness test walks them.
public struct ImportedField: Hashable, Sendable {
    public let path: String
    /// The value as text: the quoted text, or what a reading rule read in it.
    public let value: String
    public let spans: [SourceSpan]
    public let reading: ReadingRule?
    public let check: CheckReason?
}

extension ImportedCV {
    /// The spans of every value of the CV. A test compares them with the spans found by walking the CV.
    var sourceSpans: [SourceSpan] { fields.flatMap(\.spans) }

    /// Every value of the CV, in the order of the CV, and the checks of whole entries. A new field of the CV joins this
    /// list.
    public var fields: [ImportedField] {
        var fields: [ImportedField] = []
        func add<Value>(_ path: String, _ value: Sourced<Value>?, as text: (Value) -> String) {
            guard let value else { return }
            fields.append(ImportedField(path: path, value: text(value.value), spans: value.spans, reading: value.reading, check: value.check))
        }
        func add(_ path: String, _ value: Sourced<String>?) { add(path, value, as: { $0 }) }
        func addCheck(_ path: String, _ check: CheckReason?) {
            guard let check else { return }
            fields.append(ImportedField(path: path, value: check.rawValue, spans: [], reading: nil, check: check))
        }
        add("person.name", person.name)
        add("person.title", person.title)
        add("person.email", person.email, as: \.value)
        add("person.phone", person.phone, as: \.value)
        add("person.location", person.location)
        add("person.summary", person.summary)
        for (index, link) in person.links.enumerated() { add("person.links[\(index)].\(link.kind.rawValue)", link.address, as: \.value) }
        for (index, entry) in experience.enumerated() {
            let path = "experience[\(index)]"
            addCheck(path + ".check", entry.check)
            add(path + ".role", entry.role)
            add(path + ".employer", entry.employer)
            add(path + ".location", entry.location)
            add(path + ".period", entry.period, as: \.traceText)
            for (line, detail) in entry.details.enumerated() { add(path + ".details[\(line)]", detail) }
        }
        for (index, entry) in education.enumerated() {
            let path = "education[\(index)]"
            addCheck(path + ".check", entry.check)
            add(path + ".degree", entry.degree)
            add(path + ".school", entry.school)
            add(path + ".location", entry.location)
            add(path + ".period", entry.period, as: \.traceText)
            for (line, detail) in entry.details.enumerated() { add(path + ".details[\(line)]", detail) }
        }
        for (index, skill) in skills.enumerated() { add("skills[\(index)]", skill) }
        for (index, language) in languages.enumerated() {
            add("languages[\(index)].name", language.name)
            add("languages[\(index)].level", language.level, as: \.rawValue)
            add("languages[\(index)].levelWords", language.levelWords)
        }
        for (index, certification) in certifications.enumerated() {
            add("certifications[\(index)].name", certification.name)
            add("certifications[\(index)].issuer", certification.issuer)
            add("certifications[\(index)].year", certification.year, as: String.init)
        }
        for (index, interest) in interests.enumerated() { add("interests[\(index)]", interest) }
        return fields
    }
}

extension ImportedPeriod {
    /// The period as a script reads it: `2019-03 – current`, `2015`.
    var traceText: String {
        func text(_ date: YearMonth) -> String {
            guard let month = date.month else { return String(date.year) }
            return "\(date.year)-\(month < 10 ? "0" : "")\(month)"
        }
        switch end {
        case nil: return text(start)
        case .date(let date): return text(start) + " – " + text(date)
        case .current: return text(start) + " – current"
        case .unstated: return text(start) + " –"
        }
    }
}

// MARK: - Construction for tests

// Inside the package only: a test support target builds imports that no reader read, so that the app's tests can script
// one. Nothing outside the package can make a value without its evidence.
extension ImportedLink {
    package static func scripted(_ kind: Kind, _ address: Sourced<WebLink>) -> ImportedLink { ImportedLink(address: address, kind: kind) }
}

extension ImportedExperience {
    package static func scripted(role: Sourced<String>?, employer: Sourced<String>?, location: Sourced<String>?,
                                 period: Sourced<ImportedPeriod>?, details: [Sourced<String>], check: CheckReason?) -> ImportedExperience {
        ImportedExperience(role: role, employer: employer, location: location, period: period, details: details, check: check)
    }
}

extension ImportedEducation {
    package static func scripted(degree: Sourced<String>?, school: Sourced<String>?, location: Sourced<String>?,
                                 period: Sourced<ImportedPeriod>?, details: [Sourced<String>], check: CheckReason?) -> ImportedEducation {
        ImportedEducation(degree: degree, school: school, location: location, period: period, details: details, check: check)
    }
}

extension ImportedLanguage {
    package static func scripted(
        _ name: Sourced<String>, level: Sourced<LanguageProficiency>?, levelWords: Sourced<String>?, heading: String? = nil
    ) -> ImportedLanguage {
        ImportedLanguage(name: name, level: level, levelWords: levelWords, heading: heading)
    }
}

extension ImportedCertification {
    package static func scripted(_ name: Sourced<String>, issuer: Sourced<String>?, year: Sourced<Int>?) -> ImportedCertification {
        ImportedCertification(name: name, issuer: issuer, year: year)
    }
}

extension UnplacedText {
    package static func scripted(section: SectionKind, heading: String?, text: String, span: SourceSpan) -> UnplacedText {
        UnplacedText(section: section, heading: heading, text: text, span: span)
    }
}
