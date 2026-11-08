import Foundation
import Testing
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// A file is let go exactly once, when no import of it holds it any more, however often it is handed over (ADR 0027).
@MainActor
@Suite("Lifetime of an imported file")
struct ImportFileLifetimeTests {

    private let file = ImportValues.file
    private let otherFile = ImportValues.otherFile

    /// Holds the read of `first`, cancels it, and holds the read of `second` too.
    private func cancelAndStartAgain(_ world: ImportWorld, _ model: ImportViewModel, first: URL, second: URL) async {
        await world.hold(model) { $0.importFile(at: first) }
        model.cancel()
        model.importFile(at: second)
        await waitUntil("both reads at the gate") { await world.files.gate.waiting == 2 }
    }

    /// Lets both reads go on: the cancelled task ends, the new import waits at the import's gate.
    private func letTheOldTaskEnd(_ world: ImportWorld) async {
        await world.files.gate.open()
        await settle()
    }

    private func finishTheNewImport(_ world: ImportWorld, _ model: ImportViewModel) async {
        await world.importer.gate.open()
        await waitUntil("the draft") { model.status == .ready }
        await settle()
    }

    @Test("a file imported again after a cancel is not let go by the cancelled task, but once after the new import")
    func sameFileAgainAfterCancel() async {
        let world = ImportWorld()
        let model = world.model()
        await cancelAndStartAgain(world, model, first: file, second: file)

        await letTheOldTaskEnd(world)
        #expect(world.files.released(file) == 0)
        #expect(model.status == .importing)

        await finishTheNewImport(world, model)
        #expect(world.files.recorded == [.read(file), .read(file), .released(file)])
    }

    @Test("the same holds when the file is handed over again under another spelling")
    func sameFileAgainUnderAnotherSpelling() async {
        let world = ImportWorld()
        let model = world.model()
        await cancelAndStartAgain(world, model, first: file, second: URL(fileURLWithPath: "/invented/x/../cvs/cv.pdf"))

        await letTheOldTaskEnd(world)
        #expect(world.files.released(file) == 0)

        await finishTheNewImport(world, model)
        #expect(world.files.recorded.filter { if case .released = $0 { true } else { false } }.count == 1)
    }

    @Test("a cancelled file handed over again while another import runs is let go once, when its old task ends")
    func cancelledFileHandedOverAgainWhileAnotherRuns() async {
        let world = ImportWorld()
        let model = world.model()
        await cancelAndStartAgain(world, model, first: file, second: otherFile)

        model.importFile(at: file)
        #expect(world.files.released(file) == 0)

        await letTheOldTaskEnd(world)
        #expect(world.files.released(file) == 1)
        #expect(world.files.released(otherFile) == 0)

        await finishTheNewImport(world, model)
        #expect(world.files.released(file) == 1)
        #expect(world.files.released(otherFile) == 1)
    }

    @Test("a file handed over while another import runs, and held by none, is let go at once")
    func refusedFileNobodyHoldsIsReleasedAtOnce() async {
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: file) }

        model.importFile(at: otherFile)

        #expect(world.files.released(otherFile) == 1)
        #expect(world.files.released(file) == 0)
    }

    @Test("a file held by two imports is let go once when the view model is gone before both end")
    func twoHoldersModelGone() async {
        let world = ImportWorld()
        var model: ImportViewModel? = world.model()
        await world.hold(model!) { $0.importFile(at: file) }
        model?.cancel()
        model?.importFile(at: file)
        await waitUntil("both reads at the gate") { await world.files.gate.waiting == 2 }

        model = nil
        await world.files.gate.open()
        await world.importer.gate.open()
        await settle()

        #expect(world.files.released(file) == 1)
    }

    @Test("a file held by one import is let go once when the view model is gone before it ends")
    func oneHolderModelGone() async {
        let world = ImportWorld()
        var model: ImportViewModel? = world.model()
        await world.hold(model!) { $0.importFile(at: file) }

        model = nil
        await world.files.gate.open()
        await world.importer.gate.open()
        await settle()

        #expect(world.files.released(file) == 1)
    }

    // MARK: - A link that moves while an import holds it

    /// A real folder with two files and a link `link` that points at the first, removed with the value.
    private final class Links {
        let folder: URL
        let first: URL
        let second: URL
        let link: URL

        init() throws {
            let manager = FileManager.default
            folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("links-\(UUID().uuidString)")
            try manager.createDirectory(at: folder, withIntermediateDirectories: true)
            first = folder.appendingPathComponent("first.pdf")
            second = folder.appendingPathComponent("second.pdf")
            link = folder.appendingPathComponent("link.pdf")
            try Data("1".utf8).write(to: first)
            try Data("2".utf8).write(to: second)
            try manager.createSymbolicLink(at: link, withDestinationURL: first)
        }

        deinit { try? FileManager.default.removeItem(at: folder) }

        /// The link points at the second file from now on.
        func retarget() throws {
            let manager = FileManager.default
            try manager.removeItem(at: link)
            try manager.createSymbolicLink(at: link, withDestinationURL: second)
        }
    }

    @Test("a link retargeted while its import runs does not let that task release the file the link now names")
    func retargetedLinkDoesNotReleaseAnotherTasksFile() async throws {
        let links = try Links()
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: links.link) }
        model.cancel()
        try links.retarget()
        model.importFile(at: links.second)
        await waitUntil("both reads at the gate") { await world.files.gate.waiting == 2 }

        await letTheOldTaskEnd(world)
        #expect(world.files.released(links.second) == 0)
        model.importFile(at: links.second)                      // refused: the import of it still runs
        #expect(world.files.released(links.second) == 0)

        await finishTheNewImport(world, model)
        #expect(world.files.released(links.second) == 1)
        #expect(world.files.released(links.link) == 1)
        #expect(world.files.recorded.filter { if case .released = $0 { true } else { false } }.count == 2)
    }

    @Test("a file refused under a link that was retargeted is not released while the link's import runs")
    func refusedRetargetedLinkIsKept() async throws {
        let links = try Links()
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: links.link) }
        try links.retarget()

        model.importFile(at: links.link)
        #expect(world.files.released(links.link) == 0)

        await world.files.gate.open()
        await world.importer.gate.open()
        await waitUntil("the draft") { model.status == .ready }
        await settle()
        #expect(world.files.released(links.link) == 1)
    }

    @Test("two imports of one link, retargeted between them, release it once, when the last one ends")
    func sameLinkRetargetedBetweenTwoImports() async throws {
        let links = try Links()
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: links.link) }
        model.cancel()
        try links.retarget()
        model.importFile(at: links.link)
        await waitUntil("both reads at the gate") { await world.files.gate.waiting == 2 }

        await letTheOldTaskEnd(world)
        #expect(world.files.released(links.link) == 0)

        await finishTheNewImport(world, model)
        #expect(world.files.released(links.link) == 1)
    }
}
