import Foundation
internal import PrestoCVDomain

/// The choices of the editor's menus, as codes the view words: those the domain can store.
public enum EditorChoices {
    /// The levels of a skill, lowest first.
    public static let skillLevels: [Int] = Array(1...5)
    /// How well the person speaks a language, from beginner to native: the codes `a1` to `c2` and `native`.
    public static let proficiencies: [String] = LanguageProficiency.allCases.map(\.rawValue)
    /// The months of a date, January first: 1 to 12, those of the Gregorian calendar the domain stores. The view words
    /// them in the person's language.
    public static let months: [Int] = Array(1...12)

    /// Whether a date's month stands before its year in `locale`, as in "March 2019", or after it, as in "2019年3月": the
    /// order the locale writes a month and a year in, its quoted words left out. Month first when the locale has none.
    public static func monthBeforeYear(in locale: Locale) -> Bool {
        guard let pattern = DateFormatter.dateFormat(fromTemplate: "yMMMM", options: 0, locale: locale) else { return true }
        let fields = pattern.split(separator: "'", omittingEmptySubsequences: false).enumerated()
            .filter { $0.offset.isMultiple(of: 2) }.map(\.element).joined()
        guard let month = fields.firstIndex(of: "M"), let year = fields.firstIndex(of: "y") else { return true }
        return month < year
    }
}
