import Foundation
import PrestoCVDomain

/// The legacy app kept a period as the text the person typed. Only an unambiguous range is converted: two dates (a year,
/// or a month and a year) joined by a dash or "to", the second possibly a word for "now". Anything else is unreadable
/// and is dropped by the importer, which reports it; nothing is guessed.
enum LegacyPeriod {
    enum Reading: Equatable { case none, period(Period), unreadable }

    private static let separators = #"(?i)\s*[-–—]\s*|\s+(?:to|bis|a|al|à|au|até)\s+"#
    private static let now: Set<String> = [
        "present", "current", "now", "today", "oggi", "ad oggi", "attuale", "presente", "heute", "aktuell", "jetzt",
        "actual", "actualidad", "hoy", "présent", "aujourd'hui", "actuel", "atual", "atualmente", "hoje",
    ]
    private static let months: [String: Int] = [
        "jan": 1, "gen": 1, "ene": 1, "feb": 2, "fev": 2, "mar": 3, "apr": 4, "avr": 4, "abr": 4, "may": 5, "mai": 5, "mag": 5,
        "jun": 6, "giu": 6, "juin": 6, "jul": 7, "lug": 7, "juil": 7, "aug": 8, "ago": 8, "aou": 8, "sep": 9, "set": 9,
        "oct": 10, "okt": 10, "ott": 10, "out": 10, "nov": 11, "dec": 12, "dic": 12, "dez": 12,
    ]

    static func read(_ text: String) -> Reading {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        let parts = trimmed.replacingOccurrences(of: separators, with: "|", options: .regularExpression).split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 2, let start = date(String(parts[0])) else { return .unreadable }
        return period(start: start, end: String(parts[1]))
    }

    private static func period(start: (year: Int, month: Int?), end: String) -> Reading {
        let isNow = now.contains(end.trimmingCharacters(in: .whitespaces).lowercased())
        guard isNow || date(end) != nil else { return .unreadable }
        do {
            let made = try Period.make(start: start, end: isNow ? nil : date(end), current: isNow)
            return made.map { .period($0) } ?? .unreadable
        } catch { return .unreadable }
    }

    /// `2020`, `09/2020`, `Sep 2020` or `September 2020`, in the six languages of the app.
    private static func date(_ text: String) -> (year: Int, month: Int?)? {
        let words = text.trimmingCharacters(in: .whitespaces).split(whereSeparator: { $0 == " " || $0 == "/" || $0 == "." }).map(String.init)
        switch words.count {
        case 1: return year(words[0]).map { ($0, nil) }
        case 2: return year(words[1]).flatMap { y in month(words[0]).map { (y, $0) } }
        default: return nil
        }
    }

    private static func year(_ word: String) -> Int? { word.count == 4 ? Int(word) : nil }

    private static func month(_ word: String) -> Int? {
        if let number = Int(word) { return (1...12).contains(number) ? number : nil }
        let folded = word.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        return months[String(folded.prefix(4))] ?? months[String(folded.prefix(3))]
    }
}
