import Testing
import Foundation
import PrestoCVDomain
import PrestoCVIntegration
import CVDocumentModel

private let absent = "<nil>"

/// Walks a value with `Mirror` and returns every text or number in it with the path it was found at. Enum cases without
/// a payload and raw-value enums have no text or number of their own; the tests of the mapper cover them one by one.
private func leaves(_ value: Any, path: String = "") -> [(path: String, value: String)] {
    let mirror = Mirror(reflecting: value)
    switch value {
    case let text as String: return [(path, text)]
    case let number as Int: return [(path, String(number))]
    case is UUID, is Date: return [(path, String(describing: value))]
    default: break
    }
    if mirror.displayStyle == .optional {
        // A nil is a leaf too, so that a field the fixture leaves empty is still in the inventory.
        return mirror.children.first.map { leaves($0.value, path: path) } ?? [(path, absent)]
    }
    var result: [(path: String, value: String)] = []
    for (index, child) in mirror.children.enumerated() {
        let name = child.label ?? "[\(index)]"
        let step = mirror.displayStyle == .collection ? "[]" : (path.isEmpty ? name : ".\(name)")
        result += leaves(child.value, path: path + step)
    }
    return result
}

/// The fields of a CV that are deliberately not in the document, each with the reason. Adding a field to the CV that is
/// neither mapped nor listed here fails `everyFieldIsMappedOrListed`.
private let notInTheDocument: [String: String] = [
    "id.raw": "an identity of the store, not content",
    "revision": "a counter of the store, not content",
    "createdAt": "bookkeeping",
    "updatedAt": "bookkeeping",
    "title": "the private name of the CV in the list",
    "design.design": "resolved by the export workflow into the stylesheet",
    "design.palette": "resolved by the export workflow into the palette",
    "design.fonts": "resolved by the export workflow into the fonts",
    "language.tag": "the language of the document is an argument of the export",
    "sections.certifications[].issued.month": "the document prints a certification date as a year",
]

private func normalised(_ path: String) -> String {
    path.replacingOccurrences(of: #"\[\d+\]"#, with: "[]", options: .regularExpression)
}

@Suite("CV to document mirror completeness")
struct MirrorCompletenessTests {
    @Test("every populated field of the CV reaches the document, or is listed as deliberately left out")
    func everyFieldIsMappedOrListed() {
        let cv = Fixtures.fullCV()
        let document = CVToDocumentMapper().map(cv, language: DocumentLanguage("it")!)
        let printed = Set(leaves(document).map(\.value))
        var missing: [String] = []
        for leaf in leaves(cv) {
            let path = normalised(leaf.path)
            if notInTheDocument[path] != nil { continue }
            if leaf.value != absent, !printed.contains(leaf.value) { missing.append("\(path) = \(leaf.value)") }
        }
        #expect(missing.isEmpty, "not in the document and not listed: \(missing.sorted())")
    }

    @Test("every value of the document comes from a value of the CV (nothing is invented)")
    func nothingIsInvented() {
        let cv = Fixtures.fullCV()
        let document = CVToDocumentMapper().map(cv, language: DocumentLanguage("it")!)
        let known = Set(leaves(cv).map(\.value)).union([absent])
        // The schema version and the language are the document's own.
        let own: Set<String> = [String(document.schemaVersion), "it"]
        let invented = leaves(document).filter { !known.contains($0.value) && !own.contains($0.value) }
        #expect(invented.isEmpty, "\(invented.map { "\($0.path) = \($0.value)" })")
    }

    @Test("the list of left-out fields has no entry for a field that no longer exists")
    func theListHasNoStaleEntry() {
        let paths = Set(leaves(Fixtures.fullCV()).map { normalised($0.path) })
        let stale = notInTheDocument.keys.filter { !paths.contains($0) }
        #expect(stale.isEmpty, "stale entries: \(stale.sorted())")
    }

    @Test("every populated field of the CV is a leaf the walker can see")
    func theFixtureIsFullyPopulated() {
        let paths = Set(leaves(Fixtures.fullCV()).map { normalised($0.path) })
        for expected in ["personal.fullName", "personal.professionalTitle", "personal.email.value", "personal.phone.value", "personal.location",
                         "personal.website.value", "personal.summary", "sections.experiences[].role", "sections.experiences[].period.start.year",
                         "sections.education[].school", "sections.skills[].level.value", "sections.languages[].language",
                         "sections.certifications[].link.value", "sections.profiles[].link.value", "sections.interests[]"] {
            #expect(paths.contains(expected), "the fixture lacks \(expected)")
        }
    }
}
