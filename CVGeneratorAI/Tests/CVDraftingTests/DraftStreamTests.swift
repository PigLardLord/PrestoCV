import Testing
import CVDrafting
import CVDraftingTestSupport

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
        #expect(try await collect(DraftCV(generator: generator).stream(validDescription, language: "pt-br")) == [partial, DraftFixtures.full])
        #expect(await generator.requests == [.init(description: validDescription, language: "pt-BR")])
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
        await #expect(throws: DraftingError.unavailable(.modelNotReady)) { _ = try await collect(DraftCV(generator: generator).stream(validDescription, language: "en")) }
        #expect(await generator.requests.isEmpty)
    }

    @Test("an oversized snapshot ends the stream with an error, after the snapshots before it", arguments: oversizedDrafts)
    func oversized(oversized: OversizedDraft) async throws {
        let stream = DraftCV(generator: FakeDraftGenerator(answer: .snapshots([DraftFixtures.full, oversized.draft]))).stream(validDescription, language: "en")
        var received: [CVDraft] = []
        await #expect(throws: DraftingError.oversizedDraft) { for try await snapshot in stream { received.append(snapshot) } }
        #expect(received == [DraftFixtures.full])
    }

    @Test("a stream that ends blank, or with nothing, ends with an error")
    func blank() async throws {
        await #expect(throws: DraftingError.emptyDraft) {
            _ = try await collect(DraftCV(generator: FakeDraftGenerator(answer: .snapshots([CVDraft(), CVDraft(person: .init(fullName: " "))]))).stream(validDescription, language: "en"))
        }
        await #expect(throws: DraftingError.emptyDraft) {
            _ = try await collect(DraftCV(generator: FakeDraftGenerator(answer: .snapshots([]))).stream(validDescription, language: "en"))
        }
    }

    @Test("model failures keep their case in a stream too")
    func failures() async throws {
        await #expect(throws: DraftingError.contextWindowExceeded) {
            _ = try await collect(DraftCV(generator: FakeDraftGenerator(answer: .failure(.contextWindowExceeded))).stream(validDescription, language: "en"))
        }
        await #expect(throws: DraftingError.generationFailed) {
            _ = try await collect(DraftCV(generator: FakeDraftGenerator(answer: .unrecognisedError)).stream(validDescription, language: "en"))
        }
    }

    @Test("cancelling the consumer stops the model and ends the stream")
    func cancelled() async throws {
        let generator = FakeDraftGenerator(answer: .waitForCancellation)
        let stream = DraftCV(generator: generator).stream(validDescription, language: "en")
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
