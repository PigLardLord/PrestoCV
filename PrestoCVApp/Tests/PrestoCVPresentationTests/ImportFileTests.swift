import Foundation
import Testing
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The import of a PDF, from a file or the clipboard: it goes to the import as a PDF, and every file handed to the
/// screen is let go exactly once, however its import ends (ADR 0027).
@MainActor
@Suite("Import of a PDF")
struct ImportFileTests {

    private let file = ImportValues.file
    private let otherFile = ImportValues.otherFile

    @Test("a file is read, goes to the PDF method and never to the text one, and its source is file")
    func fileGoesToThePDFMethodAndSourceIsFile() async {
        let world = ImportWorld()
        let model = world.model()

        model.importFile(at: file)
        await waitUntil("the draft") { model.status == .ready }

        #expect(world.importer.pdfs.withLock { $0 } == [ImportValues.pdf])
        #expect(world.importer.texts.withLock { $0 }.isEmpty)
        #expect(model.source == .file)
        #expect(model.result?.review.source == .file)
        #expect(world.files.recorded == [.read(file), .released(file)])
    }

    @Test("a pasted PDF goes to the PDF method without the file port, and its source is file")
    func pastedPDFSkipsTheFilePort() async {
        let world = ImportWorld()
        let model = world.model()

        model.importPDF(ImportValues.pdf)
        await waitUntil("the draft") { model.status == .ready }

        #expect(world.importer.pdfs.withLock { $0 } == [ImportValues.pdf])
        #expect(world.importer.texts.withLock { $0 }.isEmpty)
        #expect(world.files.recorded.isEmpty)
        #expect(model.source == .file && model.result?.review.source == .file)
    }

    @Test("a file that could not be read, or is too large to read, is its own problem and reaches no import",
          arguments: [ImportFailure.fileNotRead, .tooLarge])
    func fileNotReadIsItsOwnProblem(_ failure: ImportFailure) async {
        let world = ImportWorld(file: .failure(failure))
        let model = world.model()

        model.importFile(at: file)
        await waitUntil("the problem") { model.status == .failed(ImportProblem(failure)) }

        #expect(world.importer.calls == 0)
        #expect(model.result == nil)
        #expect(world.files.released(file) == 1)
    }

    @Test("an error of the file port that is no import failure is fileNotRead, not unreadable")
    func anyOtherFileErrorIsFileNotRead() async {
        let world = ImportWorld(file: .failure(Unexpected()))
        let model = world.model()

        model.importFile(at: file)
        await waitUntil("the problem") { model.status != .importing }

        #expect(model.status == .failed(.fileNotRead))
        #expect(world.importer.calls == 0)
    }

    @Test("a file read but refused by the import keeps the import's own problem")
    func importerFailureOnAFileIsKept() async {
        let world = ImportWorld(answers: [.failure(ImportFailure.encrypted)])
        let model = world.model()

        model.importFile(at: file)
        await waitUntil("the problem") { model.status != .importing }

        #expect(model.status == .failed(.encrypted))
        #expect(world.importer.pdfs.withLock { $0 } == [ImportValues.pdf])
        #expect(world.files.released(file) == 1)
    }

    @Test("a file is let go once, whether its import gives a draft, fails at the read or the import, or is cancelled")
    func fileIsReleasedOnceOnSuccessFailureAndCancel() async {
        let ends: [(ImportWorld, ImportStatus)] = [
            (ImportWorld(), .ready),
            (ImportWorld(file: .failure(ImportFailure.fileNotRead)), .failed(.fileNotRead)),
            (ImportWorld(answers: [.failure(ImportFailure.noText)]), .failed(.noText)),
        ]
        for (world, end) in ends {
            let model = world.model()
            model.importFile(at: file)
            await waitUntil("the end \(end)") { model.status == end }
            await settle()
            #expect(world.files.released(file) == 1, "end \(end)")
        }

        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: file) }
        #expect(world.files.released(file) == 0)
        model.cancel()
        #expect(world.files.released(file) == 0)
        await world.files.gate.open()
        await waitUntil("the release") { world.files.released(file) == 1 }
        await settle()
        #expect(world.files.recorded == [.read(file), .released(file)])
    }

    @Test("a second file handed over while an import runs is let go unread, and the import running goes on")
    func aSecondFileWhileRunningIsNotReadAndIsReleased() async {
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: file) }

        model.importFile(at: otherFile)

        #expect(world.files.recorded == [.read(file), .released(otherFile)])
        #expect(model.status == .importing)
        await world.files.gate.open()
        await world.importer.gate.open()
        await waitUntil("the draft") { model.status == .ready }
        await settle()
        #expect(world.files.recorded == [.read(file), .released(otherFile), .released(file)])

        let typed = ImportWorld()
        let typing = typed.model()
        typing.text = "Ada Ferro"
        await typed.hold(typing) { $0.importText() }
        typing.importFile(at: file)
        #expect(typed.files.recorded == [.released(file)])
    }

    @Test("the file being read, handed over again, is released at once as its own received file; the first, after its import")
    func theSecondRequestOfTheFileBeingReadIsReleasedAtOnce() async {
        let world = ImportWorld()
        let model = world.model()
        await world.hold(model) { $0.importFile(at: file) }

        model.importFile(at: file)
        model.importFile(at: file)

        #expect(world.files.recorded == [.read(file), .released(file), .released(file)])
        await world.files.gate.open()
        await world.importer.gate.open()
        await waitUntil("the draft") { model.status == .ready }
        await settle()
        #expect(world.files.recorded == [.read(file), .released(file), .released(file), .released(file)])
        #expect(world.files.problems(ended: true).isEmpty)
    }

    @Test("a read cancelled, from the screen or by the port, is no problem and reaches no import")
    func cancelledFileReadIsNoProblem() async {
        let world = ImportWorld(file: .failure(CancellationError()))
        let model = world.model()
        model.importFile(at: file)
        await waitUntil("the release") { world.files.released(file) == 1 }
        await settle()
        #expect(model.status == .idle && model.source == nil)
        #expect(world.importer.calls == 0)

        let held = ImportWorld()
        let other = held.model()
        await held.hold(other) { $0.importFile(at: file) }
        other.cancel()
        await held.files.gate.open()
        await waitUntil("the release") { held.files.released(file) == 1 }
        await settle()
        #expect(other.status == .idle && other.result == nil)
        #expect(held.importer.calls == 0)
    }

    @Test("the result of a file import that arrives after a cancel is dropped, and its file let go once")
    func lateFileResultAfterCancelIsDropped() async {
        let world = ImportWorld()
        let model = world.model()
        await world.importer.gate.close()
        model.importFile(at: file)
        await waitUntil("the import at its gate") { await world.importer.gate.waiting == 1 }
        model.cancel()

        await world.importer.gate.open()
        await waitUntil("the release") { world.files.released(file) == 1 }
        await settle()

        #expect(world.importer.calls == 1)
        #expect(model.status == .idle)
        #expect(model.result == nil && model.source == nil)
        #expect(world.files.released(file) == 1)
    }

    // MARK: Calls back into the screen

    @Test("a release that cancels the import running drops its late result, and each file is let go once")
    func aReleaseThatCancelsDropsTheLateResult() async {
        let world = ImportWorld()
        let model = world.model()
        let box = ModelBox()
        box.model = model
        world.files.whenReleased.withLock { $0 = { _ in box.model?.cancel() } }
        await world.hold(model) { $0.importFile(at: file) }

        model.importFile(at: otherFile)
        #expect(model.status == .idle)

        await world.files.gate.open()
        await world.importer.gate.open()
        await waitUntil("the release") { world.files.released(file) == 1 }
        await settle()
        #expect(model.status == .idle && model.result == nil)
        #expect(world.importer.calls == 0)
        #expect(world.files.recorded == [.read(file), .released(otherFile), .released(file)])
    }

    @Test("the draft is published before its file is let go, so a cancel from the release finds nothing running")
    func theDraftIsPublishedBeforeItsFileIsReleased() async {
        let world = ImportWorld()
        let model = world.model()
        let box = ModelBox()
        box.model = model
        world.files.whenReleased.withLock {
            $0 = { _ in
                guard let model = box.model else { return }
                box.seen.append(model.status)
                model.cancel()
            }
        }

        model.importFile(at: file)
        await waitUntil("the release") { world.files.released(file) == 1 }
        await settle()

        #expect(box.seen == [.ready])
        #expect(model.status == .ready && model.result != nil)
    }

    @Test("files handed over from inside the read are not read, and each is released at once")
    func filesHandedOverFromInsideTheReadAreNotRead() async {
        let world = ImportWorld()
        let model = world.model()
        let box = ModelBox()
        box.model = model
        let other = otherFile
        let files = world.files
        world.files.whenRead.withLock {
            $0 = { _ in
                files.whenRead.withLock { $0 = nil }
                box.model?.importFile(at: ImportValues.file)
                box.model?.importFile(at: other)
            }
        }

        model.importFile(at: file)
        await waitUntil("the draft") { model.status == .ready }
        await settle()

        #expect(world.files.recorded == [.read(file), .released(file), .released(otherFile), .released(file)])
        #expect(world.importer.calls == 1)
        #expect(world.files.problems(ended: true).isEmpty)
    }
}
