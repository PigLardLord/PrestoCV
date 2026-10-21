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

    init(value: Value, spans: [SourceSpan], reading: ReadingRule? = nil, check: CheckReason? = nil) {
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
public enum CheckReason: String, Hashable, Sendable {
    /// The name was taken from its place at the top, with no label or mark that says it is the name.
    case nameByPosition
    /// The professional title was taken from its place under the name.
    case titleByPosition
    /// The place was taken from its place among the contacts, with no label.
    case locationByPosition
    /// The summary was taken from prose at the top, under no heading.
    case summaryWithoutHeading
    /// Nothing told the role from the employer: the CV's own order did.
    case roleOrEmployerByOrder
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
    /// The words that give a level the rules do not read as CEFR: "fluent", "buono", "Professional working".
    public var levelWords: Sourced<String>?
}

public struct ImportedCertification: Hashable, Sendable {
    public var name: Sourced<String>
    public var issuer: Sourced<String>?
    public var year: Sourced<Int>?
    /// The web address the text gives for the certification, in its line or under it.
    public var link: Sourced<WebLink>?
    /// The lines under the certification that tell what it is, in order.
    public var description: Sourced<String>?
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
