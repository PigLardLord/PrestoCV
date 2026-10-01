import Foundation   // value types only (R2): UUID and Date as types, never UUID() / Date()

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
    /// combination is either a valid period, no period, or a typed error. Nothing is defaulted (R6).
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

/// Bounded value object: invalid levels cannot exist (R6).
public struct SkillLevel: Hashable, Sendable {
    public let value: Int
    public init?(_ value: Int) { guard (1...5).contains(value) else { return nil }; self.value = value }
}

/// The CEFR levels, plus native. Its display name belongs to presentation (R13).
public enum LanguageProficiency: String, CaseIterable, Hashable, Sendable {
    case a1, a2, b1, b2, c1, c2, native
}

// MARK: - Contact details

/// A local part of dot-separated atoms (no leading, trailing or doubled dot) and a domain of labels (letters or
/// digits, inner hyphens, 1–63 characters each) ending in an alphabetic top-level label. Internationalised letters
/// are allowed, with the combining marks that follow them (Indic vowel signs, decomposed accents); control, format
/// and separator characters (NUL, zero-width space, bidirectional overrides) are not, nor are the invisible fillers
/// (default-ignorable code points other than variation selectors), since they can hide or disguise what is printed.
/// No atom or label starts with a mark. The address is at most 254 bytes as typed. Its local part is at most 64 bytes
/// (RFC 5321 §4.5.3.1.1), and each domain label is at most 63 characters as written and 63 bytes once encoded for
/// IDNA (Punycode, RFC 5891; RFC 1035 §3.1). The local part, the at sign and the encoded domain together are at most
/// 254 bytes, a mail path of 256 octets less its angle brackets (RFC 5321 §4.5.3.1.3). A label is measured as IDNA
/// maps it (variation selectors ignored, compatibility normalisation, case folding, NFC), so fullwidth letters and
/// ligatures count as the letters they stand for, and a label that is not a label once mapped is refused (the Catalan
/// middle dot is allowed between two "l"). The disallowed characters, bidirectional and contextual rules of IDNA are
/// not applied. The stored value stays as it was written.
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
        func hides(_ scalar: Unicode.Scalar) -> Bool {
            hidden.contains(scalar.properties.generalCategory)
                || (scalar.properties.isDefaultIgnorableCodePoint && !scalar.properties.isVariationSelector)
        }
        guard v.utf8.count <= 254, !v.unicodeScalars.contains(where: hides),
              v.range(of: Self.pattern, options: .regularExpression) != nil else { return nil }
        // Length limits the pattern cannot express once marks are allowed: the local part, and the domain once encoded.
        // Each label is checked to be at most 63 characters as written before it is mapped and encoded, which bounds
        // the work per label. The path bound is tighter than a domain name's own (255 octets on the wire, 253 as
        // dotted text, RFC 1035 §3.1), so it is the only bound on the whole domain.
        let parts = Self.pieces(of: v, separatedBy: "@", keepingEmpty: true)
        guard parts.count == 2, parts[0].utf8.count <= 64, let domain = Self.encodedDomain(parts[1]),
              parts[0].utf8.count + 1 + domain.utf8.count <= 254 else { return nil }
        value = v
    }

    /// The A-labels of the domain joined by dots, or nil when a label is longer than 63 characters as written or than 63
    /// bytes once encoded, or is not a label once mapped.
    private static func encodedDomain(_ domain: String) -> String? {
        var aLabels: [String] = []
        for label in pieces(of: domain, separatedBy: ".", keepingEmpty: false) {
            guard label.unicodeScalars.count <= 63, let aLabel = IDNA.aLabel(label), aLabel.utf8.count <= 63 else { return nil }
            aLabels.append(aLabel)
        }
        return aLabels.joined(separator: ".")
    }

    /// Splits on scalars, not characters: grapheme rules join a letter such as U+0D4E to the scalar after it, which
    /// would hide a separator.
    private static func pieces(of text: String, separatedBy separator: Unicode.Scalar, keepingEmpty: Bool) -> [String] {
        text.unicodeScalars.split(separator: separator, omittingEmptySubsequences: !keepingEmpty)
            .map { String(String.UnicodeScalarView($0)) }
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

/// An http or https address with a host, no credentials and the scheme's default port (R8). Kept in the form
/// the parser serialises, never as the raw input.
public struct WebLink: Hashable, Sendable {
    public let value: String
    public init?(_ raw: String) {
        let v = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard v.utf8.count <= 2048, v.unicodeScalars.allSatisfy({ $0.isASCII && $0.value > 0x20 && $0.value != 0x7F && $0 != "\\" }),
              let c = URLComponents(string: v), let scheme = c.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = c.host, host.range(of: #"^[A-Za-z0-9.-]{1,253}\z"#, options: .regularExpression) != nil,
              c.user == nil, c.password == nil, c.port == nil || c.port == (scheme == "https" ? 443 : 80),
              let serialized = c.string, serialized.utf8.count <= 2048,
              serialized.unicodeScalars.allSatisfy({ $0.isASCII && $0.value > 0x20 && $0.value != 0x7F && $0 != "\\" }),
              URLComponents(string: serialized)?.string == serialized else { return nil }   // the value rebuilds itself
        value = serialized
    }
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
