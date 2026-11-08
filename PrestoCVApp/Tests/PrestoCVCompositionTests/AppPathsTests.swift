import Foundation
import Testing
@testable import PrestoCVComposition

/// Where the new app keeps its files, decided in one place.
@Suite("The paths of the app")
struct AppPathsTests {
    private static func base() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("AppPathsTests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("The store, the trace and its copies are derived from the root and the temporary folder")
    func derived() {
        let root = URL(filePath: "/base/PrestoCVNext", directoryHint: .isDirectory)
        let temporary = URL(filePath: "/tmp/x", directoryHint: .isDirectory)
        let paths = AppPaths(root: root, temporary: temporary)
        #expect(paths.store.path == "/base/PrestoCVNext/Store")
        #expect(paths.trace.path == "/base/PrestoCVNext/Diagnostics")
        #expect(paths.traceShare.path == "/tmp/x/DiagnosticsShare")
    }

    @Test("The three folders are distinct, and none is the legacy store, Application Support/PrestoCV/CVs")
    func distinctFromTheLegacyStore() {
        let paths = AppPaths.onDevice()
        let folders = [paths.store, paths.trace, paths.traceShare].map(\.standardizedFileURL.path)
        #expect(Set(folders).count == 3)
        let legacy = URL.applicationSupportDirectory.appendingPathComponent("PrestoCV/CVs").standardizedFileURL.path
        for folder in folders {
            #expect(folder != legacy)
            #expect(!folder.hasPrefix(legacy))
        }
        #expect(paths.root.lastPathComponent == "PrestoCVNext")
    }

    @Test("Creating makes the root and the store, once, and the trace folder is left to its store")
    func creates() throws {
        let base = Self.base()
        defer { try? FileManager.default.removeItem(at: base) }
        let paths = AppPaths(root: base.appendingPathComponent("PrestoCVNext"), temporary: base)

        try paths.create()
        try paths.create()

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: paths.store.path, isDirectory: &isDirectory) && isDirectory.boolValue)
        #expect(!FileManager.default.fileExists(atPath: paths.trace.path), "The trace folder is made by its store on the first run")
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
}
