import Foundation

/// What a row shows in the form where it opens on a page of its own (`EditorViewModel.showsOnAPage`): what it is, and
/// the line under it. The texts are the person's own, without the spaces around them; the view words the rest (R13).
public struct EntrySummary: Hashable, Sendable {
    /// The texts that name the row, in the order of its fields. None when those fields are empty: the view words the
    /// name of a row of the section.
    public let title: [String]
    /// The years of the row; nil when it gives none.
    public let years: EntryYears?
    /// The other texts of the line under the title: a job's city, a profile's link.
    public let details: [String]
    /// The code of a language's level, which the view words; nil when none is picked.
    public let level: String?

    init(title: [String], years: EntryYears? = nil, details: [String] = [], level: String? = nil) {
        self.title = title.filled
        self.years = years
        self.details = details.filled
        self.level = level?.trimmed.nonEmpty
    }
}

/// The years of a row, as the person typed them.
public enum EntryYears: Hashable, Sendable {
    /// From one year to another.
    case span(from: String, to: String)
    /// From a year, and it goes on.
    case ongoing(since: String)
    /// One year: the only one given, or a start and an end in the same year.
    case year(String)
}

extension PeriodParts {
    /// The years of the period: none without a start or an end, and none for a period that goes on without a start.
    var years: EntryYears? {
        let start = start.year.trimmed
        let end = end.year.trimmed
        if isCurrent { return start.isEmpty ? nil : .ongoing(since: start) }
        switch (start.isEmpty, end.isEmpty) {
        case (true, true): return nil
        case (false, true): return .year(start)
        case (true, false): return .year(end)
        case (false, false): return start == end ? .year(start) : .span(from: start, to: end)
        }
    }
}

private extension [String] {
    /// The texts that have more than spaces, without the spaces around them.
    var filled: [String] {
        compactMap { $0.trimmed.nonEmpty }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }

    /// The text without the spaces and line breaks around it. It reads `Character.isWhitespace`, as `isBlank` does, so
    /// that FoundationEssentials alone is enough (R18).
    var trimmed: String {
        let start = firstIndex { !$0.isWhitespace } ?? endIndex
        let end = lastIndex { !$0.isWhitespace }.map(index(after:)) ?? start
        return String(self[start..<end])
    }
}

// MARK: - Rows

extension ExperienceRow {
    /// The role and the company; the years; the city.
    public var summary: EntrySummary {
        EntrySummary(title: [role, company], years: period.years, details: [location])
    }
}

extension EducationRow {
    /// The degree and the school; the years.
    public var summary: EntrySummary { EntrySummary(title: [degree, school], years: period.years) }
}

extension LanguageRow {
    /// The language; its level.
    public var summary: EntrySummary { EntrySummary(title: [language], level: proficiency) }
}

extension CertificationRow {
    /// The certification and who issued it; the year it was issued.
    public var summary: EntrySummary {
        let year = issued.year.trimmed
        return EntrySummary(title: [name, issuer], years: year.isEmpty ? nil : .year(year))
    }
}

extension ProfileRow {
    /// The platform; the link.
    public var summary: EntrySummary { EntrySummary(title: [platform], details: [link]) }
}
