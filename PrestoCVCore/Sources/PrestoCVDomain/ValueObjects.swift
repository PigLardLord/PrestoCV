import Foundation   // value types only (PureCore): UUID and Date as types, never UUID() / Date()

// MARK: - Identity

/// The identity of a CV. A type of its own, so that no other identifier can be passed where a CV's is expected.
public struct CVID: Hashable, Sendable, Codable {
    public let raw: UUID
    public init(_ raw: UUID) { self.raw = raw }
}

// MARK: - Dates and periods

/// Year, or year and month. Only a partial order exists between dates of different precision.
public struct PartialDate: Hashable, Sendable {
    public let year: Int, month: Int?

    /// Returns `nil` when the year is outside 1900...2200, or the month, if given, is outside 1...12.
    public init?(year: Int, month: Int? = nil) {
        guard (1900...2200).contains(year), month.map({ (1...12).contains($0) }) ?? true else { return nil }
        self.year = year; self.month = month
    }

    /// Whether this date is not after `other`. Months are compared only when both are known, so "May 2020" is not after "2020".
    public func isNotAfter(_ other: PartialDate) -> Bool {
        if year != other.year { return year < other.year }
        guard let month, let otherMonth = other.month else { return true }
        return month <= otherMonth
    }
}

/// `.unknown` means the period has ended but its end date was not given; it is never invented.
public enum PeriodEnd: Hashable, Sendable { case current, date(PartialDate), unknown }

/// Why loose data is not a valid period.
public enum PeriodError: Error, Equatable, Sendable {
    case invalidDate, endWithoutStart, currentWithoutStart, currentWithEndDate, endBeforeStart
}

/// A span of time that starts at a date and ends at a date, is still current, or has ended on an unknown date.
public struct Period: Hashable, Sendable {
    public let start: PartialDate, end: PeriodEnd

    /// Returns `nil` when the end is a date before the start.
    public init?(start: PartialDate, end: PeriodEnd) {
        if case .date(let endDate) = end, !start.isNotAfter(endDate) { return nil }
        self.start = start; self.end = end
    }

    /// The single rule for building a period from loose data (persistence, AI drafts): every
    /// combination is either a valid period, no period, or a typed error. Nothing is defaulted (RichDomain).
    ///
    /// - Parameters:
    ///   - start: The year, and month if known, the period began.
    ///   - end: The year, and month if known, it ended.
    ///   - current: Whether it is still going on.
    /// - Returns: The period, or `nil` when there is no start, no end and the period is not current.
    /// - Throws: `PeriodError` when a date is not valid, an end or `current` has no start, `current` comes with an end, or the
    ///   end is before the start.
    public static func make(start: (year: Int, month: Int?)?, end: (year: Int, month: Int?)?, current: Bool) throws(PeriodError) -> Period? {
        func date(_ parts: (year: Int, month: Int?)) throws(PeriodError) -> PartialDate {
            guard let date = PartialDate(year: parts.year, month: parts.month) else { throw .invalidDate }
            return date
        }
        switch (start, end, current) {
        case (nil, nil, false): return nil
        case (nil, nil, true): throw .currentWithoutStart
        case (nil, .some(let endParts), _): _ = try date(endParts); throw .endWithoutStart
        case (.some, .some, true): throw .currentWithEndDate
        case (.some(let startParts), nil, true): return Period(start: try date(startParts), end: .current)
        case (.some(let startParts), nil, false): return Period(start: try date(startParts), end: .unknown)
        case (.some(let startParts), .some(let endParts), false):
            guard let period = Period(start: try date(startParts), end: .date(try date(endParts))) else { throw .endBeforeStart }
            return period
        }
    }
}

// MARK: - Levels

/// Bounded value object: invalid levels cannot exist (RichDomain).
public struct SkillLevel: Hashable, Sendable {
    public let value: Int

    /// Returns `nil` unless `value` is in 1...5.
    public init?(_ value: Int) { guard (1...5).contains(value) else { return nil }; self.value = value }
}

/// The CEFR levels, plus native. Its display name belongs to presentation (LocalisationAtEdges).
public enum LanguageProficiency: String, CaseIterable, Hashable, Sendable {
    case a1, a2, b1, b2, c1, c2, native
}

// MARK: - Contact details

/// A local part of dot-separated atoms (no leading, trailing or doubled dot) and a domain of labels (letters or
/// digits, inner hyphens, 1–63 characters each) ending in an alphabetic top-level label. Internationalised letters
/// are allowed, with the combining marks that follow them (Indic vowel signs, decomposed accents); control, format
/// and separator characters (NUL, zero-width space, bidirectional overrides) are not, since they can hide or disguise
/// what is printed. No atom or label starts with a mark.
public struct EmailAddress: Hashable, Sendable {
    public let value: String
    private static let atom = #"[\p{L}\p{N}!#$%&'*+/=?^_`{|}~-][\p{L}\p{M}\p{N}!#$%&'*+/=?^_`{|}~-]*"#
    private static let label = #"[\p{L}\p{N}](?:[\p{L}\p{M}\p{N}-]{0,61}[\p{L}\p{M}\p{N}])?"#
    private static let topLevel = #"(?:\p{L}\p{M}*){2,63}"#   // two to 63 letters, each with its marks
    private static let pattern = "^" + atom + #"(?:\."# + atom + ")*@(?:" + label + #"\.)+"# + topLevel + #"\z"#
    private static let hiddenCategories: Set<Unicode.GeneralCategory> = [.control, .format, .lineSeparator, .paragraphSeparator,
                                                                         .spaceSeparator, .privateUse, .surrogate, .unassigned]
    private static let maxBytes = 254, maxLocalPartBytes = 64, maxLabelCharacters = 63

    /// Returns `nil` when the trimmed text is not an address in the form above.
    public init?(_ raw: String) {
        let address = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isShortAndVisible(address), Self.matchesPattern(address), Self.isWithinPartLimits(address) else { return nil }
        value = address
    }

    private static func isShortAndVisible(_ address: String) -> Bool {
        address.utf8.count <= maxBytes && !address.unicodeScalars.contains { hiddenCategories.contains($0.properties.generalCategory) }
    }

    private static func matchesPattern(_ address: String) -> Bool { address.range(of: pattern, options: .regularExpression) != nil }

    /// The limits the pattern cannot express once marks are allowed: the local part in bytes, and each domain label in
    /// characters, marks included. The exact IDNA length is not checked.
    private static func isWithinPartLimits(_ address: String) -> Bool {
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && parts[0].utf8.count <= maxLocalPartBytes
            && parts[1].split(separator: ".").allSatisfy { $0.unicodeScalars.count <= maxLabelCharacters }
    }
}

/// A phone number as written: digits with the usual separators, and at least three digits.
public struct PhoneNumber: Hashable, Sendable {
    public let value: String

    /// Returns `nil` when the trimmed text is not 3 to 32 characters of digits and separators with at least three digits.
    public init?(_ raw: String) {
        let number = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...32).contains(number.count),
              number.range(of: #"^\+?[0-9 ()./-]+\z"#, options: .regularExpression) != nil,
              number.filter(\.isASCIIDigit).count >= 3 else { return nil }
        value = number
    }
}

/// An http or https address with a host, no credentials and the scheme's default port (ValidatingBoundary). Kept in the form
/// the parser serialises, never as the raw input.
public struct WebLink: Hashable, Sendable {
    public let value: String
    private static let maxBytes = 2048
    private static let defaultPorts = ["https": 443, "http": 80]

    /// Returns `nil` unless the trimmed text is such an address, at most 2048 bytes of printable ASCII once serialised.
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isPlainASCII(trimmed), let components = URLComponents(string: trimmed), Self.isWebAddress(components),
              let serialized = Self.stableSerialization(of: components) else { return nil }
        value = serialized
    }

    private static func isPlainASCII(_ text: String) -> Bool {
        text.utf8.count <= maxBytes && text.unicodeScalars.allSatisfy(isPlainScalar)
    }

    /// Printable ASCII, and no backslash, which some parsers read as a slash.
    private static func isPlainScalar(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isASCII && scalar.value > 0x20 && scalar.value != 0x7F && scalar != "\\"
    }

    private static func isWebAddress(_ components: URLComponents) -> Bool {
        guard let defaultPort = defaultPort(of: components), let host = components.host else { return false }
        return isHostName(host) && hasNoCredentials(components) && [nil, defaultPort].contains(components.port)
    }

    /// The port the scheme uses unless another is written; `nil` for a scheme that is neither http nor https.
    private static func defaultPort(of components: URLComponents) -> Int? {
        components.scheme.flatMap { defaultPorts[$0.lowercased()] }
    }

    /// What the parser makes of the components, when that text is plain and parsing it again gives the same text: the
    /// value rebuilds itself.
    private static func stableSerialization(of components: URLComponents) -> String? {
        guard let text = components.string, isPlainASCII(text), URLComponents(string: text)?.string == text else { return nil }
        return text
    }

    private static func isHostName(_ host: String) -> Bool { host.range(of: #"^[A-Za-z0-9.-]{1,253}\z"#, options: .regularExpression) != nil }

    private static func hasNoCredentials(_ components: URLComponents) -> Bool { components.user == nil && components.password == nil }
}

// MARK: - The document

/// The language a CV is written in, as a BCP 47 tag: a language, an optional script and an optional region
/// ("it", "pt-BR", "zh-Hant-TW"). Stored in canonical case.
public struct DocumentLanguage: Hashable, Sendable {
    public let tag: String

    /// Returns `nil` when the trimmed text is not a language with at most a script and a region.
    public init?(_ raw: String) {
        let subtags = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "-", omittingEmptySubsequences: false)
        guard let tag = Self.canonicalTag(of: subtags) else { return nil }
        self.tag = tag
    }

    private static func canonicalTag(of subtags: [Substring]) -> String? {
        guard let first = subtags.first, let language = language(first) else { return nil }
        var canonical = [language]
        var rest = subtags.dropFirst()
        if let script = rest.first.flatMap(script) { canonical.append(script); rest = rest.dropFirst() }
        if let region = rest.first.flatMap(region) { canonical.append(region); rest = rest.dropFirst() }
        return rest.isEmpty ? canonical.joined(separator: "-") : nil
    }

    /// Two or three letters, in lower case.
    private static func language(_ subtag: Substring) -> String? {
        (2...3).contains(subtag.count) && subtag.allSatisfy(\.isASCIILetter) ? subtag.lowercased() : nil
    }

    /// Four letters, the first in upper case.
    private static func script(_ subtag: Substring) -> String? {
        subtag.count == 4 && subtag.allSatisfy(\.isASCIILetter) ? subtag.prefix(1).uppercased() + subtag.dropFirst().lowercased() : nil
    }

    /// Two letters, in upper case, or three digits.
    private static func region(_ subtag: Substring) -> String? {
        if subtag.count == 2, subtag.allSatisfy(\.isASCIILetter) { return subtag.uppercased() }
        return subtag.count == 3 && subtag.allSatisfy(\.isASCIIDigit) ? String(subtag) : nil
    }
}

/// The design a CV is exported with, by identifier: the design, and optionally a palette and a font scheme.
/// The catalog resolves them; an identifier it does not know falls back to the design's defaults.
public struct DesignChoice: Hashable, Sendable {
    public let design: String, palette: String?, fonts: String?

    /// Returns `nil` unless every identifier given is 1 to 64 lower-case letters, digits or hyphens.
    public init?(design: String, palette: String? = nil, fonts: String? = nil) {
        func isIdentifier(_ id: String) -> Bool { id.range(of: #"^[a-z0-9-]{1,64}\z"#, options: .regularExpression) != nil }
        guard isIdentifier(design), palette.map(isIdentifier) ?? true, fonts.map(isIdentifier) ?? true else { return nil }
        self.design = design; self.palette = palette; self.fonts = fonts
    }
}

extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
    var isASCIILetter: Bool { isASCII && isLetter }
}
