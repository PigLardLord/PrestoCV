import Testing
import PrestoCVApplication
import PrestoCVCoreTestSupport

/// A store for the content of an editor that records what it writes. It can fail, and it can hold a write until the
/// test lets it finish.
@MainActor
final class EditorStoreSpy {
    struct Failure: Error {}

    private(set) var writes: [String] = []
    /// The most writes that ran at the same time.
    private(set) var mostWritesAtOnce = 0
    var fails = false
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

    func write(_ content: String) async throws {
        writesInProgress += 1
        mostWritesAtOnce = max(mostWritesAtOnce, writesInProgress)
        writingWaiters.forEach { $0.resume() }
        writingWaiters = []
        defer { writesInProgress -= 1 }
        if !isOpen {
            await withCheckedContinuation { heldWrites.append($0) }
        }
        if fails { throw Failure() }
        writes.append(content)
    }
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

    /// An editing of a stored CV, unless said otherwise. Content is worth storing once it holds more than spaces.
    func autosave(content: String = "Ada", unchangedFrom written: String? = "Ada", isStored: Bool = true) -> Autosave<String> {
        Autosave(content: content, unchangedFrom: written, isStored: isStored, isWorthStoring: { $0.contains { $0 != " " } },
                 clock: clock, write: store.write)
    }

    @Test("ten changes 100 ms apart give one write, a second after the last one")
    func tenChangesGiveOneWrite() async {
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

        await autosave.flush()
        #expect(store.writes == ["Ada 10"], "What was written is what the store holds: a flush finds nothing to write")
    }

    @Test("a flush writes at once, as when the app goes to the background, and the pause then writes nothing more")
    func flushWritesAtOnce() async {
        let autosave = autosave()
        let change = autosave.changed(to: "Ada Lovelace")

        await autosave.flush()
        #expect(store.writes == ["Ada Lovelace"])
        #expect(autosave.status == .upToDate)

        clock.advance(by: .seconds(1))
        await finish(change)
        #expect(store.writes == ["Ada Lovelace"], "The write the pause would have made was made by the flush")
    }

    @Test("content that equals what is stored is never written, so its edit time stays")
    func unchangedContentIsNeverWritten() async {
        let autosave = autosave()
        #expect(autosave.changed(to: "Ada") == nil)

        autosave.changed(to: "Ada Lovelace")
        let back = autosave.changed(to: "Ada")
        #expect(back == nil, "A change undone before the pause ends leaves nothing to write")

        await autosave.flush()
        clock.advance(by: .seconds(2))
        #expect(store.writes.isEmpty)
        #expect(autosave.status == .upToDate)
    }

    @Test("a failed write leaves the content in memory with a failed status, and the next flush writes it")
    func failedWriteIsRetried() async {
        let autosave = autosave()
        store.fails = true
        autosave.changed(to: "Ada Lovelace")

        await autosave.flush()
        #expect(autosave.status == .failed)
        #expect(autosave.hasChangesToWrite, "The content is still to be written")

        store.fails = false
        await autosave.flush()
        #expect(store.writes == ["Ada Lovelace"])
        #expect(autosave.status == .upToDate)
    }

    @Test("a failure stays shown while a later change waits for its pause, until a write succeeds")
    func failureStaysUntilAWriteSucceeds() async {
        let autosave = autosave()
        store.fails = true
        autosave.changed(to: "Ada L")
        await autosave.flush()

        store.fails = false
        let change = autosave.changed(to: "Ada Lovelace")
        #expect(autosave.status == .failed)

        clock.advance(by: .seconds(1))
        await finish(change)
        #expect(store.writes == ["Ada Lovelace"])
        #expect(autosave.status == .upToDate)
    }

    @Test("a blank CV that is not stored yet is not stored until something is written in it")
    func blankNewCVIsNotStored() async {
        let autosave = autosave(content: "", unchangedFrom: "", isStored: false)
        #expect(autosave.changed(to: " ") == nil, "A change that writes nothing in the CV is not worth storing")
        await autosave.flush()
        #expect(store.writes.isEmpty)
        #expect(!autosave.isStored)

        autosave.changed(to: "A")
        await autosave.flush()
        #expect(store.writes == ["A"])
        #expect(autosave.isStored)
    }

    @Test("a new CV started from an example is not stored until it is changed")
    func untouchedExampleIsNotStored() async {
        let autosave = autosave(content: "Example", unchangedFrom: "Example", isStored: false)
        await autosave.flush()
        #expect(store.writes.isEmpty)

        autosave.changed(to: "Example, mine")
        await autosave.flush()
        #expect(store.writes == ["Example, mine"])
    }

    @Test("a draft that nothing stored yet is written without any change")
    func draftIsWrittenAsItIs() async {
        let autosave = autosave(content: "Draft", unchangedFrom: nil, isStored: false)
        let change = autosave.changed(to: "Draft")

        clock.advance(by: .seconds(1))
        await finish(change)
        #expect(store.writes == ["Draft"])
    }

    @Test("a stored CV whose content is all removed is written as it is")
    func emptiedStoredCVIsWritten() async {
        let autosave = autosave()
        autosave.changed(to: "")
        await autosave.flush()
        #expect(store.writes == [""])
    }

    @Test("a change made while a write runs is written after it, and never at the same time")
    func changeDuringAWriteFollowsIt() async {
        let autosave = autosave()
        store.close()
        autosave.changed(to: "Ada L")
        let firstFlush = Task { await autosave.flush() }
        await store.waitUntilWriting()
        #expect(autosave.status == .writing)

        let change = autosave.changed(to: "Ada Lovelace")
        let secondFlush = Task { await autosave.flush() }
        // Opened after the second flush has had its turn, so that a write it started would overlap the first
        Task { store.open() }
        await finish(firstFlush)
        await finish(secondFlush)
        #expect(store.writes == ["Ada L", "Ada Lovelace"])
        #expect(store.mostWritesAtOnce == 1)

        clock.advance(by: .seconds(1))
        await finish(change)
        #expect(store.writes == ["Ada L", "Ada Lovelace"], "The flush wrote the change the pause was waiting for")
        #expect(autosave.status == .upToDate)
    }

    @Test("the status is reported each time it changes")
    func statusChangesAreReported() async {
        let autosave = autosave()
        var reported: [Autosave<String>.Status] = []
        autosave.onStatusChange = { reported.append($0) }

        let change = autosave.changed(to: "Ada Lovelace")
        clock.advance(by: .seconds(1))
        await finish(change)
        #expect(reported == [.pending, .writing, .upToDate])
    }
}
