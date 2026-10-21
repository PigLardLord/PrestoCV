import Testing
import PrestoCVApplication
import PrestoCVCoreTestSupport

/// A store for the content of an editor that records what it writes. It can fail, and it can hold a write until the
/// test lets it finish.
@MainActor
final class EditorStoreSpy {
    struct Failure: Error {}

    private(set) var writes: [String] = []
    /// What each write was told about the store: whether it held the content already.
    private(set) var storedBeforeEachWrite: [Bool] = []
    /// The most writes that ran at the same time.
    private(set) var mostWritesAtOnce = 0
    /// What every write throws, when set: a full disk, or a cancellation.
    var failure: (any Error)?
    var fails: Bool {
        get { failure != nil }
        set { failure = newValue ? Failure() : nil }
    }
    /// While closed, a write waits until `open()`.
    private var isOpen = true
    private var writesInProgress = 0
    private var heldWrites: [CheckedContinuation<Void, Never>] = []
    private var writingWaiters: [CheckedContinuation<Void, Never>] = []

    func close() { isOpen = false }

    func open() {
        isOpen = true
        heldWrites.forEach { $0.resume() }
        heldWrites = []
    }

    /// Returns once a write has started, or once the test is cancelled, as when it runs past its time limit.
    func waitUntilWriting() async {
        guard writesInProgress == 0 else { return }
        await withTaskCancellationHandler {
            await withCheckedContinuation { writingWaiters.append($0) }
        } onCancel: {
            Task { @MainActor in self.stopWaiting() }
        }
    }

    private func stopWaiting() {
        writingWaiters.forEach { $0.resume() }
        writingWaiters = []
    }

    func write(_ content: String, isStored: Bool) async throws {
        writesInProgress += 1
        mostWritesAtOnce = max(mostWritesAtOnce, writesInProgress)
        writingWaiters.forEach { $0.resume() }
        writingWaiters = []
        defer { writesInProgress -= 1 }
        if !isOpen {
            await withCheckedContinuation { heldWrites.append($0) }
        }
        if let failure { throw failure }
        writes.append(content)
        storedBeforeEachWrite.append(isStored)
    }
}

/// What the editor's diagnostic boundary was told: the cause of each failed write.
@MainActor
final class WriteDiagnostics {
    private(set) var causes: [any Error] = []
    func report(_ cause: any Error) { causes.append(cause) }
}

/// Waits for the work a change scheduled. A test that runs past its time limit is cancelled, and so is the work, so that
/// the test ends with its failures instead of waiting for ever.
@MainActor
func finish(_ work: Task<Void, Never>?) async {
    guard let work else { return }
    await withTaskCancellationHandler {
        await work.value
    } onCancel: {
        work.cancel()
    }
}

@MainActor
@Suite("Autosave · the editor saves by itself, a second after the last change", .timeLimit(.minutes(1)))
struct AutosaveTests {
    let clock = ManualClock()
    let store = EditorStoreSpy()
    let diagnostics = WriteDiagnostics()

    /// An editing of a stored CV, unless said otherwise. Content is worth storing once it holds more than spaces.
    func autosave(content: String = "Ada", unchangedFrom written: String? = "Ada", isStored: Bool = true) -> Autosave<String> {
        Autosave(content: content, unchangedFrom: written, isStored: isStored, isWorthStoring: { $0.contains { $0 != " " } },
                 clock: clock, onWriteFailure: diagnostics.report, write: store.write)
    }

    @Test("ten changes 100 ms apart give one write, a second after the last one")
    func tenChangesGiveOneWrite() async throws {
        let autosave = autosave()
        var changes: [Task<Void, Never>] = []
        for n in 1...10 {
            changes += [autosave.changed(to: "Ada \(n)")].compactMap { $0 }
            clock.advance(by: .milliseconds(100))
        }

        clock.advance(by: .milliseconds(899))
        for earlier in changes.dropLast() {
            await finish(earlier)
        }
        #expect(store.writes.isEmpty, "Nothing is written before a second has passed since the last change")
        #expect(autosave.status == .pending)

        clock.advance(by: .milliseconds(1))
        await finish(changes.last)
        #expect(store.writes == ["Ada 10"])
        #expect(autosave.status == .upToDate)

        try await autosave.flush()
        #expect(store.writes == ["Ada 10"], "What was written is what the store holds: a flush finds nothing to write")
    }

    @Test("a flush writes at once, as when the app goes to the background, and the pause then writes nothing more")
    func flushWritesAtOnce() async throws {
        let autosave = autosave()
        let change = autosave.changed(to: "Ada Lovelace")

        try await autosave.flush()
        #expect(store.writes == ["Ada Lovelace"])
        #expect(autosave.status == .upToDate)

        clock.advance(by: .seconds(1))
        await finish(change)
        #expect(store.writes == ["Ada Lovelace"], "The write the pause would have made was made by the flush")
    }

    @Test("content that equals what is stored is never written, so its edit time stays")
    func unchangedContentIsNeverWritten() async throws {
        let autosave = autosave()
        #expect(autosave.changed(to: "Ada") == nil)

        autosave.changed(to: "Ada Lovelace")
        let back = autosave.changed(to: "Ada")
        #expect(back == nil, "A change undone before the pause ends leaves nothing to write")

        try await autosave.flush()
        clock.advance(by: .seconds(2))
        #expect(store.writes.isEmpty)
        #expect(autosave.status == .upToDate)
    }

    @Test("a failed write leaves the content in memory with a failed status, and the next flush writes it")
    func failedWriteIsRetried() async throws {
        let autosave = autosave()
        store.fails = true
        autosave.changed(to: "Ada Lovelace")

        try await autosave.flush()
        #expect(autosave.status == .failed)
        #expect(autosave.hasChangesToWrite, "The content is still to be written")

        store.fails = false
        try await autosave.flush()
        #expect(store.writes == ["Ada Lovelace"])
        #expect(autosave.status == .upToDate)
    }

    @Test("a failure stays shown while a later change waits for its pause, until a write succeeds")
    func failureStaysUntilAWriteSucceeds() async throws {
        let autosave = autosave()
        store.fails = true
        autosave.changed(to: "Ada L")
        try await autosave.flush()

        store.fails = false
        let change = autosave.changed(to: "Ada Lovelace")
        #expect(autosave.status == .failed)

        clock.advance(by: .seconds(1))
        await finish(change)
        #expect(store.writes == ["Ada Lovelace"])
        #expect(autosave.status == .upToDate)
    }

    @Test("a blank CV that is not stored yet is not stored until something is written in it")
    func blankNewCVIsNotStored() async throws {
        let autosave = autosave(content: "", unchangedFrom: "", isStored: false)
        #expect(autosave.changed(to: " ") == nil, "A change that writes nothing in the CV is not worth storing")
        try await autosave.flush()
        #expect(store.writes.isEmpty)
        #expect(!autosave.isStored)

        autosave.changed(to: "A")
        try await autosave.flush()
        #expect(store.writes == ["A"])
        #expect(autosave.isStored)
    }

    @Test("a new CV started from an example is not stored until it is changed")
    func untouchedExampleIsNotStored() async throws {
        let autosave = autosave(content: "Example", unchangedFrom: "Example", isStored: false)
        try await autosave.flush()
        #expect(store.writes.isEmpty)

        autosave.changed(to: "Example, mine")
        try await autosave.flush()
        #expect(store.writes == ["Example, mine"])
    }

    @Test("a draft that nothing stored yet is written without any change")
    func draftIsWrittenAsItIs() async throws {
        let autosave = autosave(content: "Draft", unchangedFrom: nil, isStored: false)
        let change = autosave.changed(to: "Draft")

        clock.advance(by: .seconds(1))
        await finish(change)
        #expect(store.writes == ["Draft"])
    }

    @Test("a stored CV whose content is all removed is written as it is")
    func emptiedStoredCVIsWritten() async throws {
        let autosave = autosave()
        autosave.changed(to: "")
        try await autosave.flush()
        #expect(store.writes == [""])
    }

    @Test("a change made while a write runs is written after it, and never at the same time")
    func changeDuringAWriteFollowsIt() async throws {
        let autosave = autosave()
        store.close()
        autosave.changed(to: "Ada L")
        let firstFlush = Task { try await autosave.flush() }
        await store.waitUntilWriting()
        #expect(autosave.status == .writing)

        let change = autosave.changed(to: "Ada Lovelace")
        let secondFlush = Task { try await autosave.flush() }
        // Opened after the second flush has had its turn, so that a write it started would overlap the first
        Task { store.open() }
        try await firstFlush.value
        try await secondFlush.value
        #expect(store.writes == ["Ada L", "Ada Lovelace"])
        #expect(store.mostWritesAtOnce == 1)

        clock.advance(by: .seconds(1))
        await finish(change)
        #expect(store.writes == ["Ada L", "Ada Lovelace"], "The flush wrote the change the pause was waiting for")
        #expect(autosave.status == .upToDate)
    }

    @Test("the status is reported each time it changes")
    func statusChangesAreReported() async throws {
        let autosave = autosave()
        var reported: [Autosave<String>.Status] = []
        autosave.onStatusChange = { reported.append($0) }

        let change = autosave.changed(to: "Ada Lovelace")
        clock.advance(by: .seconds(1))
        await finish(change)
        #expect(reported == [.pending, .writing, .upToDate])
    }

    @Test("each write is told whether the store holds the content: the first write of a new CV creates it, the next ones update it")
    func writesAreToldWhetherTheStoreHoldsTheContent() async throws {
        let autosave = autosave(content: "", unchangedFrom: "", isStored: false)

        autosave.changed(to: "A")
        try await autosave.flush()
        autosave.changed(to: "AB")
        try await autosave.flush()

        #expect(store.writes == ["A", "AB"])
        #expect(store.storedBeforeEachWrite == [false, true])
    }

    // MARK: - After a write ends, the content is compared with the store again

    @Test("a change that undoes the write in progress is written after it, so the store and the form agree")
    func changeThatUndoesTheWriteInProgressIsWritten() async throws {
        let autosave = autosave()
        store.close()
        let first = autosave.changed(to: "Ada L")
        clock.advance(by: .seconds(1))
        await store.waitUntilWriting()

        let back = autosave.changed(to: "Ada")
        #expect(back == nil, "The store still holds Ada: nothing differs yet")
        store.open()
        await finish(first)

        #expect(autosave.hasChangesToWrite, "The store holds Ada L now, and the form shows Ada")
        #expect(autosave.status == .pending, "The follow-up write waits for its pause")
        clock.advance(by: .seconds(1))
        await finish(autosave.scheduledWrite)
        #expect(store.writes == ["Ada L", "Ada"])
        #expect(!autosave.hasChangesToWrite)
        #expect(autosave.status == .upToDate)
    }

    @Test("a flush writes the changes made while its write ran, so it returns when the store holds the content")
    func flushDrainsTheChangesMadeDuringItsWrite() async throws {
        let autosave = autosave()
        store.close()
        autosave.changed(to: "Ada L")
        let flush = Task { try await autosave.flush() }
        await store.waitUntilWriting()

        autosave.changed(to: "Ada Lovelace")
        store.open()
        try await flush.value

        #expect(store.writes == ["Ada L", "Ada Lovelace"])
        #expect(!autosave.hasChangesToWrite, "What the flush returns for is stored")
        #expect(autosave.status == .upToDate)
    }

    @Test("a flush whose write the form undoes ends with the content the form shows")
    func flushWhoseWriteIsUndoneEndsWithTheFormsContent() async throws {
        let autosave = autosave()
        store.close()
        autosave.changed(to: "Ada L")
        let flush = Task { try await autosave.flush() }
        await store.waitUntilWriting()

        autosave.changed(to: "Ada")
        store.open()
        try await flush.value

        #expect(store.writes == ["Ada L", "Ada"])
        #expect(!autosave.hasChangesToWrite)
    }

    // MARK: - A failure that no longer matters

    @Test("a failure goes when the content returns to what the store holds, and Try Again then writes nothing")
    func failureGoesWhenTheContentIsBackInTheStore() async throws {
        let autosave = autosave()
        store.fails = true
        autosave.changed(to: "Ada L")
        try await autosave.flush()
        #expect(autosave.status == .failed)

        let back = autosave.changed(to: "Ada")
        #expect(back == nil)
        #expect(autosave.status == .upToDate, "The store holds what the form shows: there is nothing to retry")

        store.fails = false
        try await autosave.flush()
        #expect(store.writes.isEmpty)
        #expect(autosave.status == .upToDate)
    }

    @Test("a failure goes when a new CV that failed to be stored is emptied again")
    func failureGoesWhenANewCVIsEmptiedAgain() async throws {
        let autosave = autosave(content: "", unchangedFrom: "", isStored: false)
        store.fails = true
        autosave.changed(to: "A")
        try await autosave.flush()
        #expect(autosave.status == .failed)

        autosave.changed(to: " ")
        #expect(autosave.status == .upToDate, "Nothing worth storing is left")
        try await autosave.flush()
        #expect(store.writes.isEmpty)
        #expect(!autosave.isStored)
    }

    @Test("a failure stays while the content still differs from the store")
    func failureStaysWhileTheContentDiffers() async throws {
        let autosave = autosave()
        store.fails = true
        autosave.changed(to: "Ada L")
        try await autosave.flush()

        autosave.changed(to: "Ada Lo")
        #expect(autosave.status == .failed)
    }

    // MARK: - What a failure was, and a cancellation

    @Test("each failed write is reported with its cause, apart from the status")
    func failedWritesAreReportedWithTheirCause() async throws {
        let autosave = autosave()
        struct DiskFull: Error {}
        store.failure = DiskFull()
        autosave.changed(to: "Ada L")

        try await autosave.flush()
        try await autosave.flush()

        #expect(diagnostics.causes.count == 2, "Every attempt is reported, not only the first")
        #expect(diagnostics.causes.allSatisfy { $0 is DiskFull })
        #expect(autosave.status == .failed)
    }

    @Test("a write the store cancels is no failure: nothing is reported, the content stays to be written, and the flush passes the cancellation on")
    func cancelledWriteIsNotAFailure() async throws {
        let autosave = autosave()
        store.failure = CancellationError()
        autosave.changed(to: "Ada L")

        await #expect(throws: CancellationError.self) { try await autosave.flush() }

        #expect(diagnostics.causes.isEmpty)
        #expect(autosave.status == .pending, "The content is neither stored nor failed")
        #expect(autosave.hasChangesToWrite)

        store.failure = nil
        try await autosave.flush()
        #expect(store.writes == ["Ada L"])
        #expect(autosave.status == .upToDate)
    }

    @Test("a write the store cancels after a failure leaves the failure shown")
    func cancelledRetryKeepsTheFailure() async throws {
        let autosave = autosave()
        store.fails = true
        autosave.changed(to: "Ada L")
        try await autosave.flush()

        store.failure = CancellationError()
        await #expect(throws: CancellationError.self) { try await autosave.flush() }

        #expect(autosave.status == .failed, "Nothing has stored the content since the failure")
    }
}
