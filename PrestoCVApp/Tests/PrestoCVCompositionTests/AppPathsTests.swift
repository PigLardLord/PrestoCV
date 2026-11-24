import Foundation
import Testing
@testable import PrestoCVComposition

/// Where the new app keeps its files, decided in one place.
@Suite("The paths of the app")
struct AppPathsTests {
    private static func base() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("AppPathsTests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("The store, the designs, the trace, its copies and the export's share are derived from the root and the temporary folder")
    func derived() {
        let root = URL(filePath: "/base/PrestoCVNext", directoryHint: .isDirectory)
        let temporary = URL(filePath: "/tmp/x", directoryHint: .isDirectory)
        let paths = AppPaths(root: root, temporary: temporary)
        #expect(paths.store.path == "/base/PrestoCVNext/Store")
        #expect(paths.designs.path == "/base/PrestoCVNext/Designs")
        #expect(paths.legacyReportOff.path == "/base/PrestoCVNext/LegacyReportOff")
        #expect(paths.trace.path == "/base/PrestoCVNext/Diagnostics")
        #expect(paths.traceShare.path == "/tmp/x/DiagnosticsShare")
        #expect(paths.exportShare.path == "/tmp/x/ExportShare")
    }

    @Test("The five folders are distinct, and none is the legacy store, Application Support/PrestoCV/CVs")
    func distinctFromTheLegacyStore() {
        let paths = AppPaths.onDevice()
        let folders = [paths.store, paths.designs, paths.trace, paths.traceShare, paths.exportShare]
            .map(\.standardizedFileURL.path)
        #expect(Set(folders).count == 5)
        let legacy = URL.applicationSupportDirectory.appendingPathComponent("PrestoCV/CVs").standardizedFileURL.path
        #expect(AppPaths.legacyStoreOnDevice().standardizedFileURL.path == legacy, "The launch imports from the released app's store")
        for folder in folders {
            #expect(folder != legacy)
            #expect(!folder.hasPrefix(legacy))
        }
        #expect(paths.root.lastPathComponent == "PrestoCVNext")
    }

    @Test("Creating makes the root and the store, once, and the trace and design folders are left to their stores")
    func creates() throws {
        let base = Self.base()
        defer { try? FileManager.default.removeItem(at: base) }
        let paths = AppPaths(root: base.appendingPathComponent("PrestoCVNext"), temporary: base)

        try paths.create()
        try paths.create()

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: paths.store.path, isDirectory: &isDirectory) && isDirectory.boolValue)
        #expect(!FileManager.default.fileExists(atPath: paths.trace.path), "The trace folder is made by its store on the first run")
        #expect(!FileManager.default.fileExists(atPath: paths.designs.path), "The design folder is made by its store")
    }

    @Test("A root under a file fails with a typed error")
    func failsUnderAFile() throws {
        let base = Self.base()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let file = base.appendingPathComponent("file")
        try Data("x".utf8).write(to: file)
        let paths = AppPaths(root: file.appendingPathComponent("PrestoCVNext"), temporary: base)

        #expect(throws: AppPaths.Failure.storeUnavailable) { try paths.create() }
    }

    // MARK: Import copies

    @Test("The copy folders are the bundle's inbox in the temporary folder and the inbox in Documents")
    func importCopies() {
        let temporary = URL(filePath: "/tmp/x", directoryHint: .isDirectory)
        let documents = URL(filePath: "/base/Documents", directoryHint: .isDirectory)

        let folders = AppPaths.importCopies(temporary: temporary, documents: documents, bundleID: "app.example")

        #expect(folders.map(\.path) == ["/tmp/x/app.example-Inbox", "/base/Documents/Inbox"])
    }

    @Test("With no bundle id only the inbox in Documents is a copy folder", arguments: [nil, ""] as [String?])
    func importCopiesWithoutABundle(bundleID: String?) {
        let temporary = URL(filePath: "/tmp/x", directoryHint: .isDirectory)
        let documents = URL(filePath: "/base/Documents", directoryHint: .isDirectory)

        let folders = AppPaths.importCopies(temporary: temporary, documents: documents, bundleID: bundleID)

        #expect(folders.map(\.path) == ["/base/Documents/Inbox"])
    }

    #if !os(iOS)
    @Test("Outside iOS a file is opened where it is, so the device has no copy folder")
    func noCopyFoldersOutsideIOS() {
        #expect(AppPaths.importCopiesOnDevice().isEmpty)
    }
    #endif
}
