import DiagnosticLogging
import DiagnosticLoggingTestSupport
import Foundation
import PrestoCVImporting
import PrestoCVIntegration
import PrestoCVWorkflowPorts
import Synchronization
import Testing

/// The Foundation file system, with no security scope, and a file's identity as its resolved path.
private struct FoundationImportFiles: ImportFileSystem {
    func resolve(_ url: URL) -> URL { url.resolvingSymlinksInPath().standardizedFileURL }
    func identity(ofResolved url: URL) -> String { url.path }
    func startAccess(_ url: URL) -> Bool { false }
    func stopAccess(_ url: URL) {}
    func size(of url: URL) throws -> Int {
        guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { throw CocoaError(.fileReadUnknown) }
        return size
    }
    func read(_ url: URL) throws -> Data { try Data(contentsOf: url) }
    func remove(_ url: URL) throws { try FileManager.default.removeItem(at: url) }
}

/// A folder of its own for one test, with an app container inside it and a folder of the person's files beside it.
private struct Scratch {
    let root: URL
    var container: URL { root.appendingPathComponent("Container", isDirectory: true) }
    var inbox: URL { container.appendingPathComponent("tmp/Inbox", isDirectory: true) }
    var chosen: URL { root.appendingPathComponent("Files", isDirectory: true) }

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        for folder in [inbox, chosen] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    }

    func file(_ name: String, in folder: URL, _ text: String = "%PDF") throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    func link(_ name: String, to target: URL) throws -> URL {
        let url = chosen.appendingPathComponent(name)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
        return url
    }

    func retarget(_ link: URL, to target: URL) throws {
        try FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    }

    func remove() {
        do {
            try FileManager.default.removeItem(at: root)
        } catch {
            Issue.record(error, "The scratch folder stays: \(root.path)")
        }
    }
}

/// The real file system underneath, with the starts, stops, reads and removals recorded, and a fault to script.
private final class SpyFiles: ImportFileSystem {
    struct Calls {
        var starts: [URL] = []
        var stops: [URL] = []
        var reads: [URL] = []
        var removed: [URL] = []
        /// The stops and the removals in the order they came, as "stop a.pdf" and "remove a.pdf".
        var order: [String] = []
    }

    struct Faults {
        var sizeReported: Int?
        var bytesRead: Data?
        var removeFails = false
        var cancelDuringRead = false
        /// Every file has one identity, as two names of one file (a hard link) have on a device.
        var oneIdentity = false
    }

    struct RemoveRefused: Error {}

    private let real = FoundationImportFiles()
    private let calls = Mutex(Calls())
    private let faults: Faults

    init(_ faults: Faults) { self.faults = faults }

    var starts: [URL] { calls.withLock { $0.starts } }
    var stops: [URL] { calls.withLock { $0.stops } }
    var reads: [URL] { calls.withLock { $0.reads } }
    var removed: [URL] { calls.withLock { $0.removed } }
    var order: [String] { calls.withLock { $0.order } }

    func resolve(_ url: URL) -> URL { real.resolve(url) }
    func identity(ofResolved url: URL) -> String { faults.oneIdentity ? "one" : real.identity(ofResolved: url) }

    func startAccess(_ url: URL) -> Bool {
        calls.withLock { $0.starts.append(url) }
        return true
    }

    func stopAccess(_ url: URL) {
        calls.withLock {
            $0.stops.append(url)
            $0.order.append("stop \(url.lastPathComponent)")
        }
    }

    func size(of url: URL) throws -> Int { try faults.sizeReported ?? real.size(of: url) }

    func read(_ url: URL) throws -> Data {
        calls.withLock { $0.reads.append(url) }
        if faults.cancelDuringRead { withUnsafeCurrentTask { $0?.cancel() } }
        return try faults.bytesRead ?? real.read(url)
    }

    func remove(_ url: URL) throws {
        calls.withLock {
            $0.removed.append(url)
            $0.order.append("remove \(url.lastPathComponent)")
        }
        if faults.removeFails { throw RemoveRefused() }
        try real.remove(url)
    }
}

private struct World {
    let scratch: Scratch
    let files: SpyFiles
    let logger = RecordingLogger()
    let adapter: ImportFileAdapter

    init(maximumBytes: Int = 1_000, _ faults: SpyFiles.Faults = .init()) throws {
        scratch = try Scratch()
        files = SpyFiles(faults)
        adapter = ImportFileAdapter(files: files, container: scratch.container, maximumBytes: maximumBytes, logger: logger)
    }

    /// Every start has its stop.
    func expectBalanced(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(files.starts.count == files.stops.count, sourceLocation: sourceLocation)
        #expect(files.starts.map(\.path).sorted() == files.stops.map(\.path).sorted(), sourceLocation: sourceLocation)
    }
}

@Suite("The file adapter of the import screen")
struct ImportFileAdapterTests {

    // MARK: Identity and counting

    @Test("three spellings of one file: each receive starts its own access and its release stops it; the copy goes at the last release, before its stop")
    func eachReceiveHasItsOwnAccess() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let link = try world.scratch.link("link.pdf", to: copy)
        let spelled = world.scratch.inbox.appendingPathComponent("../Inbox/./cv.pdf")

        let received = [link, spelled, copy].map(world.adapter.receive)
        #expect(world.files.starts == [link, spelled, copy])

        world.adapter.release(received[0])
        #expect(world.files.stops == [link])
        world.adapter.release(received[1])
        #expect(world.files.stops == [link, spelled])
        #expect(world.files.removed.isEmpty)
        #expect(FileManager.default.fileExists(atPath: copy.path))

        world.adapter.release(received[2])
        #expect(world.files.order.suffix(2) == ["remove cv.pdf", "stop cv.pdf"])
        #expect(world.files.removed.count == 1)
        #expect(!FileManager.default.fileExists(atPath: copy.path))
        world.expectBalanced()
    }

    @Test("received files get distinct ids, in order")
    func idsAreDistinct() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let file = try world.scratch.file("a.pdf", in: world.scratch.chosen)
        let ids = (0..<3).map { _ in world.adapter.receive(file).id }
        #expect(Set(ids).count == 3)
    }

    @Test("the chain A, B, C where A and C are one copy: B's copy goes at once, A's release leaves the copy to C")
    func chainOfThree() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let one = try world.scratch.file("one.pdf", in: world.scratch.inbox)
        let two = try world.scratch.file("two.pdf", in: world.scratch.inbox)
        let a = world.adapter.receive(one)
        let b = world.adapter.receive(two)
        let c = world.adapter.receive(try world.scratch.link("again.pdf", to: one))
        #expect(world.files.starts.count == 3)

        world.adapter.release(b)
        #expect(world.files.order == ["remove two.pdf", "stop two.pdf"])
        world.adapter.release(a)
        #expect(world.files.order.last == "stop one.pdf")
        #expect(FileManager.default.fileExists(atPath: one.path))
        world.adapter.release(c)
        #expect(world.files.order.suffix(2) == ["remove one.pdf", "stop again.pdf"])
        #expect(!FileManager.default.fileExists(atPath: one.path))
        world.expectBalanced()
    }

    @Test("a received file released twice stops once and logs the second release")
    func releasedTwice() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let file = world.adapter.receive(try world.scratch.file("a.pdf", in: world.scratch.chosen))

        world.adapter.release(file)
        world.adapter.release(file)

        #expect(world.files.stops.count == 1)
        #expect(world.logger.entries("import.file.releasedAgain").count == 1)
        world.expectBalanced()
    }

    @Test("a second release of one received file does not let go the copy another received file still holds")
    func secondReleaseDoesNotTakeAnothersTurn() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let url = try world.scratch.file("a.pdf", in: world.scratch.inbox)
        let first = world.adapter.receive(url)
        let second = world.adapter.receive(url)

        world.adapter.release(first)
        world.adapter.release(first)
        #expect(world.files.stops.count == 1)
        #expect(world.files.removed.isEmpty)
        #expect(world.logger.entries("import.file.releasedAgain").count == 1)

        world.adapter.release(second)
        #expect(world.files.stops.count == 2)
        #expect(world.files.removed.count == 1)
        world.expectBalanced()
    }

    @Test("two names of one file in the container are both deleted at the last release, and only then")
    func everyNameOfTheCopy() throws {
        let world = try World(.init(oneIdentity: true))
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)
        let other = world.scratch.inbox.appendingPathComponent("cv-1.pdf")
        try FileManager.default.linkItem(at: copy, to: other)
        let first = world.adapter.receive(copy)
        let second = world.adapter.receive(other)

        world.adapter.release(first)
        #expect(world.files.removed.isEmpty)
        world.adapter.release(second)
        #expect(Set(world.files.removed.map(\.lastPathComponent)) == ["cv.pdf", "cv-1.pdf"])
        #expect(world.files.order.last == "stop cv-1.pdf")
        world.expectBalanced()
    }

    // MARK: Reading

    @Test("a link retargeted after receive does not change the bytes read")
    func retargetedLink() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let first = try world.scratch.file("first.pdf", in: world.scratch.chosen, "first")
        let second = try world.scratch.file("second.pdf", in: world.scratch.chosen, "second")
        let link = try world.scratch.link("link.pdf", to: first)
        let received = world.adapter.receive(link)

        try world.scratch.retarget(link, to: second)

        #expect(try await world.adapter.readPDF(of: received) == Data("first".utf8))
        world.adapter.release(received)
        world.expectBalanced()
    }

    @Test("a file above the bound is too large, and is not read")
    func aboveTheBound() async throws {
        let world = try World(maximumBytes: 10)
        defer { world.scratch.remove() }
        let received = world.adapter.receive(try world.scratch.file("big.pdf", in: world.scratch.chosen, "12345678901"))

        await #expect(throws: ImportFailure.tooLarge) { try await world.adapter.readPDF(of: received) }
        #expect(world.files.reads.isEmpty)
        world.adapter.release(received)
        world.expectBalanced()
    }

    @Test("a file at the bound is read")
    func atTheBound() async throws {
        let world = try World(maximumBytes: 10)
        defer { world.scratch.remove() }
        let received = world.adapter.receive(try world.scratch.file("ok.pdf", in: world.scratch.chosen, "1234567890"))

        #expect(try await world.adapter.readPDF(of: received).count == 10)
        world.adapter.release(received)
    }

    @Test("a file that grew past the bound during the read is too large")
    func grewDuringTheRead() async throws {
        let world = try World(maximumBytes: 10, .init(sizeReported: 5, bytesRead: Data(count: 11)))
        defer { world.scratch.remove() }
        let received = world.adapter.receive(try world.scratch.file("grow.pdf", in: world.scratch.chosen, "12345"))

        await #expect(throws: ImportFailure.tooLarge) { try await world.adapter.readPDF(of: received) }
        #expect(world.files.reads.count == 1)
        world.adapter.release(received)
        world.expectBalanced()
    }

    @Test("a file that cannot be read is fileNotRead, and the error is logged")
    func unreadable() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let missing = world.scratch.chosen.appendingPathComponent("gone.pdf")
        let received = world.adapter.receive(missing)

        await #expect(throws: ImportFailure.fileNotRead) { try await world.adapter.readPDF(of: received) }
        #expect(world.logger.entries("import.file.notRead").count == 1)
        world.adapter.release(received)
        world.expectBalanced()
    }

    @Test("a file that was released cannot be read")
    func readAfterRelease() async throws {
        let world = try World()
        defer { world.scratch.remove() }
        let received = world.adapter.receive(try world.scratch.file("a.pdf", in: world.scratch.chosen))
        world.adapter.release(received)

        await #expect(throws: ImportFailure.fileNotRead) { try await world.adapter.readPDF(of: received) }
    }

    @Test("a cancelled read stays a CancellationError, and the caller still releases the file once")
    func cancelledRead() async throws {
        let world = try World(.init(cancelDuringRead: true))
        defer { world.scratch.remove() }
        let received = world.adapter.receive(try world.scratch.file("a.pdf", in: world.scratch.chosen))

        let outcome = await Task { () -> Result<Data, any Error> in
            do { return .success(try await world.adapter.readPDF(of: received)) } catch { return .failure(error) }
        }.value
        guard case .failure(let error) = outcome else {
            Issue.record("the read of a cancelled task succeeded")
            return
        }
        #expect(error is CancellationError)
        #expect(world.logger.entries("import.file.notRead").isEmpty)
        #expect(world.files.stops.isEmpty)

        world.adapter.release(received)
        #expect(world.files.stops.count == 1)
        world.expectBalanced()
    }

    // MARK: The copy of "Open in"

    @Test("a file outside the container is the person's and stays")
    func outsideTheContainerStays() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let chosen = try world.scratch.file("mine.pdf", in: world.scratch.chosen)

        world.adapter.release(world.adapter.receive(chosen))

        #expect(world.files.removed.isEmpty)
        #expect(FileManager.default.fileExists(atPath: chosen.path))
        world.expectBalanced()
    }

    @Test("a file in a Documents/Inbox of the container is deleted too, wherever the system put it")
    func anyFolderOfTheContainer() throws {
        let world = try World()
        defer { world.scratch.remove() }
        let documents = world.scratch.container.appendingPathComponent("Documents/Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let copy = try world.scratch.file("cv.pdf", in: documents)

        world.adapter.release(world.adapter.receive(copy))

        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test("the container itself is never deleted")
    func containerIsNotAFile() throws {
        let world = try World()
        defer { world.scratch.remove() }

        world.adapter.release(world.adapter.receive(world.scratch.container))

        #expect(world.files.removed.isEmpty)
    }

    @Test("a deletion that fails is logged, and the file is still let go")
    func failedDeletion() throws {
        let world = try World(.init(removeFails: true))
        defer { world.scratch.remove() }
        let copy = try world.scratch.file("cv.pdf", in: world.scratch.inbox)

        world.adapter.release(world.adapter.receive(copy))

        #expect(world.files.removed.count == 1)
        #expect(world.logger.entries("import.file.copyNotDeleted").count == 1)
        world.expectBalanced()
    }
}
