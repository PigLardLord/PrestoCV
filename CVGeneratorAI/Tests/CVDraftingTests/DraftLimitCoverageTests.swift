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

    @Test("every text field of a draft has an oversize case, and each case oversizes exactly that field")
    func everyText() {
        let long = String(repeating: "x", count: DraftCV.maxTextScalars + 1)
        var paths: [String] = []
        for set in oversizedTextSetters {
            var draft = DraftFixtures.full
            set(&draft, long)
            let oversized = FieldPaths(of: draft).oversized
            #expect(oversized.count == 1)
            paths.append(contentsOf: oversized)
        }
        #expect(paths.sorted() == FieldPaths(of: DraftFixtures.full).texts.sorted())
    }

    @Test("every list of a draft has an oversize case, and each case oversizes exactly that list")
    func everyList() {
        var paths: [String] = []
        for set in oversizedListSetters {
            var draft = DraftFixtures.full
            set(&draft)
            let oversized = FieldPaths(of: draft).oversized
            #expect(oversized.count == 1)
            paths.append(contentsOf: oversized)
        }
        #expect(paths.sorted() == FieldPaths(of: DraftFixtures.full).lists.sorted())
    }
}

/// The field paths of a value, by kind, with array indices dropped: `jobs[].role`, not `jobs[0].role`.
struct FieldPaths {
    var texts: Set<String> = [], lists: Set<String> = []
    /// The texts longer than `DraftCV.maxTextScalars` and the lists longer than `DraftCV.maxItems`.
    var oversized: Set<String> = []
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
        if let text = value as? String {
            texts.insert(path)
            if text.unicodeScalars.count > DraftCV.maxTextScalars { oversized.insert(path) }
            return
        }
        if mirror.displayStyle == .collection {
            lists.insert(path)
            if mirror.children.count > DraftCV.maxItems { oversized.insert(path) }
            if mirror.children.isEmpty { absent.insert(path) } else { present.insert(path) }
            for child in mirror.children { walk(child.value, path: path + "[]") }
            return
        }
        for child in mirror.children { walk(child.value, path: path.isEmpty ? child.label ?? "?" : path + "." + (child.label ?? "?")) }
    }
}

/// Each sets one text of the full fixture; the tests find out which one from the draft it builds.
let oversizedTextSetters: [@Sendable (inout CVDraft, String) -> Void] = {
    var setters: [@Sendable (inout CVDraft, String) -> Void] = []
    setters.append({ $0.person.fullName = $1 })
    setters.append({ $0.person.professionalTitle = $1 })
    setters.append({ $0.person.email = $1 })
    setters.append({ $0.person.phone = $1 })
    setters.append({ $0.person.location = $1 })
    setters.append({ $0.person.website = $1 })
    setters.append({ $0.person.summary = $1 })
    setters.append({ $0.jobs[1].role = $1 })
    setters.append({ $0.jobs[1].company = $1 })
    setters.append({ $0.jobs[1].location = $1 })
    setters.append({ $0.jobs[1].description = $1 })
    setters.append({ $0.education[0].degree = $1 })
    setters.append({ $0.education[0].school = $1 })
    setters.append({ $0.education[0].description = $1 })
    setters.append({ $0.skills[1].name = $1 })
    setters.append({ $0.languages[1].name = $1 })
    setters.append({ $0.certifications[0].name = $1 })
    setters.append({ $0.certifications[0].issuer = $1 })
    setters.append({ $0.interests[0] = $1 })
    return setters
}()

/// Each makes one list of the full fixture longer than the limit; the tests find out which one from the draft it builds.
let oversizedListSetters: [@Sendable (inout CVDraft) -> Void] = {
    let over = DraftCV.maxItems + 1
    var setters: [@Sendable (inout CVDraft) -> Void] = []
    setters.append({ $0.jobs = Array(repeating: $0.jobs[0], count: over) })
    setters.append({ $0.education = Array(repeating: $0.education[0], count: over) })
    setters.append({ $0.skills = Array(repeating: $0.skills[0], count: over) })
    setters.append({ $0.languages = Array(repeating: $0.languages[0], count: over) })
    setters.append({ $0.certifications = Array(repeating: $0.certifications[0], count: over) })
    setters.append({ $0.interests = Array(repeating: $0.interests[0], count: over) })
    return setters
}()

/// A draft that breaks one size limit, named after the field it oversizes: the name is read from the draft, not typed.
struct OversizedDraft: Sendable, CustomTestStringConvertible {
    let draft: CVDraft, note: String
    init(draft: CVDraft, note: String = "") { self.draft = draft; self.note = note }
    var field: String { FieldPaths(of: draft).oversized.sorted().joined(separator: ", ") + note }
    var testDescription: String { field }
}

/// Built step by step, so the type checker stays fast.
let oversizedDrafts: [OversizedDraft] = {
    let long = String(repeating: "x", count: DraftCV.maxTextScalars + 1)
    var drafts: [OversizedDraft] = []
    for set in oversizedTextSetters {
        var draft = DraftFixtures.full
        set(&draft, long)
        drafts.append(OversizedDraft(draft: draft))
    }
    // Few characters, many scalars: combining marks cannot stretch the limit.
    var summary = DraftFixtures.full
    summary.person.summary = "e" + String(repeating: "\u{301}", count: DraftCV.maxTextScalars)
    drafts.append(OversizedDraft(draft: summary, note: ", in combining marks"))
    for set in oversizedListSetters {
        var draft = DraftFixtures.full
        set(&draft)
        drafts.append(OversizedDraft(draft: draft))
    }
    return drafts
}()
