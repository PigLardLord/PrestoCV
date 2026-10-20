/// Finds the durations LinkedIn computes and prints next to a period or a company, such as "(2 years 3 months)",
/// "· 5 yrs 2 mos" or "1 anno 4 mesi". They are no fact the person wrote, and the import leaves them out (ADR 0027).
enum DurationReader {

    /// The ranges of the durations in a text, with their brackets or leading dot.
    static func ranges(in text: String) -> [Range<String.Index>] {
        let tokens = DateReader.tokenize(text)
        var ranges: [Range<String.Index>] = []
        var index = 0
        while index < tokens.count {
            var start = index
            var opened = false
            if case .mark(let mark) = tokens[index].kind, mark == "(" || mark == "·" {
                opened = mark == "("
                start = index
                index += 1
            }
            var end = index
            var units = 0
            while end + 1 < tokens.count, case .number = tokens[end].kind, case .word(let word) = tokens[end + 1].kind, unitWords.contains(word) {
                units += 1
                end += 2
                // "1 year and 2 months", "2 Jahre und 3 Monate"
                if end < tokens.count, case .word(let joiner) = tokens[end].kind, ["and", "e", "und", "y", "et"].contains(joiner) { end += 1 }
            }
            if units == 0, index < tokens.count, case .word(let word) = tokens[index].kind, lessThanAYear.contains(word) {
                // "less than a year": LinkedIn's duration of a short job
                end = index + 1
                while end < tokens.count, case .word(let next) = tokens[end].kind, ["than", "a", "year"].contains(next) { end += 1 }
                units = end - index >= 3 ? 1 : 0
            }
            guard units > 0 else {
                index = start + 1
                continue
            }
            var last = end - 1
            if opened, end < tokens.count, case .mark(")") = tokens[end].kind { last = end }
            ranges.append(tokens[start].range.lowerBound..<tokens[last].range.upperBound)
            index = last + 1
        }
        return ranges
    }

    /// Whether the whole text is a duration, as LinkedIn prints the total of a company's roles.
    static func isDurationOnly(_ text: String) -> Bool {
        guard let range = ranges(in: text).first else { return false }
        return text[..<range.lowerBound].trimmingSpaces().isEmpty && text[range.upperBound...].trimmingSpaces().isEmpty
    }

    private static let unitWords: Set<String> = Set([
        "year", "years", "yr", "yrs", "month", "months", "mo", "mos", "anno", "anni", "mese", "mesi", "jahr", "jahre", "monat",
        "monate", "j", "mon", "año", "años", "mes", "meses", "an", "ans", "mois", "ano", "anos", "mês",
    ].map(\.folded))

    private static let lessThanAYear: Set<String> = ["less"]
}
