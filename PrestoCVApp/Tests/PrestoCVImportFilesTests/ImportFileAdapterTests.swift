import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVImportFiles
import PrestoCVWorkflowPorts
import Synchronization
import Testing

@Suite("The file adapter of the import screen")
struct ImportFileAdapterTests {
    // MARK: Access and count

    @Test("each received file has its own access, and the copy goes with the last one")
    func eachReceiveHasItsOwnAccess() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let spelled = URL(fileURLWithPath: world.scratch.inbox.path + "/../app.example-Inbox/./cv.pdf")

        let first = world.adapter.receive(copy)
        let second = world.adapter.receive(spelled)
        #expect(world.files.calls.starts == [copy, spelled])

        world.adapter.release(first)
        #expect(world.files.calls.stops == [copy])
        #expect(FileManager.default.fileExists(atPath: copy.path))

        world.adapter.release(second)
        #expect(world.files.calls.stops == [copy, spelled])
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        world.expectBalanced()
    }

    @Test("two receives of one URL give two received files")
    func idsAreDistinct() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)

        let first = world.adapter.receive(copy)
        let second = world.adapter.receive(copy)

        #expect(first.id != second.id)
        #expect(first.url == copy && second.url == copy)
        world.adapter.release(first)
        world.adapter.release(second)
        world.expectBalanced()
    }

    @Test("three received files of one copy keep it until the third is released")
    func chainOfThree() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let received = (1...3).map { _ in world.adapter.receive(copy) }

        world.adapter.release(received[1])
        world.adapter.release(received[0])
        #expect(FileManager.default.fileExists(atPath: copy.path))
        #expect(world.files.calls.removed.isEmpty)

        world.adapter.release(received[2])
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        world.expectBalanced()
    }

    @Test("a second release of a file is logged and stops nothing")
    func releasedTwice() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let received = world.adapter.receive(copy)

        world.adapter.release(received)
        world.adapter.release(received)

        #expect(world.files.calls.stops.count == 1)
        #expect(world.logger.events == ["import.file.releasedAgain"])
        world.expectBalanced()
    }

    @Test("a second release of one file does not take the turn of another file of the same copy")
    func secondReleaseDoesNotTakeAnothersTurn() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let first = world.adapter.receive(copy)
        let second = world.adapter.receive(copy)

        world.adapter.release(first)
        world.adapter.release(first)
        #expect(FileManager.default.fileExists(atPath: copy.path))

        world.adapter.release(second)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        world.expectBalanced()
    }

    @Test("every name the copy was received by goes at the last release, before its access stops")
    func everyNameOfTheCopy() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let otherName = world.scratch.inbox.appendingPathComponent("cv-1.pdf")
        try FileManager.default.linkItem(at: copy, to: otherName)

        let first = world.adapter.receive(copy)
        let second = world.adapter.receive(otherName)
        world.adapter.release(first)
        world.adapter.release(second)

        #expect(try world.scratch.names(in: world.scratch.inbox) == [])
        #expect(world.files.calls.order == ["stop cv.pdf", "remove cv-1.pdf", "remove cv.pdf", "stop cv-1.pdf"])
        world.expectBalanced()
    }

    @Test("receive starts the access before it looks at the file")
    func receiveOrder() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("a.pdf", in: world.scratch.inbox)
        let before = world.files.calls.events.count

        let received = world.adapter.receive(copy)

        let events = Array(world.files.calls.events.dropFirst(before).prefix(3))
        #expect(events == ["start a.pdf", "resolve a.pdf", "identity a.pdf"])
        world.adapter.release(received)
    }

    @Test("a link pointed elsewhere after the receive still reads and lets go the file it named")
    func retargetedLink() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox, "mine")
        let other = try world.scratch.file("other.pdf", in: world.scratch.chosen, "other")
        let link = try world.scratch.link("link.pdf", to: copy)
        let received = world.adapter.receive(link)

        try world.scratch.retarget(link, to: other)

        #expect(try await world.adapter.readPDF(of: received) == Data("mine".utf8))
        world.adapter.release(received)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        #expect(try String(contentsOf: other, encoding: .utf8) == "other")
        #expect(try world.scratch.names(in: world.scratch.chosen) == ["link.pdf", "other.pdf"])
        world.expectBalanced()
    }

    // MARK: The size bound

    @Test("a file above the bound is too large, and is not a file that could not be read")
    func aboveTheBound() async throws {
        let world = try World(maximumBytes: 1_000)
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox, String(repeating: "x", count: 1_001))
        let received = world.adapter.receive(copy)

        await #expect(throws: ImportFailure.tooLarge) { try await world.adapter.readPDF(of: received) }

        #expect(world.logger.entries("import.file.notRead").isEmpty)
        world.adapter.release(received)
        world.expectBalanced()
    }

    @Test("a file at the bound is read")
    func atTheBound() async throws {
        let world = try World(maximumBytes: 1_000)
        defer { world.scratch.remove() }
        let text = String(repeating: "x", count: 1_000)
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox, text)
        let received = world.adapter.receive(copy)

        #expect(try await world.adapter.readPDF(of: received) == Data(text.utf8))
        world.adapter.release(received)
    }

    @Test(
        "a file that states a size smaller than it holds is still bound",
        .enabled(if: FileManager.default.fileExists(atPath: "/proc/self/status"))
    )
    func understatedSize() async throws {
        // /proc files state a size of 0 and hold more
        let world = try World(maximumBytes: 10)
        defer { world.scratch.remove() }
        let received = world.adapter.receive(URL(fileURLWithPath: "/proc/self/status"))

        await #expect(throws: ImportFailure.tooLarge) { try await world.adapter.readPDF(of: received) }

        world.adapter.release(received)
        #expect(world.files.calls.removed.isEmpty)
    }

    @Test("a large file is read whole")
    func largeFileReadWhole() async throws {
        let world = try World(maximumBytes: 1_000_000)
        defer { world.scratch.remove() }
        let bytes = Data((0..<200_000).map { UInt8(truncatingIfNeeded: $0) })
        let copy = world.scratch.inbox.appendingPathComponent("cv.pdf")
        try bytes.write(to: copy)
        let received = world.adapter.receive(copy)

        #expect(try await world.adapter.readPDF(of: received) == bytes)
        world.adapter.release(received)
    }

    // MARK: A file that is not there, or not the one received

    @Test("a file gone before the receive is never read and never deleted")
    func goneAtReceive() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let missing = world.scratch.inbox.appendingPathComponent("cv.pdf")
        let received = world.adapter.receive(missing)

        await #expect(throws: ImportFailure.fileNotRead) { try await world.adapter.readPDF(of: received) }

        #expect(world.logger.entries("import.file.notRead").map { $0.value("reason") } == [.token("noIdentity")])
        #expect(world.files.calls.reads.isEmpty)
        world.adapter.release(received)
        #expect(world.files.calls.removed.isEmpty)
        #expect(world.files.calls.stops.count == 1)
    }

    @Test("a file gone after the receive is not read, and the error says why")
    func goneAfterReceive() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let received = world.adapter.receive(copy)
        try FileManager.default.removeItem(at: copy)

        await #expect(throws: ImportFailure.fileNotRead) { try await world.adapter.readPDF(of: received) }

        let logged = world.logger.entries("import.file.notRead").map { $0.value("error") }
        #expect(logged == [.error(type: "ImportFileError", code: "ENOENT")])
        world.adapter.release(received)
        #expect(world.logger.entries("import.file.copyNotDeleted").isEmpty)
        world.expectBalanced()
    }

    @Test("a read after the release is refused")
    func readAfterRelease() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let received = world.adapter.receive(copy)
        world.adapter.release(received)

        await #expect(throws: ImportFailure.fileNotRead) { try await world.adapter.readPDF(of: received) }

        #expect(world.logger.entries("import.file.notRead").map { $0.value("reason") } == [.token("notReceived")])
        #expect(world.files.calls.reads.isEmpty)
    }

    @Test("a read whose task is cancelled ends as cancelled")
    func cancelledRead() async throws {
        let world = try World(faults: .init(cancelDuringRead: true))
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let received = world.adapter.receive(copy)

        let outcome = await Task { () -> Result<Data, any Error> in
            do { return .success(try await world.adapter.readPDF(of: received)) } catch { return .failure(error) }
        }.value

        guard case .failure(let error) = outcome else { Issue.record("the read of a cancelled task succeeded"); return }
        #expect(error is CancellationError)
        world.adapter.release(received)
        world.expectBalanced()
    }

    @Test("a pipe received in place of a file is never read and stays", .timeLimit(.minutes(1)))
    func fifoAtReceive() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let pipe = try world.scratch.pipe("cv.pdf", in: world.scratch.inbox)
        let received = world.adapter.receive(pipe)

        await #expect(throws: ImportFailure.fileNotRead) { try await world.adapter.readPDF(of: received) }

        #expect(world.logger.entries("import.file.notRead").map { $0.value("reason") } == [.token("noIdentity")])
        world.adapter.release(received)
        #expect(world.files.calls.reads.isEmpty)
        #expect(world.files.calls.removed.isEmpty)
        #expect(world.files.calls.stops.count == 1)
        #expect(try world.scratch.names(in: world.scratch.inbox) == ["cv.pdf"])
    }

    @Test("a pipe put in place of the received file is neither read, waited on nor deleted", .timeLimit(.minutes(1)))
    func fifoSwappedIn() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let received = world.adapter.receive(copy)
        try FileManager.default.removeItem(at: copy)
        try world.scratch.pipe("cv.pdf", in: world.scratch.inbox)

        await #expect(throws: ImportFailure.fileNotRead) { try await world.adapter.readPDF(of: received) }
        let notRead = world.logger.entries("import.file.notRead").map { $0.value("error") }
        #expect(notRead == [.error(type: "ImportFileError", code: "notTheFile")])

        world.adapter.release(received)
        let notDeleted = world.logger.entries("import.file.copyNotDeleted").map { $0.value("error") }
        #expect(notDeleted == [.error(type: "ImportFileError", code: "notTheFile")])
        #expect(world.scratch.kind(of: copy) == S_IFIFO)
        #expect(try world.scratch.names(in: world.scratch.inbox) == ["cv.pdf"])
        world.expectBalanced()
    }

    @Test("another file put at the received path is neither read nor deleted")
    func replacedFile() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox, "mine")
        let received = world.adapter.receive(copy)
        try world.scratch.replace(copy, with: "other")

        await #expect(throws: ImportFailure.fileNotRead) { try await world.adapter.readPDF(of: received) }
        let notRead = world.logger.entries("import.file.notRead").map { $0.value("error") }
        #expect(notRead == [.error(type: "ImportFileError", code: "notTheFile")])

        world.adapter.release(received)
        let notDeleted = world.logger.entries("import.file.copyNotDeleted").map { $0.value("error") }
        #expect(notDeleted == [.error(type: "ImportFileError", code: "notTheFile")])
        #expect(try String(contentsOf: copy, encoding: .utf8) == "other")
        #expect(try world.scratch.names(in: world.scratch.inbox) == ["cv.pdf"])
        world.expectBalanced()
    }

    // MARK: Overlaps

    @Test("a receive of the copy while its last release deletes it waits, and then finds no file", .timeLimit(.minutes(1)))
    func receiveDuringLastRelease() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let first = world.adapter.receive(copy)

        let overlap = try #require(Self.releaseWhileReceiving(world, first, copy))

        #expect(overlap.finishedDuringRemove == false)
        await #expect(throws: ImportFailure.fileNotRead) { try await world.adapter.readPDF(of: overlap.second) }
        #expect(world.logger.entries("import.file.notRead").map { $0.value("reason") } == [.token("noIdentity")])
        world.adapter.release(overlap.second)
        #expect(world.files.calls.removed.count == 1)
        world.expectBalanced()
    }

    @Test("a release during the read makes the read fail, and its bytes are not given")
    func releaseDuringRead() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let received = world.adapter.receive(copy)
        let adapter = world.adapter
        world.files.onRead { _ in adapter.release(received) }

        await #expect(throws: ImportFailure.fileNotRead) { try await world.adapter.readPDF(of: received) }

        #expect(world.logger.entries("import.file.notRead").map { $0.value("reason") } == [.token("releasedDuringRead")])
        #expect(world.files.calls.stops.count == 1)
        world.expectBalanced()
    }

    // MARK: Which files are deleted

    @Test("a file outside the copy folders is never deleted")
    func outsideTheCopyFoldersStays() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let mine = try world.scratch.file("cv.pdf", in: world.scratch.chosen)

        world.adapter.release(world.adapter.receive(mine))

        #expect(FileManager.default.fileExists(atPath: mine.path))
        #expect(world.files.calls.removed.isEmpty)
        world.expectBalanced()
    }

    @Test("a copy in the Documents inbox goes")
    func documentsInboxCopyGoes() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.documentsInbox)

        world.adapter.release(world.adapter.receive(copy))

        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("a file of the app's documents that is in no copy folder stays")
    func documentsFileStays() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let file = try world.scratch.file("cv.pdf", in: world.scratch.documents)

        world.adapter.release(world.adapter.receive(file))

        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(world.files.calls.removed.isEmpty)
    }

    @Test("a file in a subfolder of a copy folder stays")
    func subfolderOfInboxStays() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let folder = world.scratch.inbox.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let file = try world.scratch.file("cv.pdf", in: folder)

        world.adapter.release(world.adapter.receive(file))

        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(world.files.calls.removed.isEmpty)
    }

    @Test("a copy folder received as a file is never deleted")
    func copyFolderItselfIsNeverDeleted() throws {
        let world = try World()
        defer { world.scratch.remove() }

        world.adapter.release(world.adapter.receive(world.scratch.inbox))

        #expect(world.scratch.kind(of: world.scratch.inbox) == S_IFDIR)
        #expect(world.files.calls.removed.isEmpty)
        world.expectBalanced()
    }

    @Test("a copy that cannot be deleted is logged, and its access still stops")
    func failedDeletion() throws {
        let world = try World(faults: .init(removeFails: true))
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)

        world.adapter.release(world.adapter.receive(copy))

        #expect(world.files.calls.removed.count == 1)
        let logged = world.logger.entries("import.file.copyNotDeleted").map { $0.value("error") }
        #expect(logged == [.error(type: "ImportFileError", code: "EACCES")])
        #expect(FileManager.default.fileExists(atPath: copy.path))
        world.expectBalanced()
    }

    // MARK: Files this run did not receive

    @Test("a file in a copy folder that this run did not receive is never deleted: at launch, after an import, after a window goes away")
    func unreceivedFileIsNeverDeleted() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let scratch = world.scratch
        try scratch.file("stray.pdf", in: scratch.inbox)
        try scratch.file("stray.pdf", in: scratch.documentsInbox)

        _ = world.nextLaunch()
        let launch = world.nextLaunch()
        #expect(try scratch.names(in: scratch.inbox) == ["stray.pdf"])
        #expect(try scratch.names(in: scratch.documentsInbox) == ["stray.pdf"])

        let imported = try scratch.file("imported.pdf", in: scratch.inbox)
        let read = launch.receive(imported)
        _ = try await launch.readPDF(of: read)
        launch.release(read)
        #expect(try scratch.names(in: scratch.inbox) == ["stray.pdf"])

        let gone = launch.receive(try scratch.file("gone.pdf", in: scratch.documentsInbox))
        launch.release(gone)
        #expect(try scratch.names(in: scratch.inbox) == ["stray.pdf"])
        #expect(try scratch.names(in: scratch.documentsInbox) == ["stray.pdf"])
        world.expectBalanced()
    }

    @Test("adapters made with logging(to:) share their received files, each with its own log")
    func adaptersThatShareFiles() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let inbox = world.nextLaunch()
        let screenLog = RecordingLogger()
        let screen = inbox.logging(to: screenLog)
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)

        let waiting = inbox.receive(copy)
        let read = screen.receive(copy)
        inbox.release(waiting)

        #expect(try world.scratch.names(in: world.scratch.inbox) == ["cv.pdf"])
        _ = try await screen.readPDF(of: read)
        screen.release(read)
        #expect(try world.scratch.names(in: world.scratch.inbox) == [])
        screen.release(read)
        #expect(screenLog.events == ["import.file.releasedAgain"])
        #expect(world.logger.events.isEmpty)
        world.expectBalanced()
    }

    // MARK: Helpers

    /// Releases `first` while another thread receives `copy` from inside the delete of the copy, and gives that receive's
    /// file and whether it ended while the delete ran. Nil when the receive never ended.
    private static func releaseWhileReceiving(
        _ world: World,
        _ first: ReceivedFile,
        _ copy: URL
    ) -> (second: ReceivedFile, finishedDuringRemove: Bool)? {
        let second = Box<ReceivedFile?>(nil)
        let finishedDuringRemove = Box(false)
        let done = Signal()
        let adapter = world.adapter
        world.files.onRemove { _ in
            DispatchQueue.global().async {
                second.set(adapter.receive(copy))
                done.signal()
            }
            finishedDuringRemove.set(done.wait(seconds: 0.3))
        }
        world.adapter.release(first)
        guard finishedDuringRemove.current || done.wait(seconds: 10) else {
            Issue.record("the receive never ended")
            return nil
        }
        guard let received = second.current else { return nil }
        return (received, finishedDuringRemove.current)
    }
}

// MARK: - Test doubles

/// A value shared with a closure that runs on another thread.
private final class Box<Value: Sendable>: Sendable {
    private let value: Mutex<Value>

    init(_ value: Value) {
        self.value = Mutex(value)
    }

    var current: Value { value.withLock { $0 } }

    func set(_ newValue: Value) {
        value.withLock { $0 = newValue }
    }
}

/// One thread tells another that something happened; the other waits for it, for a while. A semaphore is safe to
/// share between threads.
private final class Signal: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)

    func signal() {
        semaphore.signal()
    }

    /// True when the signal came within `seconds`.
    func wait(seconds: Double) -> Bool {
        semaphore.wait(timeout: .now() + seconds) == .success
    }
}

/// The device's file system, with every call recorded, and faults and hooks the tests choose.
private final class SpyFiles: ImportFileSystem {
    struct Calls: Sendable {
        var starts: [URL] = []
        var stops: [URL] = []
        var reads: [URL] = []
        var removed: [URL] = []
        /// Every call, as "<call> <last path component>".
        var events: [String] = []

        /// The deletes and the stops of access, in their order.
        var order: [String] { events.filter { $0.hasPrefix("remove ") || $0.hasPrefix("stop ") } }
    }

    struct Faults: Sendable {
        var removeFails = false
        var cancelDuringRead = false
    }

    private struct Hooks: Sendable {
        var onRead: (@Sendable (URL) -> Void)?
        var onRemove: (@Sendable (URL) -> Void)?
    }

    private let system = SystemImportFiles()
    private let faults: Faults
    private let recorded = Mutex(Calls())
    private let hooks = Mutex(Hooks())
    init(_ faults: Faults = Faults()) {
        self.faults = faults
    }

    var calls: Calls { recorded.withLock { $0 } }

    /// Runs after each read, outside every lock of the spy.
    func onRead(_ hook: @escaping @Sendable (URL) -> Void) {
        hooks.withLock { $0.onRead = hook }
    }

    /// Runs at the start of each delete, before the file is touched.
    func onRemove(_ hook: @escaping @Sendable (URL) -> Void) {
        hooks.withLock { $0.onRemove = hook }
    }

    func startAccess(_ url: URL) -> Bool {
        record("start", url) { $0.starts.append(url) }
        return true
    }

    func stopAccess(_ url: URL) {
        record("stop", url) { $0.stops.append(url) }
    }

    func resolve(_ url: URL) -> URL {
        record("resolve", url)
        return system.resolve(url)
    }

    func identity(ofResolved url: URL) -> FileIdentity? {
        record("identity", url)
        return system.identity(ofResolved: url)
    }

    func read(_ url: URL, identity: FileIdentity, atMost limit: Int) throws(ImportFileError) -> FileRead {
        record("read", url) { $0.reads.append(url) }
        if faults.cancelDuringRead { withUnsafeCurrentTask { $0?.cancel() } }
        let result = try system.read(url, identity: identity, atMost: limit)
        hooks.withLock { $0.onRead }?(url)
        return result
    }

    func remove(_ url: URL, identity: FileIdentity) throws(ImportFileError) {
        record("remove", url) { $0.removed.append(url) }
        hooks.withLock { $0.onRemove }?(url)
        if faults.removeFails { throw ImportFileError.system(EACCES) }
        try system.remove(url, identity: identity)
    }

    private func record(_ call: String, _ url: URL) {
        record(call, url) { _ in }
    }

    private func record(_ call: String, _ url: URL, _ change: (inout Calls) -> Void) {
        recorded.withLock { calls in
            change(&calls)
            calls.events.append("\(call) \(url.lastPathComponent)")
        }
    }
}

/// An adapter over a spy of the device's file system, in a scratch container.
private struct World {
    let scratch: Scratch
    let files: SpyFiles
    let logger: RecordingLogger
    let maximumBytes: Int
    let adapter: ImportFileAdapter

    init(maximumBytes: Int = 1_000, faults: SpyFiles.Faults = SpyFiles.Faults()) throws {
        let scratch = try Scratch()
        let files = SpyFiles(faults)
        let logger = RecordingLogger()
        self.scratch = scratch
        self.files = files
        self.logger = logger
        self.maximumBytes = maximumBytes
        adapter = ImportFileAdapter(
            files: files, copyFolders: scratch.copyFolders, maximumBytes: maximumBytes, logger: logger
        )
    }

    /// The adapter of the app launched again, over the same folders, file system and log: it holds none of the files
    /// the earlier one received.
    func nextLaunch() -> ImportFileAdapter {
        ImportFileAdapter(
            files: files, copyFolders: scratch.copyFolders, maximumBytes: maximumBytes, logger: logger
        )
    }

    /// Every start of access has had its stop, on the same URL.
    func expectBalanced(sourceLocation: SourceLocation = #_sourceLocation) {
        let calls = files.calls
        #expect(calls.starts.count == calls.stops.count, sourceLocation: sourceLocation)
        #expect(calls.starts.map(\.path).sorted() == calls.stops.map(\.path).sorted(), sourceLocation: sourceLocation)
    }
}
