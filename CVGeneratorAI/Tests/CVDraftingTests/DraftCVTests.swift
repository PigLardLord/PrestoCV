import Testing
import Foundation
import CVDrafting
import CVDraftingTestSupport

let description = "Engineer at Analytical since March 2019, Swift and Git, Italian native, English C1."

@Suite("DraftCV (#93)")
struct DraftCVTests {
    @Test("a valid request returns the model's draft unchanged, from the trimmed description")
    func drafts() async throws {
        let generator = FakeDraftGenerator(answer: .draft(DraftFixtures.full))
        #expect(try await DraftCV(generator: generator)("  \n\(description)\n ", language: "it") == DraftFixtures.full)
        #expect(await generator.requests == [.init(description: description, language: "it")])
    }

    @Test("the language reaches the model as a canonical BCP 47 tag", arguments: [
        ("it", "it"), (" pt-br ", "pt-BR"), ("ZH-hant-tw", "zh-Hant-TW"), ("es-419", "es-419"), ("sr-latn", "sr-Latn"),
    ])
    func language(given: String, sent: String) async throws {
        let generator = FakeDraftGenerator(answer: .draft(DraftFixtures.full))
        _ = try await DraftCV(generator: generator)(description, language: given)
        #expect(await generator.requests.map(\.language) == [sent])
    }

    @Test("a description at either length limit is accepted")
    func lengthLimits() async throws {
        let generator = FakeDraftGenerator(answer: .draft(DraftFixtures.full))
        let use = DraftCV(generator: generator)
        _ = try await use(String(repeating: "x", count: DraftCV.minDescriptionCharacters), language: "en")
        _ = try await use(String(repeating: "x", count: DraftCV.maxDescriptionCharacters), language: "en")
        #expect(await generator.requests.count == 2)
    }

    @Test("an input that cannot be drafted is refused before the model is asked", arguments: invalidInputs)
    func invalidInput(input: InvalidInput) async throws {
        let generator = FakeDraftGenerator(answer: .draft(DraftFixtures.full))
        await #expect(throws: input.error) { _ = try await DraftCV(generator: generator)(input.text, language: input.language) }
        #expect(await generator.requests.isEmpty)
    }

    @Test("an unavailable model is reported with its reason, and not asked", arguments: DraftAvailability.Reason.allCases)
    func unavailable(reason: DraftAvailability.Reason) async throws {
        let generator = FakeDraftGenerator(availability: .unavailable(reason), answer: .draft(DraftFixtures.full))
        await #expect(throws: DraftingError.unavailable(reason)) { _ = try await DraftCV(generator: generator)(description, language: "en") }
        #expect(await generator.requests.isEmpty)
    }

    @Test("a draft with no text in it is refused, never handed on as a CV", arguments: blankDrafts)
    func blank(draft: CVDraft) async throws {
        let generator = FakeDraftGenerator(answer: .draft(draft))
        await #expect(throws: DraftingError.emptyDraft) { _ = try await DraftCV(generator: generator)(description, language: "en") }
    }

    @Test("a draft with a single text is a draft: the gaps are the app's to report")
    func sparse() async throws {
        let draft = CVDraft(jobs: [.init(role: "Engineer")])
        #expect(try await DraftCV(generator: FakeDraftGenerator(answer: .draft(draft)))(description, language: "en") == draft)
    }

    @Test("a draft over a size limit is refused, whichever text or list is over it", arguments: oversizedDrafts)
    func oversized(oversized: OversizedDraft) async throws {
        let generator = FakeDraftGenerator(answer: .draft(oversized.draft))
        await #expect(throws: DraftingError.oversizedDraft) { _ = try await DraftCV(generator: generator)(description, language: "en") }
    }

    @Test("a draft at the size limits is accepted")
    func atLimits() async throws {
        let text = String(repeating: "x", count: DraftCV.maxTextCharacters)
        var draft = DraftFixtures.full
        draft.person.summary = text
        draft.interests = Array(repeating: "Chess", count: DraftCV.maxItems)
        #expect(try await DraftCV(generator: FakeDraftGenerator(answer: .draft(draft)))(description, language: "en") == draft)
    }

    @Test("a model failure keeps its case; any other failure is a generation failure")
    func failures() async throws {
        await #expect(throws: DraftingError.guardrailViolation) {
            _ = try await DraftCV(generator: FakeDraftGenerator(answer: .failure(.guardrailViolation)))(description, language: "en")
        }
        await #expect(throws: DraftingError.generationFailed) {
            _ = try await DraftCV(generator: FakeDraftGenerator(answer: .otherFailure))(description, language: "en")
        }
    }

    @Test("a cancelled draft ends in a cancellation, not a draft or a model failure", arguments: [
        FakeDraftGenerator.Answer.waitForCancellation, .failWhenCancelled(.generationFailed), .failWhenCancelled(.refusal),
    ])
    func cancelled(answer: FakeDraftGenerator.Answer) async throws {
        let generator = FakeDraftGenerator(answer: answer)
        let use = DraftCV(generator: generator)
        let task = Task { try await use(description, language: "en") }
        await generator.firstRequest()
        task.cancel()
        await #expect(throws: CancellationError.self) { _ = try await task.value }
    }
}

@Suite("DraftCV streaming (#93)")
struct DraftStreamTests {
    func collect(_ stream: AsyncThrowingStream<CVDraft, any Error>) async throws -> [CVDraft] {
        var drafts: [CVDraft] = []
        for try await draft in stream { drafts.append(draft) }
        return drafts
    }

    @Test("snapshots arrive as the model produces them; blank ones are skipped")
    func snapshots() async throws {
        let partial = CVDraft(person: .init(fullName: "Ada Lovelace"))
        let generator = FakeDraftGenerator(answer: .snapshots([CVDraft(), partial, DraftFixtures.full]))
        #expect(try await collect(DraftCV(generator: generator).stream(description, language: "pt-br")) == [partial, DraftFixtures.full])
        #expect(await generator.requests == [.init(description: description, language: "pt-BR")])
    }

    @Test("streaming refuses the same inputs, before the model is asked", arguments: invalidInputs)
    func invalidInput(input: InvalidInput) async throws {
        let generator = FakeDraftGenerator(answer: .snapshots([DraftFixtures.full]))
        await #expect(throws: input.error) { _ = try await collect(DraftCV(generator: generator).stream(input.text, language: input.language)) }
        #expect(await generator.requests.isEmpty)
    }

    @Test("streaming from an unavailable model is refused, and the model is not asked")
    func unavailable() async throws {
        let generator = FakeDraftGenerator(availability: .unavailable(.modelNotReady), answer: .snapshots([DraftFixtures.full]))
        await #expect(throws: DraftingError.unavailable(.modelNotReady)) { _ = try await collect(DraftCV(generator: generator).stream(description, language: "en")) }
        #expect(await generator.requests.isEmpty)
    }

    @Test("an oversized snapshot ends the stream with an error, after the snapshots before it", arguments: oversizedDrafts)
    func oversized(oversized: OversizedDraft) async throws {
        let stream = DraftCV(generator: FakeDraftGenerator(answer: .snapshots([DraftFixtures.full, oversized.draft]))).stream(description, language: "en")
        var received: [CVDraft] = []
        await #expect(throws: DraftingError.oversizedDraft) { for try await snapshot in stream { received.append(snapshot) } }
        #expect(received == [DraftFixtures.full])
    }

    @Test("a stream that ends blank, or with nothing, ends with an error")
    func blank() async throws {
        await #expect(throws: DraftingError.emptyDraft) {
            _ = try await collect(DraftCV(generator: FakeDraftGenerator(answer: .snapshots([CVDraft(), CVDraft(person: .init(fullName: " "))]))).stream(description, language: "en"))
        }
        await #expect(throws: DraftingError.emptyDraft) {
            _ = try await collect(DraftCV(generator: FakeDraftGenerator(answer: .snapshots([]))).stream(description, language: "en"))
        }
    }

    @Test("model failures keep their case in a stream too")
    func failures() async throws {
        await #expect(throws: DraftingError.contextWindowExceeded) {
            _ = try await collect(DraftCV(generator: FakeDraftGenerator(answer: .failure(.contextWindowExceeded))).stream(description, language: "en"))
        }
        await #expect(throws: DraftingError.generationFailed) {
            _ = try await collect(DraftCV(generator: FakeDraftGenerator(answer: .otherFailure)).stream(description, language: "en"))
        }
    }

    @Test("cancelling the consumer stops the model and ends the stream")
    func cancelled() async throws {
        let generator = FakeDraftGenerator(answer: .waitForCancellation)
        let stream = DraftCV(generator: generator).stream(description, language: "en")
        let task = Task {
            var count = 0
            for try await _ in stream { count += 1 }
            return count
        }
        await generator.firstRequest()
        task.cancel()
        let ended = try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask { _ = await task.result; return true }
            group.addTask { try await Task.sleep(for: .seconds(5)); return false }
            let first = try await group.next() ?? false
            group.cancelAll()
            return first
        }
        #expect(ended, "the stream should end soon after its consumer is cancelled")
    }
}

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

// MARK: - Inputs and drafts

struct InvalidInput: Sendable, CustomTestStringConvertible {
    let text: String, language: String, error: DraftingError
    var testDescription: String { "\(error) for \(text.prefix(12).debugDescription), \(language.debugDescription)" }
}

let invalidInputs: [InvalidInput] = {
    var inputs: [InvalidInput] = []
    inputs.append(InvalidInput(text: "", language: "en", error: .descriptionTooShort))
    inputs.append(InvalidInput(text: "   short   \n", language: "en", error: .descriptionTooShort))
    inputs.append(InvalidInput(text: String(repeating: "x", count: DraftCV.maxDescriptionCharacters + 1), language: "en", error: .descriptionTooLong))
    // Few characters, many scalars: combining marks cannot stretch the limit.
    inputs.append(InvalidInput(text: "e" + String(repeating: "\u{301}", count: DraftCV.maxDescriptionCharacters), language: "en", error: .descriptionTooLong))
    for language in ["", "e", "english", "en_GB", "en-", "-en", "en-GB-x", "en-Latn-GB-1996", "en-12", "ен", "e1"] {
        inputs.append(InvalidInput(text: description, language: language, error: .unsupportedLanguage))
    }
    return inputs
}()

let blankDrafts: [CVDraft] = {
    var drafts: [CVDraft] = [CVDraft()]
    drafts.append(CVDraft(person: .init(fullName: "   ", summary: "\n\t")))
    drafts.append(CVDraft(jobs: [.init(role: " ", start: .init(year: 2019), isCurrent: true)], skills: [.init(name: "")], interests: [" "]))
    return drafts
}()

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
    let long = String(repeating: "x", count: DraftCV.maxTextCharacters + 1)
    var drafts: [OversizedDraft] = []
    for (field, set) in oversizedTextSetters {
        var draft = DraftFixtures.full
        set(&draft, long)
        drafts.append(OversizedDraft(field: field, draft: draft))
    }
    // Few characters, many scalars: combining marks cannot stretch the limit.
    var summary = DraftFixtures.full
    summary.person.summary = "e" + String(repeating: "\u{301}", count: DraftCV.maxTextCharacters)
    drafts.append(OversizedDraft(field: "person.summary, in combining marks", draft: summary))
    for (field, set) in oversizedListSetters {
        var draft = DraftFixtures.full
        set(&draft)
        drafts.append(OversizedDraft(field: field + ", in items", draft: draft))
    }
    return drafts
}()
