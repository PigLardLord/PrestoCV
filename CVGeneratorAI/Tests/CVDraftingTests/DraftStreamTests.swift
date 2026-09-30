import Testing
import CVDrafting
import CVDraftingTestSupport

@Suite("DraftCV streaming (#93)")
struct DraftStreamTests {
    func collect(_ stream: DraftCV.Snapshots) async throws -> [CVDraft] {
        var drafts: [CVDraft] = []
        for try await draft in stream { drafts.append(draft) }
        return drafts
    }

    /// True when the signal comes within the limit; false when it does not.
    func arrives(_ signal: AsyncStream<Void>, within limit: Duration = .seconds(5)) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in signal { return true }
                return false
            }
            group.addTask {
                try? await Task.sleep(for: limit)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    @Test("snapshots arrive as the model produces them; blank ones are skipped")
    func snapshots() async throws {
        let partial = CVDraft(person: .init(fullName: "Ada Lovelace"))
        let generator = FakeDraftGenerator(answer: .snapshots([CVDraft(), partial, DraftFixtures.full]))
        #expect(try await collect(DraftCV(generator: generator).stream(validDescription, language: "pt-br")) == [partial, DraftFixtures.full])
        #expect(await generator.requests == [.init(description: validDescription, language: "pt-BR")])
    }

    @Test("each reading of the stream is a new request")
    func eachReadingIsARequest() async throws {
        let generator = FakeDraftGenerator(answer: .snapshots([DraftFixtures.full]))
        let stream = DraftCV(generator: generator).stream(validDescription, language: "en")
        #expect(try await collect(stream) == [DraftFixtures.full])
        #expect(try await collect(stream) == [DraftFixtures.full])
        #expect(await generator.requests.count == 2)
    }

    @Test("a stream nobody reads does not ask the model")
    func unread() async {
        let generator = FakeDraftGenerator(answer: .snapshots([DraftFixtures.full]))
        do { _ = DraftCV(generator: generator).stream(validDescription, language: "en") }
        #expect(await generator.requests.isEmpty)
        #expect(await generator.happened(.asked, within: .milliseconds(100)) == false)
    }

    @Test("reading again after the end or an error returns nothing, and the model is not asked again")
    func readingAgain() async throws {
        let ending = FakeDraftGenerator(answer: .snapshots([DraftFixtures.full]))
        var atTheEnd = DraftCV(generator: ending).stream(validDescription, language: "en").makeAsyncIterator()
        #expect(try await atTheEnd.next() == DraftFixtures.full)
        #expect(try await atTheEnd.next() == nil)
        #expect(try await atTheEnd.next() == nil)
        #expect(await ending.requests.count == 1)

        let failing = FakeDraftGenerator(answer: .failure(.refusal))
        var afterError = DraftCV(generator: failing).stream(validDescription, language: "en").makeAsyncIterator()
        await #expect(throws: DraftingError.refusal) { _ = try await afterError.next() }
        #expect(try await afterError.next() == nil)
        #expect(await failing.requests.count == 1)
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

    @Test("a stream that ends on a blank snapshot ends with an error, after the snapshots before it")
    func endsBlankAfterSnapshots() async {
        let stream = DraftCV(generator: FakeDraftGenerator(answer: .snapshots([DraftFixtures.full, CVDraft()]))).stream(validDescription, language: "en")
        var received: [CVDraft] = []
        await #expect(throws: DraftingError.emptyDraft) { for try await snapshot in stream { received.append(snapshot) } }
        #expect(received == [DraftFixtures.full])
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

    @Test("a model failure after some snapshots keeps its case")
    func failureAfterSnapshots() async {
        let stream = DraftCV(generator: FakeDraftGenerator(answer: .snapshotsThenFailure([DraftFixtures.full], .rateLimited))).stream(validDescription, language: "en")
        var received: [CVDraft] = []
        await #expect(throws: DraftingError.rateLimited) { for try await snapshot in stream { received.append(snapshot) } }
        #expect(received == [DraftFixtures.full])
    }

    @Test("a cancellation the model reports on its own is a generation failure in a stream too")
    func strayCancellation() async {
        let generator = FakeDraftGenerator(answer: .strayCancellation)
        await #expect(throws: DraftingError.generationFailed) {
            _ = try await collect(DraftCV(generator: generator).stream(validDescription, language: "en"))
        }
    }

    @Test("cancelling the consumer stops the model")
    func cancelled() async {
        let generator = FakeDraftGenerator(answer: .waitForCancellation())
        let stream = DraftCV(generator: generator).stream(validDescription, language: "en")
        let reader = Task { try await collect(stream) }
        #expect(await generator.happened(.asked))
        reader.cancel()
        await #expect(throws: CancellationError.self) { _ = try await reader.value }
        #expect(await generator.happened(.stopped))
    }

    @Test("a cancelled reader ends in a cancellation after the snapshots it had")
    func cancelledAfterSnapshots() async {
        let generator = FakeDraftGenerator(answer: .waitForCancellation(after: [DraftFixtures.full]))
        let stream = DraftCV(generator: generator).stream(validDescription, language: "en")
        let firstSnapshot = AsyncStream<Void>.makeStream()
        let reader = Task { await readToTheEnd(stream) { _ in firstSnapshot.continuation.yield() } }
        #expect(await arrives(firstSnapshot.stream))
        reader.cancel()
        let reading = await reader.value
        #expect(reading.received == [DraftFixtures.full])
        #expect(reading.error is CancellationError)
        #expect(await generator.happened(.stopped))
    }

    @Test("leaving the loop stops the model, even while the stream is kept")
    func leftEarlyWhileKept() async throws {
        let generator = FakeDraftGenerator(answer: .waitForCancellation(after: [DraftFixtures.full]))
        let stream = DraftCV(generator: generator).stream(validDescription, language: "en")
        for try await _ in stream { break }
        #expect(await generator.happened(.stopped))
        withExtendedLifetime(stream) {}
    }

    @Test("a reader cancelled between two snapshots ends in a cancellation, not in the next draft or the model's failure")
    func cancelledBetweenSnapshots() async {
        var second = DraftFixtures.full
        second.person.fullName = "Grace Hopper"
        let generator = FakeDraftGenerator(answer: .snapshotsThenFailure([DraftFixtures.full, second], .rateLimited))
        let stream = DraftCV(generator: generator).stream(validDescription, language: "en")
        let gotFirst = AsyncStream<Void>.makeStream()
        let goAhead = AsyncStream<Void>.makeStream()
        let reader = Task {
            await readToTheEnd(stream) { count in
                guard count == 1 else { return }
                gotFirst.continuation.yield()
                for await _ in goAhead.stream { break }
            }
        }
        #expect(await arrives(gotFirst.stream))
        reader.cancel()
        goAhead.continuation.yield()
        let reading = await reader.value
        #expect(reading.received == [DraftFixtures.full])
        #expect(reading.error is CancellationError)
    }

    @Test("an oversized snapshot stops the model, even while the reader is kept")
    func oversizedStops() async {
        var oversized = DraftFixtures.full
        oversized.person.summary = String(repeating: "x", count: DraftCV.maxTextScalars + 1)
        let generator = FakeDraftGenerator(answer: .waitForCancellation(after: [oversized]))
        var reader = DraftCV(generator: generator).stream(validDescription, language: "en").makeAsyncIterator()
        await #expect(throws: DraftingError.oversizedDraft) { _ = try await reader.next() }
        #expect(await generator.happened(.stopped))
        withExtendedLifetime(reader) {}
    }
}

/// What a reader got: the snapshots it received, and the error it ended with, if any.
struct Reading: Sendable {
    var received: [CVDraft] = []
    var error: (any Error)?
}

/// Reads a stream to its end, calling `afterEach` with the number of snapshots received so far.
func readToTheEnd(_ stream: DraftCV.Snapshots, afterEach: @Sendable (Int) async -> Void) async -> Reading {
    var reading = Reading()
    do {
        for try await snapshot in stream {
            reading.received.append(snapshot)
            await afterEach(reading.received.count)
        }
    } catch {
        reading.error = error
    }
    return reading
}
