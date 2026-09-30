import Testing
import CVDrafting
import CVDraftingTestSupport

let validDescription = "Engineer at Analytical since March 2019, Swift and Git, Italian native, English C1."

@Suite("DraftCV (#93)")
struct DraftCVTests {
    @Test("a valid request returns the model's draft unchanged, from the trimmed description")
    func drafts() async throws {
        let generator = FakeDraftGenerator(answer: .draft(DraftFixtures.full))
        #expect(try await DraftCV(generator: generator)("  \n\(validDescription)\n ", language: "it") == DraftFixtures.full)
        #expect(await generator.requests == [.init(description: validDescription, language: "it")])
    }

    @Test("the language reaches the model as a canonical BCP 47 tag", arguments: [
        ("it", "it"), (" pt-br ", "pt-BR"), ("ZH-hant-tw", "zh-Hant-TW"), ("es-419", "es-419"), ("sr-latn", "sr-Latn"),
    ])
    func language(given: String, sent: String) async throws {
        let generator = FakeDraftGenerator(answer: .draft(DraftFixtures.full))
        _ = try await DraftCV(generator: generator)(validDescription, language: given)
        #expect(await generator.requests.map(\.language) == [sent])
    }

    @Test("a description at either length limit is accepted")
    func lengthLimits() async throws {
        let generator = FakeDraftGenerator(answer: .draft(DraftFixtures.full))
        let use = DraftCV(generator: generator)
        _ = try await use(String(repeating: "x", count: DraftCV.minDescriptionCharacters), language: "en")
        _ = try await use(String(repeating: "x", count: DraftCV.maxDescriptionScalars), language: "en")
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
        await #expect(throws: DraftingError.unavailable(reason)) { _ = try await DraftCV(generator: generator)(validDescription, language: "en") }
        #expect(await generator.requests.isEmpty)
    }

    @Test("a draft with no text in it is refused, never handed on as a CV", arguments: blankDrafts)
    func blank(draft: CVDraft) async throws {
        let generator = FakeDraftGenerator(answer: .draft(draft))
        await #expect(throws: DraftingError.emptyDraft) { _ = try await DraftCV(generator: generator)(validDescription, language: "en") }
    }

    @Test("a draft with a single text is a draft: the gaps are the app's to report")
    func sparse() async throws {
        let draft = CVDraft(jobs: [.init(role: "Engineer")])
        #expect(try await DraftCV(generator: FakeDraftGenerator(answer: .draft(draft)))(validDescription, language: "en") == draft)
    }

    @Test("a draft over a size limit is refused, whichever text or list is over it", arguments: oversizedDrafts)
    func oversized(oversized: OversizedDraft) async throws {
        let generator = FakeDraftGenerator(answer: .draft(oversized.draft))
        await #expect(throws: DraftingError.oversizedDraft) { _ = try await DraftCV(generator: generator)(validDescription, language: "en") }
    }

    @Test("a draft at the size limits is accepted")
    func atLimits() async throws {
        let text = String(repeating: "x", count: DraftCV.maxTextScalars)
        var draft = DraftFixtures.full
        draft.person.summary = text
        draft.interests = Array(repeating: "Chess", count: DraftCV.maxItems)
        #expect(try await DraftCV(generator: FakeDraftGenerator(answer: .draft(draft)))(validDescription, language: "en") == draft)
    }

    @Test("a model failure keeps its case; any other failure is a generation failure")
    func failures() async throws {
        await #expect(throws: DraftingError.guardrailViolation) {
            _ = try await DraftCV(generator: FakeDraftGenerator(answer: .failure(.guardrailViolation)))(validDescription, language: "en")
        }
        await #expect(throws: DraftingError.generationFailed) {
            _ = try await DraftCV(generator: FakeDraftGenerator(answer: .unrecognisedError))(validDescription, language: "en")
        }
    }

    @Test("a cancelled draft ends in a cancellation, not a draft or a model failure", arguments: [
        FakeDraftGenerator.Answer.waitForCancellation, .failWhenCancelled(.generationFailed), .failWhenCancelled(.refusal),
    ])
    func cancelled(answer: FakeDraftGenerator.Answer) async throws {
        let generator = FakeDraftGenerator(answer: answer)
        let use = DraftCV(generator: generator)
        let task = Task { try await use(validDescription, language: "en") }
        await generator.firstRequest()
        task.cancel()
        await #expect(throws: CancellationError.self) { _ = try await task.value }
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
    inputs.append(InvalidInput(text: String(repeating: "x", count: DraftCV.maxDescriptionScalars + 1), language: "en", error: .descriptionTooLong))
    // Few characters, many scalars: combining marks cannot stretch the limit.
    inputs.append(InvalidInput(text: "e" + String(repeating: "\u{301}", count: DraftCV.maxDescriptionScalars), language: "en", error: .descriptionTooLong))
    for language in ["", "e", "english", "en_GB", "en-", "-en", "en-GB-x", "en-Latn-GB-1996", "en-12", "ен", "e1"] {
        inputs.append(InvalidInput(text: validDescription, language: language, error: .unsupportedLanguage))
    }
    return inputs
}()

let blankDrafts: [CVDraft] = {
    var drafts: [CVDraft] = [CVDraft()]
    drafts.append(CVDraft(person: .init(fullName: "   ", summary: "\n\t")))
    drafts.append(CVDraft(jobs: [.init(role: " ", start: .init(year: 2019), isCurrent: true)], skills: [.init(name: "")], interests: [" "]))
    return drafts
}()
