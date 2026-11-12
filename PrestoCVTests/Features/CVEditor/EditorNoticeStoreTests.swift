import Testing
import Foundation
import DiagnosticLogging
@testable import PrestoCV

@Suite("FileEditorNoticeStore - the notice of an imported CV, kept beside the CVs")
struct EditorNoticeStoreTests {

    private let review = ImportReview(
        items: [ImportReview.Item(field: .title, reason: .byPosition, text: "Mobile Developer")],
        passages: [
            ImportReview.Passage(place: .top, text: "EU citizen", isWholeSection: false),
            ImportReview.Passage(place: .section("OWN VENTURES"), text: "Tidepool Notes | 2021 – today", isWholeSection: true),
        ]
    )

    private func makeTemporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("import-notices.json")
    }

    private func removeDirectory(of url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test("A CV whose notice was never kept has none, and no file is made for it")
    func noFileHoldsNoNotice() async {
        let file = makeTemporaryFileURL()
        defer { removeDirectory(of: file) }
        let store = FileEditorNoticeStore(fileURL: file)

        #expect(await store.notice(ofCVWithId: UUID()) == nil)
        await store.forget(cvWithId: UUID())
        #expect(!FileManager.default.fileExists(atPath: file.path), "Forgetting a notice that is not kept writes nothing")
    }

    @Test("A kept notice is read back whole, by the CV's id, after the app starts again")
    func keptNoticeIsReadBack() async {
        let file = makeTemporaryFileURL()
        defer { removeDirectory(of: file) }
        let id = UUID()
        let other = UUID()

        await FileEditorNoticeStore(fileURL: file).keep(.imported(review), forCVWithId: id)
        let store = FileEditorNoticeStore(fileURL: file)

        #expect(await store.notice(ofCVWithId: id) == .imported(review))
        #expect(await store.notice(ofCVWithId: other) == nil, "Each CV has its own notice")
    }

    @Test("A forgotten notice is gone, and the other CVs keep theirs")
    func forgottenNoticeIsGone() async {
        let file = makeTemporaryFileURL()
        defer { removeDirectory(of: file) }
        let store = FileEditorNoticeStore(fileURL: file)
        let dismissed = UUID()
        let kept = UUID()
        await store.keep(.imported(review), forCVWithId: dismissed)
        await store.keep(.importedDescription(review), forCVWithId: kept)

        await store.forget(cvWithId: dismissed)

        let reopened = FileEditorNoticeStore(fileURL: file)
        #expect(await reopened.notice(ofCVWithId: dismissed) == nil)
        #expect(await reopened.notice(ofCVWithId: kept) == .importedDescription(review))
    }

    @Test("A damaged file holds no notice, and the next notice kept replaces it")
    func damagedFileIsReplaced() async throws {
        let file = makeTemporaryFileURL()
        defer { removeDirectory(of: file) }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: file)
        let store = FileEditorNoticeStore(fileURL: file)
        let id = UUID()

        #expect(await store.notice(ofCVWithId: id) == nil)
        await store.keep(.imported(review), forCVWithId: id)

        #expect(await FileEditorNoticeStore(fileURL: file).notice(ofCVWithId: id) == .imported(review))
    }

    @Test("The notices are kept in the app's own folder, beside the CVs")
    func noticesFileIsInApplicationSupport() {
        let path = AppEnvironment.device(diagnostics: SilentLogger()).importNoticesFile.path

        #expect(path.contains("Application Support"))
        #expect(path.hasSuffix("PrestoCV/import-notices.json"))
    }
}
