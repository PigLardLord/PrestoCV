import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// The contract table of the import (ADR 0027): every fixture of the synthetic corpus is imported, and each value it
/// states is compared with what the import found. Nothing may be invented: every value is checked against its spans.
@Suite("The import's contract table")
struct ContractTableTests {

    /// How one fixture fared.
    struct Score {
        var correct = 0
        var missed: [String] = []
        var wrong: [String] = []
        var extra: [String] = []

        var expected: Int { correct + missed.count + wrong.count }
        var rate: Double { expected == 0 ? 1 : Double(correct) / Double(expected) }

        mutating func compare(_ field: String, expected: String?, found: String?) {
            let normalise: (String?) -> String? = { $0?.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            switch (normalise(expected), normalise(found)) {
            case (nil, nil): break
            case (nil, let found?): extra.append("\(field): \(found)")
            case (let expected?, nil): missed.append("\(field): \(expected)")
            case (let expected?, let found?):
                if expected == found { correct += 1 } else { wrong.append("\(field): \(found) ≠ \(expected)") }
            }
        }

        mutating func compare(_ field: String, expected: [String], found: [String]) {
            for value in expected {
                if found.contains(value) { correct += 1 } else { missed.append("\(field): \(value)") }
            }
            for value in found where !expected.contains(value) { extra.append("\(field): \(value)") }
        }
    }

    static func score(_ result: ImportResult, against expected: Corpus.Expected) -> Score {
        var score = Score()
        let person = result.cv.person
        score.compare("name", expected: expected.person.name, found: person.name?.value)
        score.compare("title", expected: expected.person.title, found: person.title?.value)
        score.compare("email", expected: expected.person.email, found: person.email?.value.value)
        score.compare("phone", expected: expected.person.phone, found: person.phone?.value.value)
        score.compare("location", expected: expected.person.location, found: person.location?.value)
        score.compare("summary", expected: expected.person.summary, found: person.summary?.value)
        score.compare("links", expected: expected.person.links, found: person.links.map(\.address.value.value))

        for index in 0..<max(expected.experience.count, result.cv.experience.count) {
            let want = expected.experience.indices.contains(index) ? expected.experience[index] : nil
            let got = result.cv.experience.indices.contains(index) ? result.cv.experience[index] : nil
            score.compare("experience \(index) role", expected: want?.role, found: got?.role?.value)
            score.compare("experience \(index) employer", expected: want?.employer, found: got?.employer?.value)
            score.compare("experience \(index) location", expected: want?.location, found: got?.location?.value)
            score.compare("experience \(index) period", expected: want.map { period($0.start, $0.end) }, found: got?.period.map { period($0.value) })
            score.compare("experience \(index) details", expected: want.map { "\($0.details)" }, found: got.map { "\($0.details.count)" })
        }
        for index in 0..<max(expected.education.count, result.cv.education.count) {
            let want = expected.education.indices.contains(index) ? expected.education[index] : nil
            let got = result.cv.education.indices.contains(index) ? result.cv.education[index] : nil
            score.compare("education \(index) degree", expected: want?.degree, found: got?.degree?.value)
            score.compare("education \(index) school", expected: want?.school, found: got?.school?.value)
            if let location = want?.location { score.compare("education \(index) location", expected: location, found: got?.location?.value) }
            score.compare("education \(index) period", expected: want.map { period($0.start, $0.end) }, found: got?.period.map { period($0.value) })
        }
        score.compare("skill", expected: expected.skills, found: result.cv.skills.map(\.value))
        score.compare("language", expected: expected.languages.map(\.name), found: result.cv.languages.map(\.name.value))
        for language in expected.languages {
            let found = result.cv.languages.first { $0.name.value == language.name }
            guard found != nil else { continue }
            score.compare("level of \(language.name)", expected: language.level, found: found?.level.map { $0.value.rawValue })
        }
        score.compare("certification", expected: expected.certifications.map(\.name), found: result.cv.certifications.map(\.name.value))
        for certification in expected.certifications {
            guard let found = result.cv.certifications.first(where: { $0.name.value == certification.name }) else { continue }
            score.compare("issuer of \(certification.name)", expected: certification.issuer, found: found.issuer?.value)
            score.compare("year of \(certification.name)", expected: certification.year.map(String.init), found: found.year.map { String($0.value) })
            score.compare("link of \(certification.name)", expected: certification.link, found: found.link?.value.value)
            score.compare("description of \(certification.name)", expected: certification.description, found: found.description?.value)
        }
        score.compare("interest", expected: expected.interests, found: result.cv.interests.map(\.value))
        return score
    }

    private static func period(_ start: [Int?], _ end: Corpus.Expected.End) -> String {
        let first = start.compactMap { $0 }.map(String.init).joined(separator: "-")
        switch end {
        case .current: return first + " → current"
        case .date(let date): return first + " → " + date.compactMap { $0 }.map(String.init).joined(separator: "-")
        case .none: return first
        }
    }

    private static func period(_ period: ImportedPeriod) -> String {
        let first = [period.start.year, period.start.month].compactMap { $0 }.map(String.init).joined(separator: "-")
        switch period.end {
        case .current?: return first + " → current"
        case .date(let date)?: return first + " → " + [date.year, date.month].compactMap { $0 }.map(String.init).joined(separator: "-")
        case .unstated?: return first + " → ?"
        case nil: return first
        }
    }

    // MARK: The table

    /// The lowest rate each form may fall to. The table only ever rises: a defect found adds a fixture, which fails, before
    /// its fix.
    static let floors: [String: Double] = [
        "chat": 1, "word": 1, "latex": 1, "europass": 1, "lebenslauf": 1, "linkedin": 1, "wordpdf": 1, "railpdf": 1,
        "lebenslaufpdf": 1, "europasspdf": 1, "trap": 1,
    ]

    @Test("Every fixture of the corpus imports with nothing invented, at or above its form's floor")
    func table() async throws {
        var rows: [(Corpus.Entry, Score)] = []
        for entry in try Corpus.entries() {
            let result = try await Corpus.importResult(of: entry)
            #expect(result.ungrounded.isEmpty, "\(entry.id): values the gate refused: \(result.ungrounded)")
            #expect(Coverage.lost(result).isEmpty, "\(entry.id): lines that no value, text not imported or left-out piece covers: \(Coverage.lost(result).map(\.text))")
            let score = Self.score(result, against: try Corpus.expected(of: entry))
            rows.append((entry, score))
        }
        print(Self.report(rows))
        for (entry, score) in rows {
            let floor = Self.floors[entry.form] ?? 1
            #expect(score.rate >= floor, "\(entry.id): \(Int(score.rate * 100))% < \(Int(floor * 100))%; missed \(score.missed); wrong \(score.wrong); extra \(score.extra)")
            #expect(score.wrong.filter { $0.hasPrefix("email") || $0.hasPrefix("phone") }.isEmpty, "\(entry.id): a contact that is not the person's")
        }
    }

    /// The rates by language and form, and the totals.
    static func report(_ rows: [(Corpus.Entry, Score)]) -> String {
        let forms = ["chat", "word", "latex", "europass", "lebenslauf", "linkedin", "wordpdf", "railpdf", "lebenslaufpdf", "europasspdf", "trap"]
        let languages = ["en", "it", "de", "es", "fr", "pt"]
        var lines = ["Import contract table: values found of the values stated (missed, wrong, extra)", ""]
        lines.append("form".padding(toLength: 14, withPad: " ", startingAt: 0) + languages.map { $0.padding(toLength: 12, withPad: " ", startingAt: 0) }.joined())
        for form in forms where rows.contains(where: { $0.0.form == form }) {
            var line = form.padding(toLength: 14, withPad: " ", startingAt: 0)
            for language in languages {
                let scores = rows.filter { $0.0.form == form && $0.0.language == language }.map(\.1)
                let correct = scores.reduce(0) { $0 + $1.correct }
                let expected = scores.reduce(0) { $0 + $1.expected }
                line += (expected == 0 ? "—" : "\(correct)/\(expected)").padding(toLength: 12, withPad: " ", startingAt: 0)
            }
            lines.append(line)
        }
        let correct = rows.reduce(0) { $0 + $1.1.correct }
        let expected = rows.reduce(0) { $0 + $1.1.expected }
        let missed = rows.reduce(0) { $0 + $1.1.missed.count }
        let wrong = rows.reduce(0) { $0 + $1.1.wrong.count }
        let extra = rows.reduce(0) { $0 + $1.1.extra.count }
        lines.append("")
        lines.append("total \(correct)/\(expected) (\(String(format: "%.1f", 100 * Double(correct) / Double(max(expected, 1))))%), missed \(missed), wrong \(wrong), extra \(extra)")
        for (entry, score) in rows where !score.missed.isEmpty || !score.wrong.isEmpty || !score.extra.isEmpty {
            lines.append("  \(entry.id): missed \(score.missed) wrong \(score.wrong) extra \(score.extra)")
        }
        return lines.joined(separator: "\n")
    }
}
