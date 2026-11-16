import Testing
import Foundation
import DiagnosticLogging
@testable import PrestoCV

@Suite("FileEditorNoticeStore - the notice of each imported CV, in a file of its own beside the CVs")
struct EditorNoticeStoreTests {

    private let review = ImportReview(
        items: [ImportReview.Item(field: .title, reason: .byPosition, text: "Mobile Developer")],
        passages: [
            ImportReview.Passage(place: .top, text: "EU citizen", isWholeSection: false),
            ImportReview.Passage(place: .section("OWN VENTURES"), text: "Tidepool Notes | 2021 – today", isWholeSection: true),
        ]
    )

    private func makeTemporaryFolder() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("import-notices", isDirectory: true)
    }

    private func removeParent(of folder: URL) {
        try? FileManager.default.removeItem(at: folder.deletingLastPathComponent())
    }

    /// Every file of the folder, read as text: what the device still holds of the notices.
    private func contents(of folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).map { file in
            String(decoding: try Data(contentsOf: file), as: UTF8.self)
        }
    }

    @Test("A CV whose notice was never kept has none, and no folder is made for it")
    func noFolderHoldsNoNotice() async {
        let folder = makeTemporaryFolder()
        defer { removeParent(of: folder) }
        let store = FileEditorNoticeStore(directoryURL: folder)

        #expect(await store.notice(ofCVWithId: UUID()) == nil)
        await store.forget(cvWithId: UUID())
        #expect(await store.keptCVIds().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path), "Forgetting a notice that is not kept writes nothing")
    }

    @Test("A kept notice is read back whole, by the CV's id, after the app starts again")
    func keptNoticeIsReadBack() async throws {
        let folder = makeTemporaryFolder()
        defer { removeParent(of: folder) }
        let id = UUID()
        let other = UUID()

        try await FileEditorNoticeStore(directoryURL: folder).keep(.imported(review), forCVWithId: id)
        let store = FileEditorNoticeStore(directoryURL: folder)

        #expect(await store.notice(ofCVWithId: id) == .imported(review))
        #expect(await store.notice(ofCVWithId: other) == nil, "Each CV has its own notice")
        #expect(await store.keptCVIds() == [id])
    }

    @Test("A forgotten notice leaves the device with its text, and the other CVs keep theirs (#452)")
    func forgottenNoticeIsGone() async throws {
        let folder = makeTemporaryFolder()
        defer { removeParent(of: folder) }
        let store = FileEditorNoticeStore(directoryURL: folder)
        let dismissed = UUID()
        let kept = UUID()
        let privateText = "Harbor Timer | 2019 – 2020"
        try await store.keep(.imported(ImportReview(items: [], passages: [
            ImportReview.Passage(place: .section("OWN VENTURES"), text: privateText, isWholeSection: true),
        ])), forCVWithId: dismissed)
        try await store.keep(.importedDescription(review), forCVWithId: kept)

        await store.forget(cvWithId: dismissed)

        let reopened = FileEditorNoticeStore(directoryURL: folder)
        #expect(await reopened.notice(ofCVWithId: dismissed) == nil)
        #expect(await reopened.notice(ofCVWithId: kept) == .importedDescription(review))
        #expect(await reopened.keptCVIds() == [kept])
        #expect(try contents(of: folder).allSatisfy { !$0.contains("Harbor Timer") }, "No file of the folder still holds the text")
    }

    @Test("A damaged notice holds nothing and is removed; the other CVs keep theirs")
    func damagedNoticeIsRemoved() async throws {
        let folder = makeTemporaryFolder()
        defer { removeParent(of: folder) }
        let damaged = UUID()
        let kept = UUID()
        let store = FileEditorNoticeStore(directoryURL: folder)
        try await store.keep(.imported(review), forCVWithId: kept)
        let damagedFile = folder.appendingPathComponent("\(damaged.uuidString).json")
        try Data("{ not json".utf8).write(to: damagedFile)

        #expect(await store.notice(ofCVWithId: damaged) == nil)

        #expect(!FileManager.default.fileExists(atPath: damagedFile.path))
        #expect(await store.notice(ofCVWithId: kept) == .imported(review))
        try await store.keep(.imported(review), forCVWithId: damaged)
        #expect(await FileEditorNoticeStore(directoryURL: folder).notice(ofCVWithId: damaged) == .imported(review))
    }

    @Test("The kept CVs are the notices of the folder, nothing else that lies in it")
    func keptCVIdsListsOnlyNotices() async throws {
        let folder = makeTemporaryFolder()
        defer { removeParent(of: folder) }
        let store = FileEditorNoticeStore(directoryURL: folder)
        let first = UUID()
        let second = UUID()
        try await store.keep(.imported(review), forCVWithId: first)
        try await store.keep(.importedDescription(review), forCVWithId: second)
        for stray in ["notes.txt", "not-a-uuid.json", ".dat.nosync1234", "\(UUID().uuidString).tmp"] {
            try Data("x".utf8).write(to: folder.appendingPathComponent(stray))
        }

        #expect(Set(await store.keptCVIds()) == [first, second])
    }

    @Test("A notice that cannot be written is reported to the caller, so that the editor shows the save as failed (#452)")
    func unwritableNoticeThrows() async throws {
        let folder = makeTemporaryFolder()
        defer { removeParent(of: folder) }
        try FileManager.default.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: folder)
        let store = FileEditorNoticeStore(directoryURL: folder)

        await #expect(throws: (any Error).self) {
            try await store.keep(.imported(review), forCVWithId: UUID())
        }
    }

    @Test("The notices are kept in the app's own folder, beside the CVs")
    func noticesFolderIsInApplicationSupport() {
        let path = AppEnvironment.device(diagnostics: SilentLogger()).importNoticesDirectory.path

        #expect(path.contains("Application Support"))
        #expect(path.hasSuffix("PrestoCV/import-notices") || path.hasSuffix("PrestoCV/import-notices/"))
    }
}
