import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// Every shape of a line that holds only a period, under a heading that joins studies and certifications (#461): the
/// entry above it (a certification, a study on one line, a study on two lines: degree, then school), the entry below it,
/// which of the two has a date of its own, whether the section starts with a date or with an entry, and a period that is
/// the last line. The rule: the period stays with the neighbour that has no date of its own; when both or neither have
/// one, the direction of the section decides (below when the section starts with dates, above otherwise); a last line
/// goes to the entry above it. Every value here is invented (the corpus README).
@Suite("A period on its own line, in every shape of its neighbours")
struct PeriodShapesTests {

    /// The words of one language: two certifications, two studies on one line, two studies on two lines.
    struct Words: Sendable, CustomTestStringConvertible {
        let language: String
        let heading: String
        let certificates: [(name: String, issuer: String)]
        let studies: [(degree: String, school: String)]
        let twoLines: [(degree: String, school: String)]
        var testDescription: String { language }
    }

    static let languages = [
        Words(
            language: "en", heading: "Education & Certifications",
            certificates: [("Certified Scrum Master", "Scrum Alliance"), ("Certified Product Owner", "Meridian Board")],
            studies: [("BSc Physics", "University of Leipzig"), ("BSc Chemistry", "University of Halle")],
            twoLines: [("Master of Science in Physics", "University of Bonn"), ("Master of Science in Chemistry", "Technical University of Dresden")]),
        Words(
            language: "de", heading: "Ausbildung & Zertifizierungen",
            certificates: [("Zertifizierter Scrum Master", "Scrum Alliance"), ("Zertifizierter Product Owner", "Meridian Board")],
            studies: [("BSc Physik", "Universität Leipzig"), ("BSc Chemie", "Universität Halle")],
            twoLines: [("Master of Science in Physik", "Universität Bonn"), ("Master of Science in Chemie", "Technische Universität Dresden")]),
        Words(
            language: "it", heading: "Istruzione e certificazioni",
            certificates: [("Certificazione Scrum Master", "Scrum Alliance"), ("Certificazione Product Owner", "Meridian Board")],
            studies: [("Laurea in Fisica", "Università di Pisa"), ("Laurea in Chimica", "Università di Siena")],
            twoLines: [("Laurea Magistrale in Fisica", "Università di Bologna"), ("Laurea Magistrale in Chimica", "Università di Padova")]),
    ]

    /// A row: the lines of the section, as tokens, and what each entry must come out with.
    /// Tokens: `C1 C2` a certification, `S1 S2` a study on one line, `M1 M2` a study on two lines (degree, school);
    /// a `d` after it dates the entry itself (a year 2018, the period 2010-2014, the school line of an `M` 2012-2014);
    /// `M1a M1b` the degree line and the school line of a study with a line between them; `P` the period 2019-2021
    /// and `Q` 2016-2017, each alone on its line.
    /// `entries` lists each entry in the order of the CV as `token:value`, the value the year of a certification or the
    /// period of a study (`-` for none); a study with no degree line shows a `*` after its token. `unplaced` lists the
    /// lines left in the text not imported.
    struct Row: Sendable, CustomTestStringConvertible {
        let name: String
        let body: String
        let entries: String
        var unplaced: [String] = []
        var testDescription: String { name }
    }

    static let rows: [Row] = [
        // The section starts with an entry and both neighbours are bare: the period goes above.
        Row(name: "bare C over C", body: "C1 P C2", entries: "C1:2021 C2:-"),
        Row(name: "bare C over S", body: "C1 P S2", entries: "C1:2021 S2:-"),
        Row(name: "bare C over M", body: "C1 P M2", entries: "C1:2021 M2:-"),
        Row(name: "bare S over C", body: "S1 P C2", entries: "S1:2019-2021 C2:-"),
        Row(name: "bare S over S", body: "S1 P S2", entries: "S1:2019-2021"),
        Row(name: "bare S over M", body: "S1 P M2", entries: "S1:2019-2021"),
        Row(name: "bare M over C", body: "M1 P C2", entries: "M1:2019-2021 C2:-"),
        Row(name: "bare M over S", body: "M1 P S2", entries: "M1:2019-2021"),
        Row(name: "bare M over M", body: "M1 P M2", entries: "M1:2019-2021"),
        // (A study with no date under a study with one is read as its detail, by the entry reader: not the rule here.)
        // The entry above has a date of its own: the period goes to the entry below.
        Row(name: "dated C over bare C", body: "C1d P C2", entries: "C1:2018 C2:2021"),
        Row(name: "dated C over bare S", body: "C1d P S2", entries: "C1:2018 S2:2019-2021"),
        Row(name: "dated C over bare M", body: "C1d P M2", entries: "C1:2018 M2:2019-2021"),
        Row(name: "dated S over bare C", body: "S1d P C2", entries: "S1:2010-2014 C2:2021"),
        Row(name: "dated S over bare S", body: "S1d P S2", entries: "S1:2010-2014 S2:2019-2021"),
        Row(name: "dated S over bare M", body: "S1d P M2", entries: "S1:2010-2014 M2:2019-2021"),
        Row(name: "dated M over bare C", body: "M1d P C2", entries: "M1:2012-2014 C2:2021"),
        Row(name: "dated M over bare S", body: "M1d P S2", entries: "M1:2012-2014 S2:2019-2021"),
        Row(name: "dated M over bare M", body: "M1d P M2", entries: "M1:2012-2014 M2:2019-2021"),
        // The entry below has a date of its own: the period goes to the entry above.
        Row(name: "bare C over dated C", body: "C1 P C2d", entries: "C1:2021 C2:2018"),
        Row(name: "bare C over dated S", body: "C1 P S2d", entries: "C1:2021 S2:2010-2014"),
        Row(name: "bare C over dated M", body: "C1 P M2d", entries: "C1:2021 M2:2012-2014"),
        Row(name: "bare S over dated C", body: "S1 P C2d", entries: "S1:2019-2021 C2:2018"),
        Row(name: "bare S over dated S", body: "S1 P S2d", entries: "S1:2019-2021 S2:2010-2014"),
        Row(name: "bare S over dated M", body: "S1 P M2d", entries: "S1:2019-2021 M2:2012-2014"),
        Row(name: "bare M over dated C", body: "M1 P C2d", entries: "M1:2019-2021 C2:2018"),
        Row(name: "bare M over dated S", body: "M1 P S2d", entries: "M1:2019-2021 S2:2010-2014"),
        Row(name: "bare M over dated M", body: "M1 P M2d", entries: "M1:2019-2021 M2:2012-2014"),
        // The section starts with a period and both neighbours are bare: each period goes to the entry below it.
        Row(name: "dates first, C then C", body: "Q C1 P C2", entries: "C1:2017 C2:2021"),
        Row(name: "dates first, C then S", body: "Q C1 P S2", entries: "C1:2017 S2:2019-2021"),
        Row(name: "dates first, C then M", body: "Q C1 P M2", entries: "C1:2017 M2:2019-2021"),
        Row(name: "dates first, S then C", body: "Q S1 P C2", entries: "S1:2016-2017 C2:2021"),
        Row(name: "dates first, S then S", body: "Q S1 P S2", entries: "S1:2016-2017 S2:2019-2021"),
        Row(name: "dates first, S then M", body: "Q S1 P M2", entries: "S1:2016-2017 M2:2019-2021"),
        Row(name: "dates first, M then C", body: "Q M1 P C2", entries: "M1:2016-2017 C2:2021"),
        Row(name: "dates first, M then S", body: "Q M1 P S2", entries: "M1:2016-2017 S2:2019-2021"),
        Row(name: "dates first, M then M", body: "Q M1 P M2", entries: "M1:2016-2017 M2:2019-2021"),
        // The period is the last line: it goes to the entry above it, whichever way the section starts.
        Row(name: "last: C", body: "C1 P", entries: "C1:2021"),
        Row(name: "last: S", body: "S1 P", entries: "S1:2019-2021"),
        Row(name: "last: M", body: "M1 P", entries: "M1:2019-2021"),
        Row(name: "last: S then C", body: "S1 C2 P", entries: "S1:- C2:2021"),
        Row(name: "last, dates first: C then C", body: "Q C1 C2 P", entries: "C1:2017 C2:2021"),
        Row(name: "last, dates first: C then S", body: "Q C1 S2 P", entries: "C1:2017 S2:2019-2021"),
        Row(name: "last, dates first: C then M", body: "Q C1 M2 P", entries: "C1:2017 M2:2019-2021"),
        // A period between the degree line and the school line of one study: the school's line is the study's, the
        // degree stays in the text not imported (a degree over its dates and then its school).
        Row(name: "inside M", body: "M1a P M1b", entries: "M1*:2019-2021", unplaced: ["M1a"]),
        Row(name: "inside M, C above", body: "C1 M1a P M1b", entries: "C1:- M1*:2019-2021", unplaced: ["M1a"]),
        Row(name: "inside M, dated C above", body: "C1d M1a P M1b", entries: "C1:2018 M1*:2019-2021", unplaced: ["M1a"]),
        Row(name: "inside M, C below", body: "M1a P M1b C2", entries: "M1*:2019-2021 C2:-", unplaced: ["M1a"]),
    ]

    // MARK: The test

    @Test("A period on its own line follows the rule", arguments: PeriodShapesTests.rows, PeriodShapesTests.languages)
    func theRule(row: Row, words: Words) throws {
        let lines = row.body.split(separator: " ").map { Token(String($0)) }
        let text = "Tobias Renn\ntobias.renn@example.com\n\n\(words.heading)\n" + lines.map { $0.text(words) }.joined(separator: "\n")
        let found = try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)

        let order = lines.map(\.entry)
        let certificates = found.cv.certifications.map { certificate -> (String, String) in
            let index = words.certificates.firstIndex { $0.name == certificate.name.value }
            let token = index.map { "C\($0 + 1)" } ?? "C?\(certificate.name.value)"
            let issuer = index.map { words.certificates[$0].issuer } == certificate.issuer?.value
            return (token + (issuer ? "" : "(issuer \(certificate.issuer?.value ?? "none"))"), certificate.year.map { "\($0.value)" } ?? "-")
        }
        let studies = found.cv.education.map { study -> (String, String) in
            let all = words.studies.map { ("S", $0) } + words.twoLines.map { ("M", $0) }
            let byDegree = all.indices.first { all[$0].1.degree == study.degree?.value }
            let bySchool = all.indices.first { all[$0].1.school == study.school?.value }
            let index = byDegree ?? bySchool
            let token = index.map { "\(all[$0].0)\($0 % 2 + 1)" } ?? "S?\(study.degree?.value ?? "") \(study.school?.value ?? "")"
            let school = byDegree == nil || byDegree == bySchool
            let shown = token + (study.degree == nil ? "*" : "") + (school ? "" : "(school \(study.school?.value ?? "none"))")
            return (shown, study.period.map(Self.show) ?? "-")
        }
        let actual = (certificates + studies)
            .sorted { rank($0.0, in: order) < rank($1.0, in: order) }
            .map { "\($0.0):\($0.1)" }.joined(separator: " ")

        #expect(actual == row.entries, "\(row.name) (\(words.language)): \(found.unplaced.map(\.text))")
        let expectedUnplaced = lines.filter { row.unplaced.contains($0.token) }.map { $0.text(words) }
        #expect(found.unplaced.map(\.text) == expectedUnplaced, "\(row.name) (\(words.language))")
        #expect(Coverage.lost(found).isEmpty, "\(row.name) (\(words.language)): \(Coverage.describe(Coverage.lost(found)))")
    }

    private func rank(_ shown: String, in order: [String?]) -> Int {
        order.firstIndex { $0.map { shown.hasPrefix($0) } == true } ?? order.count
    }

    private static func show(_ period: Sourced<ImportedPeriod>) -> String {
        let end: String
        switch period.value.end {
        case .date(let date)?: end = "\(date.year)"
        case .current?: end = "current"
        case .unstated?: end = "open"
        case nil: end = "-"
        }
        return "\(period.value.start.year)-\(end)"
    }

    /// One token of a row's body.
    struct Token: Sendable {
        let token: String

        init(_ token: String) { self.token = token }

        /// The entry the token belongs to (`C1`, `S2`, `M1`), nil for a period.
        var entry: String? {
            token.first == "P" || token.first == "Q" ? nil : String(token.prefix(2))
        }

        func text(_ words: Words) -> String {
            switch token {
            case "P": return "2019–2021"
            case "Q": return "2016–2017"
            default: break
            }
            let number = (Int(String(token.dropFirst().prefix(1))) ?? 1) - 1
            let dated = token.hasSuffix("d")
            switch token.first {
            case "C":
                let certificate = words.certificates[number]
                return "\(certificate.name) — \(certificate.issuer)" + (dated ? ", 2018" : "")
            case "S":
                let study = words.studies[number]
                return "\(study.degree) — \(study.school)" + (dated ? ", 2010–2014" : "")
            default:
                let study = words.twoLines[number]
                if token.hasSuffix("a") { return study.degree }
                if token.hasSuffix("b") { return study.school }
                return "\(study.degree)\n\(study.school)" + (dated ? ", 2012–2014" : "")
            }
        }
    }
}
