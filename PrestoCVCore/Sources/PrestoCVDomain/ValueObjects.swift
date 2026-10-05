import Foundation   // value types only (PureCore): UUID and Date as types, never UUID() / Date()

// MARK: - Identity

public struct CVID: Hashable, Sendable, Codable {
    public let raw: UUID
    public init(_ raw: UUID) { self.raw = raw }
}

// MARK: - Dates and periods

/// Year, or year and month. Only a partial order exists between dates of different precision.
public struct PartialDate: Hashable, Sendable {
    public let year: Int, month: Int?
    public init?(year: Int, month: Int? = nil) {
        guard (1900...2200).contains(year), month.map({ (1...12).contains($0) }) ?? true else { return nil }
        self.year = year; self.month = month
    }
    /// "May 2020 – 2020" is ordered: months are compared only when both are known.
    public func isNotAfter(_ other: PartialDate) -> Bool {
        if year != other.year { return year < other.year }
        guard let a = month, let b = other.month else { return true }
        return a <= b
    }
}

/// `.unknown` means the period has ended but its end date was not given; it is never invented.
public enum PeriodEnd: Hashable, Sendable { case current, date(PartialDate), unknown }

public enum PeriodError: Error, Equatable, Sendable {
    case invalidDate, endWithoutStart, currentWithoutStart, currentWithEndDate, endBeforeStart
}

public struct Period: Hashable, Sendable {
    public let start: PartialDate, end: PeriodEnd
    public init?(start: PartialDate, end: PeriodEnd) {
        if case .date(let e) = end, !start.isNotAfter(e) { return nil }
        self.start = start; self.end = end
    }

    /// The single rule for building a period from loose data (persistence, AI drafts): every
    /// combination is either a valid period, no period, or a typed error. Nothing is defaulted (RichDomain).
    public static func make(start: (year: Int, month: Int?)?, end: (year: Int, month: Int?)?, current: Bool) throws(PeriodError) -> Period? {
        func date(_ d: (year: Int, month: Int?)) throws(PeriodError) -> PartialDate {
            guard let p = PartialDate(year: d.year, month: d.month) else { throw .invalidDate }
            return p
        }
        switch (start, end, current) {
        case (nil, nil, false): return nil
        case (nil, nil, true): throw .currentWithoutStart
        case (nil, .some(let e), _): _ = try date(e); throw .endWithoutStart
        case (.some, .some, true): throw .currentWithEndDate
        case (.some(let s), nil, true): return Period(start: try date(s), end: .current)
        case (.some(let s), nil, false): return Period(start: try date(s), end: .unknown)
        case (.some(let s), .some(let e), false):
            guard let p = Period(start: try date(s), end: .date(try date(e))) else { throw .endBeforeStart }
            return p
        }
    }
}

// MARK: - Levels

/// Bounded value object: invalid levels cannot exist (RichDomain).
public struct SkillLevel: Hashable, Sendable {
    public let value: Int
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
    static let atom = #"[\p{L}\p{N}!#$%&'*+/=?^_`{|}~-][\p{L}\p{M}\p{N}!#$%&'*+/=?^_`{|}~-]*"#
    static let label = #"[\p{L}\p{N}](?:[\p{L}\p{M}\p{N}-]{0,61}[\p{L}\p{M}\p{N}])?"#
    static let topLevel = #"(?:\p{L}\p{M}*){2,63}"#   // two to 63 letters, each with its marks
    static let pattern = "^" + atom + #"(?:\."# + atom + ")*@(?:" + label + #"\.)+"# + topLevel + #"\z"#
    public init?(_ raw: String) {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let hidden: Set<Unicode.GeneralCategory> = [.control, .format, .lineSeparator, .paragraphSeparator, .spaceSeparator,
                                                    .privateUse, .surrogate, .unassigned]
        guard v.utf8.count <= 254, !v.unicodeScalars.contains(where: { hidden.contains($0.properties.generalCategory) }),
              v.range(of: Self.pattern, options: .regularExpression) != nil else { return nil }
        // Length limits the pattern cannot express once marks are allowed: a local part of at most 64 bytes, and
        // domain labels of at most 63 characters, marks included. The exact IDNA length is not checked.
        let parts = v.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].utf8.count <= 64,
              parts[1].split(separator: ".").allSatisfy({ $0.unicodeScalars.count <= 63 }) else { return nil }
        value = v
    }
}

/// A phone number as written: digits with the usual separators, and at least three digits.
public struct PhoneNumber: Hashable, Sendable {
    public let value: String
    public init?(_ raw: String) {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...32).contains(v.count),
              v.range(of: #"^\+?[0-9 ()./-]+\z"#, options: .regularExpression) != nil,
              v.filter(\.isASCIIDigit).count >= 3 else { return nil }
        value = v
    }
}

/// An http or https address with a host, no credentials and the scheme's default port (ValidatingBoundary). Kept in the form
/// the parser serialises, never as the raw input.
public struct WebLink: Hashable, Sendable {
    public let value: String
    private static let maxBytes = 2048
    private static let defaultPorts = ["https": 443, "http": 80]

    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isPlainASCII(trimmed), let components = URLComponents(string: trimmed), Self.isWebAddress(components),
              let serialized = components.string, Self.isPlainASCII(serialized),
              URLComponents(string: serialized)?.string == serialized else { return nil }   // the value rebuilds itself
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
        guard let scheme = components.scheme?.lowercased(), let defaultPort = defaultPorts[scheme], let host = components.host else { return false }
        return isHostName(host) && hasNoCredentials(components) && [nil, defaultPort].contains(components.port)
    }

    private static func isHostName(_ host: String) -> Bool { host.range(of: #"^[A-Za-z0-9.-]{1,253}\z"#, options: .regularExpression) != nil }

    private static func hasNoCredentials(_ components: URLComponents) -> Bool { components.user == nil && components.password == nil }
}

// MARK: - The document

/// The language a CV is written in, as a BCP 47 tag: a language, an optional script and an optional region
/// ("it", "pt-BR", "zh-Hant-TW"). Stored in canonical case.
public struct DocumentLanguage: Hashable, Sendable {
    public let tag: String
    public init?(_ raw: String) {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard let first = parts.first, (2...3).contains(first.count), first.allSatisfy(\.isASCIILetter), parts.count <= 3 else { return nil }
        var canonical = [first.lowercased()]
        var rest = parts.dropFirst()
        if let script = rest.first, script.count == 4, script.allSatisfy(\.isASCIILetter) {
            canonical.append(script.prefix(1).uppercased() + script.dropFirst().lowercased()); rest = rest.dropFirst()
        }
        if let region = rest.first {
            if region.count == 2, region.allSatisfy(\.isASCIILetter) { canonical.append(region.uppercased()) }
            else if region.count == 3, region.allSatisfy(\.isASCIIDigit) { canonical.append(region) }
            else { return nil }
            rest = rest.dropFirst()
        }
        guard rest.isEmpty else { return nil }
        tag = canonical.joined(separator: "-")
    }
}

/// The design a CV is exported with, by identifier: the design, and optionally a palette and a font scheme.
/// The catalog resolves them; an identifier it does not know falls back to the design's defaults.
public struct DesignChoice: Hashable, Sendable {
    public let design: String, palette: String?, fonts: String?
    public init?(design: String, palette: String? = nil, fonts: String? = nil) {
        func valid(_ id: String) -> Bool { id.range(of: #"^[a-z0-9-]{1,64}\z"#, options: .regularExpression) != nil }
        guard valid(design), palette.map(valid) ?? true, fonts.map(valid) ?? true else { return nil }
        self.design = design; self.palette = palette; self.fonts = fonts
    }
}

extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
    var isASCIILetter: Bool { isASCII && isLetter }
}
