// MARK: - Dates as the text states them

/// A year, or a year and a month, as the text states it.
public struct YearMonth: Hashable, Sendable {
    public let year: Int
    public let month: Int?

    public init(year: Int, month: Int?) {
        self.year = year
        self.month = month
    }
}

/// A date or a period as the text states it, read by closed rules. The CV's own period is built from it with
/// `Period.make`, the rule that exists once (R6).
public struct ImportedPeriod: Hashable, Sendable {
    public enum End: Hashable, Sendable {
        case date(YearMonth)
        /// "heute", "oggi", "Present", "seit 2019".
        case current
        /// The range has no end: "2019 –".
        case unstated
    }

    public let start: YearMonth
    /// Nil for a single date.
    public let end: End?

    public init(start: YearMonth, end: End?) {
        self.start = start
        self.end = end
    }
}

/// A date or period found in a text.
struct DateMatch: Equatable {
    let range: Range<String.Index>
    let period: ImportedPeriod
}

// MARK: - The reader

/// Reads dates and periods in the forms of the six languages: numeric months ("03/2019", "2019-03", "12.03.2026"),
/// month names and their abbreviations, ranges with their connectors ("–", "to", "a", "al", "bis", "hasta", "au",
/// "até"), the words of a current period ("heute", "oggi", "Present", "actualidad", "aujourd'hui", "atual") and
/// "since" forms ("seit", "dal", "desde", "depuis", "ab").
enum DateReader {

    static func periods(in text: some StringProtocol) -> [DateMatch] {
        let string = String(text)
        let tokens = tokenize(string)
        var matches: [DateMatch] = []
        var index = 0
        while index < tokens.count {
            if let (period, end) = period(at: index, in: tokens) {
                matches.append(DateMatch(range: tokens[index].range.lowerBound..<tokens[end].range.upperBound, period: period))
                index = end + 1
            } else {
                index += 1
            }
        }
        return matches
    }

    // MARK: Tokens

    struct Token {
        enum Kind: Equatable {
            case number(Int, digits: Int)
            case word(String)
            case mark(Character)
        }
        let kind: Kind
        let range: Range<String.Index>
        /// White space comes right before it.
        let spaced: Bool
    }

    static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var index = text.startIndex
        var spaced = false
        while index < text.endIndex {
            let character = text[index]
            if character.isWhitespace {
                spaced = true
                index = text.index(after: index)
                continue
            }
            let start = index
            if character.isASCII && character.isNumber {
                while index < text.endIndex, text[index].isASCII, text[index].isNumber { index = text.index(after: index) }
                let digits = text[start..<index]
                tokens.append(Token(kind: .number(Int(digits) ?? 0, digits: digits.count), range: start..<index, spaced: spaced))
            } else if character.isLetter {
                while index < text.endIndex, text[index].isLetter || ((text[index] == "'" || text[index] == "’") && index > start) {
                    index = text.index(after: index)
                }
                tokens.append(Token(kind: .word(text[start..<index].folded), range: start..<index, spaced: spaced))
            } else {
                index = text.index(after: index)
                tokens.append(Token(kind: .mark(character), range: start..<index, spaced: spaced))
            }
            spaced = false
        }
        return tokens
    }

    // MARK: Periods

    /// The period that starts at a token, and the index of its last token.
    private static func period(at start: Int, in tokens: [Token]) -> (ImportedPeriod, Int)? {
        var index = start
        var prefix: Prefix?
        if let (found, next) = prefixWord(at: index, in: tokens) {
            prefix = found
            index = next
        }
        // A month without its year opens a range whose end gives the year: "marzo – giugno 2019"
        if let month = monthName(at: index, in: tokens), let connector = connector(after: month.end, in: tokens),
           let (end, endIndex) = date(at: connector, in: tokens), let endMonth = end.month, endMonth >= month.month,
           date(at: index, in: tokens) == nil {
            return (ImportedPeriod(start: YearMonth(year: end.year, month: month.month), end: .date(end)), endIndex)
        }
        if let found = shortRange(at: index, in: tokens) { return found }
        guard let (first, firstEnd) = date(at: index, in: tokens) else { return nil }
        if let next = connector(after: firstEnd, in: tokens) {
            if let (second, secondEnd) = rangeEnd(at: next, in: tokens) {
                let ordered = (second.year, second.month ?? 0) >= (first.year, first.month ?? 0)
                if ordered { return (ImportedPeriod(start: first, end: .date(second)), secondEnd) }
            }
            if let currentEnd = currentWords(at: next, in: tokens) {
                return (ImportedPeriod(start: first, end: .current), currentEnd)
            }
        }
        if prefix == .since {
            return (ImportedPeriod(start: first, end: .current), firstEnd)
        }
        // A dash that ends the text: the range has no end
        if firstEnd + 2 == tokens.count, case .mark(let mark) = tokens[firstEnd + 1].kind, dashes.contains(mark) {
            return (ImportedPeriod(start: first, end: .unstated), firstEnd + 1)
        }
        // A prefix that only reads as "from" with a range is not part of a single date
        let quoteStart = prefix == nil ? start : index
        if quoteStart != start { return period(at: index, in: tokens) }
        return (ImportedPeriod(start: first, end: nil), firstEnd)
    }

    /// A range that starts with a two-digit year, "09/19 – 08/21" or "10/21 – heute": a two-digit year is a date only here.
    /// A range beside a percent sign, a currency or a rate ("3.50–4.50%", "10.50–12.50 €/hour") is a range of numbers.
    private static func shortRange(at index: Int, in tokens: [Token]) -> (ImportedPeriod, Int)? {
        guard !followsNumber(index, in: tokens), !isUnit(before: index, in: tokens),
              let (first, firstEnd) = shortDate(at: index, in: tokens),
              let next = connector(after: firstEnd, in: tokens) else { return nil }
        if let (second, secondEnd) = rangeEnd(at: next, in: tokens),
           (second.year, second.month ?? 0) >= (first.year, first.month ?? 0), !isUnit(after: secondEnd, in: tokens) {
            return (ImportedPeriod(start: first, end: .date(second)), secondEnd)
        }
        guard let currentEnd = currentWords(at: next, in: tokens) else { return nil }
        return (ImportedPeriod(start: first, end: .current), currentEnd)
    }

    /// A number unit right before the token: a currency sign or code.
    private static func isUnit(before index: Int, in tokens: [Token]) -> Bool {
        guard index > 0 else { return false }
        switch tokens[index - 1].kind {
        case .mark(let mark): return currencySigns.contains(mark)
        case .word(let word): return currencyWords.contains(word)
        case .number: return false
        }
    }

    /// A number unit right after the token: a percent sign, a currency, "k", "/h", "/hour", "per hour".
    private static func isUnit(after index: Int, in tokens: [Token]) -> Bool {
        var next = index + 1
        guard next < tokens.count else { return false }
        if case .mark("/") = tokens[next].kind, !tokens[next].spaced { next += 1 }
        else if case .word("per") = tokens[next].kind { next += 1 }
        else if case .mark(let mark) = tokens[next].kind { return mark == "%" || currencySigns.contains(mark) }
        guard next < tokens.count, case .word(let word) = tokens[next].kind else { return false }
        return currencyWords.contains(word) || rateWords.contains(word)
    }

    private static let currencySigns: Set<Character> = ["€", "$", "£", "¥"]
    private static let currencyWords: Set<String> = [
        "eur", "euro", "euros", "usd", "chf", "gbp", "dollar", "dollars", "pounds"
    ]
    private static let rateWords: Set<String> = [
        "k", "h", "hr", "hrs", "hour", "hours", "stunde", "ora", "heure", "hora"
    ]

    /// The end date of a range, as a date or a two-digit date, after the words of an expected end ("expected 06/2024").
    private static func rangeEnd(at index: Int, in tokens: [Token]) -> (YearMonth, Int)? {
        var start = index
        if index < tokens.count, case .word(let word) = tokens[index].kind, expectedWords.contains(word) { start += 1 }
        return date(at: start, in: tokens) ?? shortDate(at: start, in: tokens)
    }

    private static let expectedWords: Set<String> = [
        "expected", "voraussichtlich", "previsto", "prevista", "prevu", "prevue", "esperado", "esperada",
    ].reduce(into: Set<String>()) { $0.insert($1.folded) }

    private enum Prefix { case since, from }

    /// "since"-like words make the period current when no end follows; "from"-like words only open a range.
    private static func prefixWord(at index: Int, in tokens: [Token]) -> (Prefix, Int)? {
        guard index < tokens.count, case .word(let word) = tokens[index].kind else { return nil }
        // "a partir de"
        if word == "a", index + 2 < tokens.count, case .word("partir") = tokens[index + 1].kind, case .word("de") = tokens[index + 2].kind {
            return (.since, index + 3)
        }
        if sinceWords.contains(word) { return (.since, index + 1) }
        if fromWords.contains(word) { return (.from, index + 1) }
        return nil
    }

    private static let sinceWords: Set<String> = ["since", "seit", "dal", "dall'", "dalla", "dallo", "da", "desde", "depuis", "ab", "des"]
    private static let fromWords: Set<String> = ["from", "von", "vom", "de", "del", "du", "do"]

    // MARK: Dates

    /// A date at a token: a month name and a year, a numeric month and year, a full date, an ISO month, or a year.
    private static func date(at index: Int, in tokens: [Token]) -> (YearMonth, Int)? {
        guard index < tokens.count else { return nil }
        if let month = monthName(at: index, in: tokens) {
            var next = month.end + 1
            if next < tokens.count, case .word(let word) = tokens[next].kind, word == "de" || word == "of" { next += 1 }
            if next < tokens.count, case .mark(",") = tokens[next].kind { next += 1 }
            if let year = year(at: next, in: tokens) {
                return (YearMonth(year: year, month: month.month), next)
            }
            return nil
        }
        guard case .number(let first, let firstDigits) = tokens[index].kind else { return nil }
        // dd.mm.yyyy, dd/mm/yyyy
        if firstDigits <= 2, let (second, secondDigits, afterSecond) = numberAfterSeparator(index, in: tokens), secondDigits <= 2,
           let (third, thirdDigits, afterThird) = numberAfterSeparator(afterSecond, in: tokens), thirdDigits == 4, isYear(third) {
            if (1...12).contains(second), (1...31).contains(first) { return (YearMonth(year: third, month: second), afterThird) }
            if (1...12).contains(first), (1...31).contains(second) { return (YearMonth(year: third, month: first), afterThird) }
            return nil
        }
        // mm/yyyy, mm.yyyy, mm-yyyy
        if firstDigits <= 2, (1...12).contains(first), let (second, secondDigits, afterSecond) = numberAfterSeparator(index, in: tokens),
           secondDigits == 4, isYear(second) {
            return (YearMonth(year: second, month: first), afterSecond)
        }
        guard firstDigits == 4, isYear(first) else { return nil }
        // A year inside a longer number, such as a phone number's group, is no date
        if index > 0, case .number = tokens[index - 1].kind, tokens[index].spaced { return nil }
        if index + 1 < tokens.count, case .number = tokens[index + 1].kind, tokens[index + 1].spaced { return nil }
        // yyyy-mm, yyyy/mm
        if let (second, secondDigits, afterSecond) = numberAfterSeparator(index, in: tokens, separators: ["-", "/", "."]),
           secondDigits <= 2, (1...12).contains(second), !tokens[index + 1].spaced {
            return (YearMonth(year: first, month: second), afterSecond)
        }
        return (YearMonth(year: first, month: nil), index)
    }

    /// A month and a two-digit year, "09/19" or "09.19", that no other number touches.
    private static func shortDate(at index: Int, in tokens: [Token]) -> (YearMonth, Int)? {
        guard index < tokens.count, case .number(let month, let monthDigits) = tokens[index].kind, monthDigits <= 2, (1...12).contains(month),
              let (value, digits, end) = numberAfterSeparator(index, in: tokens, separators: ["/", "."]), digits == 2,
              !(isDot(after: index, in: tokens) && monthDigits == 1),
              numberAfterSeparator(end, in: tokens, separators: ["/", "."]) == nil else { return nil }
        let year = value < twoDigitPivot ? 2000 + value : 1900 + value
        return isYear(year) ? (YearMonth(year: year, month: month), end) : nil
    }

    /// A dot between two numbers can be a decimal point: a month written with one digit before it is no month ("3.50").
    private static func isDot(after index: Int, in tokens: [Token]) -> Bool {
        index + 1 < tokens.count && tokens[index + 1].kind == .mark(".")
    }

    /// Two-digit years from 00 up to this are 20xx, the others 19xx. Stated here and nowhere else; no clock is read.
    /// The reader's year bounds (`isYear`) apply after this mapping, so 30 to 39 give 1930 to 1939 and are not read.
    private static let twoDigitPivot = 30

    private static func followsNumber(_ index: Int, in tokens: [Token]) -> Bool {
        guard index >= 2, case .mark(let mark) = tokens[index - 1].kind, ["/", ".", "-"].contains(mark), !tokens[index].spaced else { return false }
        if case .number = tokens[index - 2].kind { return true }
        return false
    }

    private static func numberAfterSeparator(_ index: Int, in tokens: [Token], separators: Set<Character> = ["/", ".", "-"]) -> (Int, Int, Int)? {
        guard index + 2 < tokens.count, case .mark(let mark) = tokens[index + 1].kind, separators.contains(mark),
              !tokens[index + 1].spaced, !tokens[index + 2].spaced,
              case .number(let value, let digits) = tokens[index + 2].kind else { return nil }
        return (value, digits, index + 2)
    }

    private static func year(at index: Int, in tokens: [Token]) -> Int? {
        guard index < tokens.count, case .number(let value, 4) = tokens[index].kind, isYear(value) else { return nil }
        return value
    }

    private static func isYear(_ value: Int) -> Bool { (1940...2099).contains(value) }

    private struct MonthToken { let month: Int; let end: Int }

    /// A month's name or abbreviation, with the full stop after an abbreviation.
    private static func monthName(at index: Int, in tokens: [Token]) -> MonthToken? {
        guard index < tokens.count, case .word(let word) = tokens[index].kind, let month = months[word] else { return nil }
        if index + 1 < tokens.count, case .mark(".") = tokens[index + 1].kind, !tokens[index + 1].spaced {
            return MonthToken(month: month, end: index + 1)
        }
        return MonthToken(month: month, end: index)
    }

    // MARK: Connectors and current words

    private static let dashes: Set<Character> = ["-", "–", "—", "‐", "−", "~", "→"]
    private static let connectorWords: Set<String> = [
        "to", "till", "until", "a", "al", "ad", "fino", "bis", "zum", "hasta", "au", "jusqu'a", "jusqu'au", "ate", "ao", "a", "e",
    ]

    /// The index of the token after a range's connector that follows a date ending at `end`.
    private static func connector(after end: Int, in tokens: [Token]) -> Int? {
        var index = end + 1
        guard index < tokens.count else { return nil }
        switch tokens[index].kind {
        case .mark(let mark) where dashes.contains(mark):
            index += 1
            if index < tokens.count, case .mark(">") = tokens[index].kind { index += 1 }
        case .mark("/"):
            // Only between two years: "2016/2017"
            guard case .number(_, 4) = tokens[end].kind, index + 1 < tokens.count, case .number(_, 4) = tokens[index + 1].kind else { return nil }
            index += 1
        case .word(let word) where connectorWords.contains(word):
            index += 1
            // "fino a", "fino al", "bis zum"
            if index < tokens.count, case .word(let next) = tokens[index].kind, ["a", "al", "ad", "zum"].contains(next), word == "fino" || word == "bis" {
                index += 1
            }
        default:
            return nil
        }
        return index < tokens.count ? index : nil
    }

    /// The last token of the words of a current period at a token: "heute", "bis heute", "a oggi", "to date",
    /// "à ce jour", "hasta la fecha", "até hoje".
    private static func currentWords(at index: Int, in tokens: [Token]) -> Int? {
        guard index < tokens.count, case .word(let word) = tokens[index].kind else { return nil }
        for phrase in currentPhrases where phrase.first == word {
            var matched = true
            for (offset, part) in phrase.enumerated().dropFirst() {
                guard index + offset < tokens.count, case .word(let next) = tokens[index + offset].kind, next == part else {
                    matched = false
                    break
                }
            }
            if matched { return index + phrase.count - 1 }
        }
        return currentWordSet.contains(word) ? index : nil
    }

    private static let currentWordSet: Set<String> = [
        "present", "current", "currently", "now", "today", "ongoing", "date",
        "heute", "jetzt", "aktuell", "laufend", "derzeit", "dato",
        "oggi", "presente", "attuale", "attualmente", "tuttora", "corrente",
        "actualidad", "actual", "actualmente", "hoy",
        "aujourd'hui", "actuel", "actuellement",
        "atual", "atualmente", "hoje", "agora", "momento",
    ].reduce(into: Set<String>()) { $0.insert($1.folded) }

    private static let currentPhrases: [[String]] = [
        ["in", "corso"], ["en", "cours"], ["ce", "jour"], ["a", "ce", "jour"], ["la", "fecha"], ["hasta", "la", "fecha"],
        ["a", "la", "fecha"], ["hasta", "hoy"], ["o", "momento"], ["ate", "hoje"], ["ate", "ao", "momento"],
        ["ate", "o", "momento"], ["the", "present"], ["to", "date"], ["bis", "heute"], ["a", "oggi"], ["ad", "oggi"],
    ]

    // MARK: Months

    private static let months: [String: Int] = {
        let names: [(Int, [String])] = [
            (1, ["january", "jan", "gennaio", "gen", "januar", "jänner", "enero", "ene", "janvier", "janv", "janeiro"]),
            (2, ["february", "feb", "febbraio", "februar", "febrero", "février", "févr", "fév", "fevereiro", "fev"]),
            (3, ["march", "mar", "marzo", "märz", "mär", "mrz", "mars", "março"]),
            (4, ["april", "apr", "aprile", "abril", "abr", "avril", "avr"]),
            (5, ["may", "maggio", "mag", "mai", "mayo", "maio"]),
            (6, ["june", "jun", "giugno", "giu", "juni", "junio", "juin", "junho"]),
            (7, ["july", "jul", "luglio", "lug", "juli", "julio", "juillet", "juil", "julho"]),
            (8, ["august", "aug", "agosto", "ago", "août", "aou", "aout"]),
            (9, ["september", "sep", "sept", "settembre", "set", "sett", "septiembre", "setiembre", "septembre", "setembro"]),
            (10, ["october", "oct", "ottobre", "ott", "oktober", "okt", "octubre", "octobre", "outubro", "out"]),
            (11, ["november", "nov", "novembre", "noviembre", "novembro"]),
            (12, ["december", "dec", "dicembre", "dic", "dezember", "dez", "diciembre", "décembre", "déc", "dezembro"]),
        ]
        var table: [String: Int] = [:]
        for (month, words) in names {
            for word in words { table[word.folded] = month }
        }
        return table
    }()
}
