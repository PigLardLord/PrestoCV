import Testing
import CVDrafting
import CVDraftingTestSupport

// MARK: - Every field is under the limits

@Suite("CVDraft limits cover every field (#93)")
struct DraftLimitCoverageTests {
    @Test("the full fixture fills every field, so the checks below see all of them")
    func fixtureIsFull() {
        #expect(FieldPaths(of: DraftFixtures.full).nilOrEmpty.isEmpty)
    }

    @Test("every text field of a draft has an oversize case")
    func everyText() {
        #expect(FieldPaths(of: DraftFixtures.full).texts == Set(oversizedTextSetters.map(\.0)))
    }

    @Test("every list of a draft has an oversize case")
    func everyList() {
        #expect(FieldPaths(of: DraftFixtures.full).lists == Set(oversizedListSetters.map(\.0)))
    }
}

/// The field paths of a value, by kind, with array indices dropped: `jobs[].role`, not `jobs[0].role`.
struct FieldPaths {
    var texts: Set<String> = [], lists: Set<String> = []
    private var present: Set<String> = [], absent: Set<String> = []
    /// Optionals that are nil, and lists that are empty, in every element that has them.
    var nilOrEmpty: Set<String> { absent.subtracting(present) }

    init(of value: Any) { walk(value, path: "") }

    private mutating func walk(_ value: Any, path: String) {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first else { absent.insert(path); return }
            present.insert(path)
            walk(wrapped.value, path: path); return
        }
        if value is String { texts.insert(path); return }
        if mirror.displayStyle == .collection {
            lists.insert(path)
            if mirror.children.isEmpty { absent.insert(path) } else { present.insert(path) }
            for child in mirror.children { walk(child.value, path: path + "[]") }
            return
        }
        for child in mirror.children { walk(child.value, path: path.isEmpty ? child.label ?? "?" : path + "." + (child.label ?? "?")) }
    }
}

/// Each sets one text of the full fixture over the limit, and names it.
let oversizedTextSetters: [(String, @Sendable (inout CVDraft, String) -> Void)] = {
    var setters: [(String, @Sendable (inout CVDraft, String) -> Void)] = []
    setters.append(("person.fullName", { $0.person.fullName = $1 }))
    setters.append(("person.professionalTitle", { $0.person.professionalTitle = $1 }))
    setters.append(("person.email", { $0.person.email = $1 }))
    setters.append(("person.phone", { $0.person.phone = $1 }))
    setters.append(("person.location", { $0.person.location = $1 }))
    setters.append(("person.website", { $0.person.website = $1 }))
    setters.append(("person.summary", { $0.person.summary = $1 }))
    setters.append(("jobs[].role", { $0.jobs[1].role = $1 }))
    setters.append(("jobs[].company", { $0.jobs[1].company = $1 }))
    setters.append(("jobs[].location", { $0.jobs[1].location = $1 }))
    setters.append(("jobs[].description", { $0.jobs[1].description = $1 }))
    setters.append(("education[].degree", { $0.education[0].degree = $1 }))
    setters.append(("education[].school", { $0.education[0].school = $1 }))
    setters.append(("education[].description", { $0.education[0].description = $1 }))
    setters.append(("skills[].name", { $0.skills[1].name = $1 }))
    setters.append(("languages[].name", { $0.languages[1].name = $1 }))
    setters.append(("certifications[].name", { $0.certifications[0].name = $1 }))
    setters.append(("certifications[].issuer", { $0.certifications[0].issuer = $1 }))
    setters.append(("interests[]", { $0.interests[0] = $1 }))
    return setters
}()

/// Each makes one list of the full fixture longer than the limit, and names it.
let oversizedListSetters: [(String, @Sendable (inout CVDraft) -> Void)] = {
    let over = DraftCV.maxItems + 1
    var setters: [(String, @Sendable (inout CVDraft) -> Void)] = []
    setters.append(("jobs", { $0.jobs = Array(repeating: $0.jobs[0], count: over) }))
    setters.append(("education", { $0.education = Array(repeating: $0.education[0], count: over) }))
    setters.append(("skills", { $0.skills = Array(repeating: $0.skills[0], count: over) }))
    setters.append(("languages", { $0.languages = Array(repeating: $0.languages[0], count: over) }))
    setters.append(("certifications", { $0.certifications = Array(repeating: $0.certifications[0], count: over) }))
    setters.append(("interests", { $0.interests = Array(repeating: $0.interests[0], count: over) }))
    return setters
}()

/// A draft that breaks one size limit, named after the field that breaks it.
struct OversizedDraft: Sendable, CustomTestStringConvertible {
    let field: String, draft: CVDraft
    var testDescription: String { field }
}

/// Built step by step, so the type checker stays fast.
let oversizedDrafts: [OversizedDraft] = {
    let long = String(repeating: "x", count: DraftCV.maxTextScalars + 1)
    var drafts: [OversizedDraft] = []
    for (field, set) in oversizedTextSetters {
        var draft = DraftFixtures.full
        set(&draft, long)
        drafts.append(OversizedDraft(field: field, draft: draft))
    }
    // Few characters, many scalars: combining marks cannot stretch the limit.
    var summary = DraftFixtures.full
    summary.person.summary = "e" + String(repeating: "\u{301}", count: DraftCV.maxTextScalars)
    drafts.append(OversizedDraft(field: "person.summary, in combining marks", draft: summary))
    for (field, set) in oversizedListSetters {
        var draft = DraftFixtures.full
        set(&draft)
        drafts.append(OversizedDraft(field: field + ", in items", draft: draft))
    }
    return drafts
}()
