import Testing
import Foundation
import PrestoCVDomain
import PrestoCVIntegration
import CVDocumentModel

// MARK: The walker

/// A value of the CV or of the document, with the path it was found at. Paths use the property names, `[i]` for the
/// i-th element of a collection and `.case` for the payload of an enum case.
struct Leaf: Equatable {
    let path: String, value: String
}

private let absent = "<nil>", empty = "<empty>"

/// Walks a value with `Mirror` and returns every leaf in it: strings, numbers, booleans, dates, identifiers and the case
/// of every enum (its payload, if any, follows under `.case`). A nil optional and an empty collection are leaves too
/// (`absent`, `empty`), so that a field the fixture leaves empty is still in the inventory. A type the walker does not
/// know is a leaf as well, described as text: the tests then fail on it instead of skipping it.
func leaves(_ value: Any, path: String = "") -> [Leaf] {
    switch value {
    case let text as String: return [Leaf(path: path, value: text)]
    case let number as Int: return [Leaf(path: path, value: String(number))]
    case let flag as Bool: return [Leaf(path: path, value: String(flag))]
    case let number as Double: return [Leaf(path: path, value: String(number))]
    case is UUID, is Date: return [Leaf(path: path, value: String(describing: value))]
    default: break
    }
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .optional:
        return mirror.children.first.map { leaves($0.value, path: path) } ?? [Leaf(path: path, value: absent)]
    case .enum:
        let label = mirror.children.first?.label ?? String(describing: value)
        return [Leaf(path: path, value: label)] + mirror.children.flatMap { leaves($0.value, path: path + "." + ($0.label ?? "?")) }
    case .collection, .set:
        let elements = Array(mirror.children)
        if elements.isEmpty { return [Leaf(path: path + "[]", value: empty)] }
        return elements.enumerated().flatMap { leaves($0.element.value, path: path + "[\($0.offset)]") }
    case .struct, .class, .tuple:
        if mirror.children.isEmpty { return [Leaf(path: path, value: String(describing: value))] }
        return mirror.children.enumerated().flatMap { index, child in
            leaves(child.value, path: path + (path.isEmpty ? "" : ".") + (child.label ?? "\(index)"))
        }
    default:
        return [Leaf(path: path, value: String(describing: value))]
    }
}

/// `sections.experiences[2].role` becomes `sections.experiences[].role`.
private func normalised(_ path: String) -> String {
    path.replacingOccurrences(of: #"\[\d+\]"#, with: "[]", options: .regularExpression)
}

/// The indices of a path, in order.
private func indices(of path: String) -> [String] {
    path.matches(of: /\[(\d+)\]/).map { String($0.output.1) }
}

/// The pattern with its `[]` replaced, in order, by the indices.
private func instantiate(_ pattern: String, with indices: [String]) -> String {
    var result = "", remaining = indices[...], rest = Substring(pattern)
    while let range = rest.range(of: "[]") {
        result += rest[..<range.lowerBound] + "[" + (remaining.popFirst() ?? "?") + "]"
        rest = rest[range.upperBound...]
    }
    return result + rest
}

/// A document path without the position of its section: `sections[3].skills[0].name` is `sections.skills[0].name`.
private func withoutSectionPosition(_ path: String) -> String {
    path.replacingOccurrences(of: #"^sections\[\d+\]"#, with: "sections", options: .regularExpression)
}

// MARK: What goes where

/// How a value of the CV is written in the document.
private enum Written {
    case same                          // the same text or number
    case trimmed                       // the text with the white space around it removed
    case renamed([String: String])     // the case of an enum, under another name
}

private typealias Printed = [String: (document: String, written: Written)]

private let periodEnds = ["current": "present", "unknown": "unspecified", "date": "date"]

/// Every leaf of the CV that reaches the document: where it lands (same indices) and how it is written. A leaf of the
/// CV that is neither here nor in `notPrinted` fails the completeness test.
private let printed: Printed = [
    "personal.fullName": ("person.name", .trimmed),
    "personal.professionalTitle": ("person.professionalTitle", .trimmed),
    "personal.email.value": ("person.email", .same),
    "personal.phone.value": ("person.phone", .same),
    "personal.location": ("person.location", .trimmed),
    "personal.website.value": ("person.website", .same),
    "personal.summary": ("sections.summary", .trimmed),
    "sections.experiences[].role": ("sections.experience[].role", .trimmed),
    "sections.experiences[].company": ("sections.experience[].company", .trimmed),
    "sections.experiences[].location": ("sections.experience[].location", .trimmed),
    "sections.experiences[].description": ("sections.experience[].description", .trimmed),
    "sections.experiences[].period.start.year": ("sections.experience[].period.start.year", .same),
    "sections.experiences[].period.start.month": ("sections.experience[].period.start.month", .same),
    "sections.experiences[].period.end": ("sections.experience[].period.end", .renamed(periodEnds)),
    "sections.experiences[].period.end.date.year": ("sections.experience[].period.end.date.year", .same),
    "sections.experiences[].period.end.date.month": ("sections.experience[].period.end.date.month", .same),
    "sections.education[].degree": ("sections.education[].degree", .trimmed),
    "sections.education[].school": ("sections.education[].school", .trimmed),
    "sections.education[].description": ("sections.education[].description", .trimmed),
    "sections.education[].period.start.year": ("sections.education[].period.start.year", .same),
    "sections.education[].period.start.month": ("sections.education[].period.start.month", .same),
    "sections.education[].period.end": ("sections.education[].period.end", .renamed(periodEnds)),
    "sections.education[].period.end.date.year": ("sections.education[].period.end.date.year", .same),
    "sections.education[].period.end.date.month": ("sections.education[].period.end.date.month", .same),
    "sections.skills[].name": ("sections.skills[].name", .trimmed),
    "sections.skills[].level.value": ("sections.skills[].rating", .same),
    "sections.languages[].language": ("sections.languages[].language", .trimmed),
    "sections.languages[].proficiency": ("sections.languages[].level", .same),
    "sections.certifications[].name": ("sections.certifications[].name", .trimmed),
    "sections.certifications[].issuer": ("sections.certifications[].issuer", .trimmed),
    "sections.certifications[].issued.year": ("sections.certifications[].year", .same),
    "sections.certifications[].link.value": ("sections.certifications[].url", .same),
    "sections.certifications[].description": ("sections.certifications[].description", .trimmed),
    "sections.profiles[].platform": ("sections.profiles[].platform", .trimmed),
    "sections.profiles[].link.value": ("sections.profiles[].url", .same),
    "sections.interests[]": ("sections.interests[]", .trimmed),
]

/// The leaves of a CV that are deliberately not in the document, each with the reason.
private let notPrinted: [String: String] = [
    "id.raw": "the identity of the CV in the store, not content",
    "revision": "a counter of the store, not content",
    "createdAt": "bookkeeping of the store",
    "updatedAt": "bookkeeping of the store",
    "title": "the private name of the CV in the list",
    "design.design": "resolved by the export workflow into the stylesheet",
    "design.palette": "resolved by the export workflow into the palette",
    "design.fonts": "resolved by the export workflow into the fonts",
    "language.tag": "the language of the document is an argument of the export",
    "sections.certifications[].issued.month": "the document prints a certification date as a year",
]

/// The leaves of the document that no field of the CV holds: the document's own.
private func ownLeaves(of document: CVDocument) -> [String: String] {
    ["schemaVersion": String(document.schemaVersion), "language": document.language]
}

// MARK: The checks

private func positions(_ document: CVDocument) -> [String: String] {
    Dictionary(leaves(document).map { (withoutSectionPosition($0.path), $0.value) }, uniquingKeysWith: { first, _ in first })
}

/// Every leaf of the CV must be at its own place in the document, written as the table says, or be listed as not printed.
/// An unknown leaf is a problem.
private func completenessProblems(_ cv: CV, _ document: CVDocument, printed: Printed, notPrinted: [String: String]) -> [String] {
    let found = positions(document)
    var problems: [String] = []
    for leaf in leaves(cv) {
        let pattern = normalised(leaf.path)
        if notPrinted[pattern] != nil { continue }
        guard let rule = printed[pattern] else { problems.append("\(leaf.path) = \(leaf.value): neither printed nor listed"); continue }
        let place = instantiate(rule.document, with: indices(of: leaf.path))
        let expected: String
        switch rule.written {
        case .same: expected = leaf.value
        case .trimmed: expected = leaf.value.trimmingCharacters(in: .whitespacesAndNewlines)
        case .renamed(let names): expected = names[leaf.value] ?? "?\(leaf.value)"
        }
        if found[place] != expected { problems.append("\(leaf.path) = \(leaf.value): the document has \(found[place] ?? "nothing") at \(place), not \(expected)") }
    }
    return problems.sorted()
}

/// Every leaf of the document must come from a leaf of the CV or be the document's own.
private func inventedLeaves(_ cv: CV, _ document: CVDocument) -> [String] {
    let comesFromTheCV = Set(leaves(cv).compactMap { leaf in
        printed[normalised(leaf.path)].map { instantiate($0.document, with: indices(of: leaf.path)) }
    })
    let own = ownLeaves(of: document)
    var invented: [String] = []
    for leaf in leaves(document) where leaf.value != absent && leaf.value != empty {
        let path = withoutSectionPosition(leaf.path)
        if path == "sections" || comesFromTheCV.contains(path) { continue }   // "sections" is the case of a section
        if let value = own[path] {
            if value != leaf.value { invented.append("\(path) = \(leaf.value), not \(value)") }
        } else {
            invented.append("\(path) = \(leaf.value)")
        }
    }
    return invented.sorted()
}

@Suite("CV to document mirror completeness")
struct MirrorCompletenessTests {
    private func mapped(_ cv: CV) -> CVDocument { CVToDocumentMapper().map(cv, language: DocumentLanguage("it")!) }

    @Test("every leaf of the CV is printed at its own place in the document, or listed as deliberately left out")
    func everyLeafIsPrintedOrListed() {
        let cv = Fixtures.fullCV()
        #expect(completenessProblems(cv, mapped(cv), printed: printed, notPrinted: notPrinted).isEmpty,
                "\(completenessProblems(cv, mapped(cv), printed: printed, notPrinted: notPrinted))")
    }

    @Test("every leaf of the document comes from a leaf of the CV, or is the document's own: nothing is invented")
    func nothingIsInvented() {
        let cv = Fixtures.fullCV()
        #expect(inventedLeaves(cv, mapped(cv)).isEmpty, "\(inventedLeaves(cv, mapped(cv)))")
    }

    @Test("a leaf the tables do not know fails the check")
    func anUnknownLeafFails() {
        let cv = Fixtures.fullCV()
        let problems = completenessProblems(cv, mapped(cv), printed: printed.filter { $0.key != "sections.skills[].level.value" }, notPrinted: notPrinted)
        #expect(problems.contains { $0.contains("sections.skills[1].level.value") && $0.contains("neither printed nor listed") })
        #expect(completenessProblems(cv, mapped(cv), printed: [:], notPrinted: [:]).count == leaves(cv).count)
    }

    @Test("a document that drops a value of the CV fails the check")
    func aDroppedValueIsCaught() {
        let cv = Fixtures.fullCV()
        var document = mapped(cv)
        document.sections = document.sections.map {
            guard case .skills(var skills) = $0 else { return $0 }
            skills[1].rating = nil
            return .skills(skills)
        }
        let problems = completenessProblems(cv, document, printed: printed, notPrinted: notPrinted)
        #expect(problems.count == 1)
        #expect(problems.first?.contains("sections.skills[1].level.value") == true, "\(problems)")
    }

    @Test("a document that adds or changes a value the CV does not hold fails the checks")
    func anInventedValueIsCaught() {
        let cv = Fixtures.fullCV()
        var added = mapped(cv)
        added.sections = added.sections.map {
            guard case .interests(let items) = $0 else { return $0 }
            return .interests(items + ["Sailing"])
        }
        #expect(inventedLeaves(cv, added) == ["sections.interests[2] = Sailing"])
        var changed = mapped(cv)
        changed.person.location = "Atlantis"
        #expect(completenessProblems(cv, changed, printed: printed, notPrinted: notPrinted).count == 1)
    }

    @Test("no value of the fixture is used twice, so a value found in the document can only come from its own field")
    func fixtureValuesAreUnique() {
        let enumCases: Set = ["sections.languages[].proficiency", "sections.experiences[].period.end", "sections.education[].period.end"]
        let values = leaves(Fixtures.fullCV()).filter { ![absent, empty].contains($0.value) && !enumCases.contains(normalised($0.path)) }
        let duplicated = Dictionary(grouping: values, by: { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }).filter { $0.value.count > 1 }
        #expect(duplicated.isEmpty, "\(duplicated.mapValues { $0.map(\.path) })")
    }

    @Test("the fixture populates every field of the CV, except the listed ones that only the store sets")
    func theFixtureIsFullyPopulated() {
        let all = leaves(Fixtures.fullCV())
        let populated = Set(all.filter { ![absent, empty].contains($0.value) }.map { normalised($0.path) })
        let unset = Set(all.map { normalised($0.path) }).subtracting(populated).filter { notPrinted[$0] == nil }
        #expect(unset.isEmpty, "the fixture leaves these empty: \(unset.sorted())")
    }

    @Test("the tables have no entry for a field that no longer exists, and no field is in both")
    func noStaleEntry() {
        let patterns = Set(leaves(Fixtures.fullCV()).map { normalised($0.path) })
        #expect(Set(printed.keys).subtracting(patterns).isEmpty, "stale: \(Set(printed.keys).subtracting(patterns).sorted())")
        #expect(Set(notPrinted.keys).subtracting(patterns).isEmpty, "stale: \(Set(notPrinted.keys).subtracting(patterns).sorted())")
        #expect(Set(printed.keys).isDisjoint(with: notPrinted.keys))
    }

    @Test("the walker sees enums, booleans, numbers, nil optionals and empty collections")
    func theWalkerSeesEverything() {
        enum Colour { case red, other(Int) }
        struct Sample { let flag = true, ratio = 0.5, colour = Colour.red, payload = Colour.other(7), nothing: String? = nil, none: [Int] = [] }
        let found = Dictionary(uniqueKeysWithValues: leaves(Sample()).map { ($0.path, $0.value) })
        #expect(found == ["flag": "true", "ratio": "0.5", "colour": "red", "payload": "other", "payload.other": "7", "nothing": absent, "none[]": empty])
    }
}
