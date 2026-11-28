import Foundation
import Testing
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// Each file the screen receives is released exactly once, after the import that reads it has ended, however it ended,
/// or at once when it is not read. Which URLs name one file is the adapter's to know, not the view model's (ADR 0027).
@MainActor
@Suite("Lifetime of an imported file")
struct ImportFileLifetimeTests {

    private let file = ImportValues.file
    private let otherFile = ImportValues.otherFile

    /// Lets both reads go on: the cancelled task ends, the new import waits at the import's gate.
    private func letTheOldTaskEnd(_ world: ImportWorld) async {
        await world.files.gate.open()
        await settle()
    }

    private func finishTheNewImport(_ world: ImportWorld, _ model: ImportViewModel) async {
        await world.importer.gate.open()
        await waitUntil("the draft") { model.status == .ready }
        await model.files.settled()
    }

    /// Holds the read of `first`, cancels it, and holds the read of `second` too.
    private func cancelAndStartAgain(_ world: ImportWorld, _ model: ImportViewModel, first: URL, second: URL) async {
        await world.hold(model) { $0.importFile(at: first) }
        model.cancel()
        model.importFile(at: second)
        await waitUntil("both reads at the gate") { await world.files.gate.waiting == 2 }
    }

    @Test("every file is received before it is read, and a file read is released once, after the import, on success")
    func successReleasesOnceAfterTheImport() async {
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: file) }
        #expect(world.files.received.map(\.file.url) == [file])

        await world.files.gate.open()
        await settle()
        #expect(world.files.released(file) == 0)                // the import still runs

        await finishTheNewImport(world, model)
        #expect(world.files.released(file) == 1)
        #expect(world.files.problems(ended: true).isEmpty)
    }

    @Test("a file whose read fails is released once")
    func failureReleasesOnce() async {
        let world = ImportWorld(file: .failure(ImportFailure.fileNotRead))
        let model = world.model()

        model.importFile(at: file)
        await waitUntil("the problem") { model.status == .failed(ImportProblem(.fileNotRead)) }
        await model.files.settled()

        #expect(world.files.released(file) == 1)
        #expect(world.files.problems(ended: true).isEmpty)
    }

    @Test("a file cancelled during its read is released once, when its task ends, not before")
    func cancelDuringTheReadReleasesWhenTheTaskEnds() async {
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: file) }

        model.cancel()
        #expect(world.files.released(file) == 0)                // its read still runs

        await letTheOldTaskEnd(world)
        #expect(world.files.released(file) == 1)
        #expect(world.files.problems(ended: true).isEmpty)
    }

    @Test("a file cancelled during its import is released once, when its task ends")
    func cancelDuringTheImportReleasesWhenTheTaskEnds() async {
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: file) }
        await world.files.gate.open()
        await waitUntil("the import") { world.importer.calls == 1 }

        model.cancel()
        #expect(world.files.released(file) == 0)                // the import still runs

        await world.importer.gate.open()
        await settle()
        #expect(world.files.released(file) == 1)
        #expect(world.files.problems(ended: true).isEmpty)
    }

    @Test("a file imported again after a cancel is released once by the cancelled task and once by the new import")
    func sameFileAgainAfterCancel() async {
        let world = ImportWorld()
        let model = world.model()
        await cancelAndStartAgain(world, model, first: file, second: file)
        #expect(world.files.received.count == 2)

        await letTheOldTaskEnd(world)
        #expect(world.files.received.first?.releases == 1)      // the cancelled task's own received file
        #expect(world.files.received.last?.releases == 0)
        #expect(model.status == .importing)

        await finishTheNewImport(world, model)
        #expect(world.files.received.map(\.releases) == [1, 1])
        #expect(world.files.problems(ended: true).isEmpty)
    }

    @Test("a file handed over while an import runs is released at once, unread, and the import is not touched")
    func refusedFileIsReleasedAtOnce() async {
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: file) }

        model.importFile(at: otherFile)
        await model.files.settled()

        #expect(world.files.released(otherFile) == 1)
        #expect(world.files.released(file) == 0)
        #expect(world.files.received.last?.reads == 0)
        #expect(model.status == .importing)

        await world.files.gate.open()
        await finishTheNewImport(world, model)
        #expect(world.files.released(otherFile) == 1)
        #expect(world.files.released(file) == 1)
        #expect(world.files.problems(ended: true).isEmpty)
    }

    @Test("the same file handed over again while an import runs is released at once, as its own received file")
    func sameFileRefusedIsReleasedAtOnce() async {
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: file) }

        model.importFile(at: file)
        await model.files.settled()
        #expect(world.files.received.map(\.releases) == [0, 1])

        await world.files.gate.open()
        await finishTheNewImport(world, model)
        #expect(world.files.received.map(\.releases) == [1, 1])
        #expect(world.files.problems(ended: true).isEmpty)
    }

    @Test("a cancelled file handed over again while another import runs is released at once, its old task later")
    func cancelledFileHandedOverAgainWhileAnotherRuns() async {
        let world = ImportWorld()
        let model = world.model()
        await cancelAndStartAgain(world, model, first: file, second: otherFile)

        model.importFile(at: file)
        await model.files.settled()
        #expect(world.files.released(file) == 1)                // the third, refused

        await letTheOldTaskEnd(world)
        await waitUntil("the cancelled task let its file go") { world.files.released(file) == 2 }
        await model.files.settled()
        #expect(world.files.released(file) == 2)                // plus the cancelled task's own
        #expect(world.files.released(otherFile) == 0)

        await finishTheNewImport(world, model)
        #expect(world.files.released(otherFile) == 1)
        #expect(world.files.problems(ended: true).isEmpty)
    }

    @Test("a file is released once when the view model is gone before its import ends")
    func oneImportModelGone() async {
        let world = ImportWorld()
        var model: ImportViewModel? = world.model()
        await world.hold(model!) { $0.importFile(at: file) }
        let holder = model!.files

        model = nil
        #expect(world.files.released(file) == 0)
        await world.files.gate.open()
        await world.importer.gate.open()
        await waitUntil("the file let go") { world.files.released(file) > 0 }
        await holder.settled()

        #expect(world.files.released(file) == 1)
        #expect(world.files.problems(ended: true).isEmpty)
    }

    @Test("two imports of files, the view model gone before both end, release each file once")
    func twoImportsModelGone() async {
        let world = ImportWorld()
        var model: ImportViewModel? = world.model()
        await world.hold(model!) { $0.importFile(at: file) }
        model?.cancel()
        model?.importFile(at: file)
        await waitUntil("both reads at the gate") { await world.files.gate.waiting == 2 }
        let holder = model!.files

        model = nil
        await world.files.gate.open()
        await world.importer.gate.open()
        await waitUntil("both files let go") { world.files.received.allSatisfy { $0.releases > 0 } }
        await holder.settled()

        #expect(world.files.received.map(\.releases) == [1, 1])
        #expect(world.files.problems(ended: true).isEmpty)
    }
}
