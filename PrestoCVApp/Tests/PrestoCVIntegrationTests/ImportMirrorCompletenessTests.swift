import Testing
import Foundation
import PrestoCVDomain
import PrestoCVImporting
import PrestoCVImportingTestSupport
import PrestoCVIntegration
import PrestoCVWorkflowPorts

// MARK: The inventory of what an import holds

/// The leaves of an `ImportedCV`, one per value with its evidence (`Sourced` is one leaf), per whole-entry check and per
/// enum, at normalised paths (`[i]` is `[]`). A nil value is a leaf too, so that an empty fixture field shows.
private func importLeaves(_ cv: ImportedCV) -> [Leaf] {
    let all = leaves(cv)
    let sourced = Set(all.compactMap { leaf in leaf.path.range(of: ".value").map { String(leaf.path[..<$0.lowerBound]) } })
    var result: [Leaf] = sourced.sorted().map { Leaf(path: $0, value: "present") }
    result += all.filter { leaf in !sourced.contains { leaf.path == $0 || leaf.path.hasPrefix($0 + ".") } }
    return result.map { Leaf(path: normalised($0.path), value: $0.value) }
}

private func normalised(_ path: String) -> String {
    path.replacingOccurrences(of: #"\[\d+\]"#, with: "[]", options: .regularExpression)
}

/// The path of a field of `ImportedCV.fields` as the inventory names it.
private func inventoryPath(_ field: ImportedField) -> String {
    let path = normalised(field.path)
    for kind in ["linkedIn", "gitHub", "xing", "website"] where path == "person.links[]." + kind { return "person.links[].address" }
    return path
}

private func index(of field: ImportedField) -> Int {
    guard let match = field.path.firstMatch(of: /\[(\d+)\]/), let value = Int(match.1) else { preconditionFailure("no index in \(field.path)") }
    return value
}

// MARK: Where each leaf goes

private typealias Destination = @Sendable (ImportedField, ImportOutcome) -> Bool

/// Inventory paths the tables know. A path is in exactly one table: `mapped` (the value is in the CV, typed or as text) or
/// `reported` (the value is not in the CV: the review and the text not imported hold it). A path that is in
/// neither makes the test fail, so a field added to `ImportedCV` cannot go unseen.
private let mapped: [String: Destination] = [
    "person.name": inCV, "person.title": inCV, "person.email": inCV, "person.phone": inCV, "person.location": inCV,
    "person.summary": inCV, "person.links[].address": inCV,
    "experience[].role": inCV, "experience[].employer": inCV, "experience[].location": inCV, "experience[].details[]": inCV,
    "education[].degree": inCV, "education[].school": inCV, "education[].details[]": inCV,
    "skills[]": inCV, "languages[].name": inCVOrListed, "languages[].level": inCV,
    "certifications[].name": inCV, "certifications[].issuer": inCV, "interests[]": inCV,
]

private let reported: [String: Destination] = [
    "person.links[].kind": { _, _ in true },   // the kind decides where the address goes: the address is checked
    "languages[].heading": { _, _ in true },   // the heading a language the CV cannot take is listed under: its name is checked
    "experience[].check": checkReported, "education[].check": checkReported,
    "experience[].period": { field, outcome in periodKeptOrReported(field, outcome, section: .experience) },
    "education[].period": { field, outcome in periodKeptOrReported(field, outcome, section: .education) },
    "education[].location": { field, outcome in outcome.notImported.contains(field.value) },
    "languages[].levelWords": { field, outcome in outcome.notImported.contains(field.value) },
    "certifications[].year": { field, outcome in
        leaves(outcome.cv).contains { $0.path.hasSuffix("issued.year") && $0.value == field.value }
            || outcome.review.contains { $0.field == .certificationYear(index(of: field) + 1) }
    },
]

private func inCV(_ field: ImportedField, _ outcome: ImportOutcome) -> Bool {
    leaves(outcome.cv).contains { $0.value == field.value || ($0.value.contains(field.value) && field.path.contains("details")) }
}

private func inCVOrListed(_ field: ImportedField, _ outcome: ImportOutcome) -> Bool {
    inCV(field, outcome) || outcome.notImported.contains(field.value)
}

private func checkReported(_ field: ImportedField, _ outcome: ImportOutcome) -> Bool {
    outcome.review.contains { $0.reason.rawValue == field.value }
}

private enum Section { case experience, education }

private func periodKeptOrReported(_ field: ImportedField, _ outcome: ImportOutcome, section: Section) -> Bool {
    let entry = index(of: field)
    switch section {
    case .experience:
        return outcome.cv.sections.experiences[entry].period != nil || outcome.review.contains { $0.field == .experiencePeriod(entry + 1) }
    case .education:
        return outcome.cv.sections.education[entry].period != nil || outcome.review.contains { $0.field == .educationPeriod(entry + 1) }
    }
}

/// The paths of `fields` that the tables do not know, or whose value is nowhere in the outcome.
private func lost(_ fields: [ImportedField], in outcome: ImportOutcome) -> [String] {
    fields.compactMap { field in
        let path = inventoryPath(field)
        guard let destination = mapped[path] ?? reported[path] else { return field.path + " (no table knows it)" }
        return destination(field, outcome) ? nil : field.path
    }
}

private func unknown(_ paths: [String]) -> [String] { paths.filter { mapped[$0] == nil && reported[$0] == nil } }

@Suite("Import mirror completeness")
struct ImportMirrorCompletenessTests {
    private let outcome = ImportedCVMapper().map(FullImport.result, id: FixedID().id)

    @Test("the fixture fills every field of ImportedCV, and the list of fields names each of them")
    func fixtureFillsEveryFieldOfImportedCV() {
        let inventory = importLeaves(FullImport.result.cv)
        let filled = Set(inventory.filter { $0.value != "<nil>" && $0.value != "<empty>" }.map(\.path))
        #expect(Set(inventory.map(\.path)).subtracting(filled) == [], "a field the fixture leaves empty in every entry")
        let fieldPaths = Set(FullImport.result.cv.fields.map(inventoryPath))
        // The kind of a link and the heading of a language name where a value goes; they are not values of the person
        #expect(Set(inventory.map(\.path)).subtracting(fieldPaths).subtracting(["person.links[].kind", "languages[].heading"]) == [],
                "a field of ImportedCV that `fields` does not list")
        #expect(fieldPaths.subtracting(Set(inventory.map(\.path))) == [])
        let values = FullImport.result.cv.fields.map(\.value)
        #expect(Set(values).count == values.count, "a value repeats, so one field could stand for another")
    }

    @Test("every leaf of the import is in the CV, or reported and listed in the text not imported")
    func everyImportedLeafIsMappedReportedOrListed() {
        let inventory = Set(importLeaves(FullImport.result.cv).map(\.path))
        #expect(unknown(inventory.sorted()) == [], "paths no table knows")
        #expect(lost(FullImport.result.cv.fields, in: outcome) == [])
        #expect(Set(mapped.keys).isDisjoint(with: reported.keys))
        #expect(Set(mapped.keys).union(reported.keys).subtracting(inventory) == [], "a table names a field ImportedCV has not")
    }

    @Test("a leaf the tables do not know is found")
    func aLeafTheTablesDoNotKnowFails() {
        #expect(unknown(["person.name", "person.pronouns"]) == ["person.pronouns"])
    }

    @Test("a mapper that drops a leaf is found")
    func aMapperThatDropsALeafFails() {
        var cv = outcome.cv
        var personal = cv.personal
        personal.email = nil
        cv.setPersonalDetails(personal)
        let dropping = ImportOutcome(cv: cv, review: outcome.review, saving: outcome.saving, notImported: outcome.notImported)
        #expect(lost(FullImport.result.cv.fields, in: dropping) == ["person.email"])
    }
}
