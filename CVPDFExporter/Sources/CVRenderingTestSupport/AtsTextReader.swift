import Foundation
import CVDocumentModel
import CVRendering

/// How a naive parser reads the text of a printed CV (#121): line by line, with no layout analysis, expecting the lines
/// that MyCv's markup contract prints, not cv-giovanni's. It reports four floors that gate whatever the score is, and a
/// score that is never presented as what an applicant tracking system does.
public struct AtsReading: Equatable, Sendable {
    public enum Floor: String, Sendable { case sections, email, roles, chronology }
    public let failedFloors: [Floor]
    /// How many of the document's printed fields the text holds, of how many it was given.
    public let recovered: Int, expected: Int
    public var score: Double { expected == 0 ? 1 : Double(recovered) / Double(expected) }

    /// `text` is the output of `pdftotext` in either order.
    public init(text: String, document: CVDocument, headings: Headings) {
        let page = AtsPage(text), expectation = AtsExpectation(document, headings)
        var failed: [Floor] = []
        if !expectation.sectionsFound(in: page) { failed.append(.sections) }
        if let email = document.person.email, !page.joined.contains(AtsPage.normalize(email)) { failed.append(.email) }
        let located = expectation.locateRoles(in: page)
        if located.contains(where: { $0 == nil }) { failed.append(.roles) }
        if !expectation.chronologyHolds(located) { failed.append(.chronology) }
        failedFloors = failed
        recovered = expectation.fields.filter { page.joined.contains($0) }.count
        expected = expectation.fields.count
    }

    public var passesFloors: Bool { failedFloors.isEmpty }
}

struct AtsPage {
    let lines: [String], joined: String

    init(_ text: String) {
        lines = text.components(separatedBy: .newlines).map(Self.normalize).filter { !$0.isEmpty }
        joined = Self.normalize(text)
    }

    /// Lower case, no white space: how a parser compares a line that a PDF may have spaced out differently.
    static func normalize(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { !$0.properties.isWhitespace })
    }

    func index(of line: String, from start: Int = 0) -> Int? {
        lines.indices.first { $0 >= start && lines[$0] == line }
    }
}

struct AtsExpectation {
    struct Role { let title: String, company: String, period: String?, startYear: Int? }
    let headings: [String], roles: [Role], fields: [String]

    init(_ document: CVDocument, _ h: Headings) {
        let norm = AtsPage.normalize
        headings = document.sections.compactMap { AtsFixtureText.heading(of: $0, h) }.map(norm)
        roles = document.sections.flatMap { section -> [Role] in
            guard case .experience(let items) = section else { return [] }
            return items.map { Role(title: norm($0.role), company: norm($0.company), period: $0.period.map { norm(AtsFixtureText.period($0, h)) },
                                    startYear: $0.period?.start.year) }
        }
        fields = AtsFixtureText.fields(document).map(norm) + headings
    }

    func sectionsFound(in page: AtsPage) -> Bool {
        var from = 0
        for heading in headings {
            guard let at = page.index(of: heading, from: from) else { return false }
            from = at + 1
        }
        return true
    }

    /// For each role, where its title is, if its company follows at once and its period within the next lines.
    func locateRoles(in page: AtsPage) -> [Int?] {
        roles.map { role in
            guard let at = page.index(of: role.title), page.lines.indices.contains(at + 1), page.lines[at + 1] == role.company else { return nil }
            guard let period = role.period else { return at }
            return page.lines[(at + 1)..<min(at + 5, page.lines.count)].contains(period) ? at : nil
        }
    }

    /// The roles, in the order the text prints them, run through time in one direction.
    func chronologyHolds(_ located: [Int?]) -> Bool {
        let years = zip(roles, located).compactMap { role, at in at.flatMap { at in role.startYear.map { (at, $0) } } }
            .sorted { $0.0 < $1.0 }.map(\.1)
        let pairs = zip(years, years.dropFirst())
        return pairs.allSatisfy { $0 <= $1 } || pairs.allSatisfy { $0 >= $1 }
    }
}
