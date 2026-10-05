import Testing
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVApplication
@testable import PrestoCVPersistence

@Suite("PersistedSchema · what is at a path")
struct StoreFilesTests {
    private func paths(in dir: URL) throws -> (file: String, folder: String, link: String, dangling: String, pipe: String) {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("file"), folder = dir.appendingPathComponent("folder")
        try Data("12345".utf8).write(to: file)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("link"), withDestinationURL: file)
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("dangling"), withDestinationURL: dir.appendingPathComponent("gone"))
        #expect(mkfifo(dir.appendingPathComponent("pipe").path, 0o600) == 0)
        return (file.path, folder.path, dir.appendingPathComponent("link").path, dir.appendingPathComponent("dangling").path,
                dir.appendingPathComponent("pipe").path)
    }

    @Test("a link is its own kind unless the link is followed, and nothing is missing")
    func kinds() throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let found = try paths(in: dir)
        #expect(StoreFiles.status(of: found.file).kind == .regularFile && StoreFiles.status(of: found.file).size == 5)
        #expect(StoreFiles.status(of: found.folder).kind == .directory)
        #expect(StoreFiles.status(of: found.pipe).kind == .other)
        #expect(StoreFiles.status(of: dir.appendingPathComponent("nothing").path).kind == .missing)
        #expect(StoreFiles.status(of: found.link).kind == .symbolicLink && StoreFiles.statusFollowingLinks(of: found.link).kind == .regularFile)
        #expect(StoreFiles.status(of: found.dangling).kind == .symbolicLink && StoreFiles.statusFollowingLinks(of: found.dangling).kind == .missing)
    }

    @Test("an open descriptor reports the kind and the size of the file behind it")
    func descriptor() throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let found = try paths(in: dir)
        let file = open(found.file, O_RDONLY), folder = open(found.folder, O_RDONLY)
        defer { close(file); close(folder) }
        #expect(StoreFiles.status(ofDescriptor: file).kind == .regularFile && StoreFiles.status(ofDescriptor: file).size == 5)
        #expect(StoreFiles.status(ofDescriptor: folder).kind == .directory)
        #expect(StoreFiles.status(ofDescriptor: -1).kind == .inaccessible)
    }

    @Test("a path that cannot be reached is inaccessible, not missing", .enabled(if: !isRoot))
    func inaccessible() throws {
        let dir = tempDir(); defer { chmod(dir.path, 0o755); try? FileManager.default.removeItem(at: dir) }
        let found = try paths(in: dir)
        chmod(dir.path, 0)
        #expect(StoreFiles.status(of: found.file).kind == .inaccessible)
        #expect(throws: RepositoryError.unreadable(file: "file")) { _ = try StoreFiles.exists(URL(fileURLWithPath: found.file)) }
    }

    @Test("a thing is there when anything is at its path, a link included, and a missing path is not")
    func exists() throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let found = try paths(in: dir)
        for path in [found.file, found.folder, found.link, found.dangling, found.pipe] { #expect(try StoreFiles.exists(URL(fileURLWithPath: path))) }
        #expect(try !StoreFiles.exists(dir.appendingPathComponent("nothing")))
    }
}
