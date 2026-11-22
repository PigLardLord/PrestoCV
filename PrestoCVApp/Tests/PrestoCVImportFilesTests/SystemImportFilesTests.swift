import DiagnosticLogging
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVImportFiles
import Testing

@Suite("The device's file system for the import")
struct SystemImportFilesTests {
    private let files = SystemImportFiles()

    // MARK: Identity

    @Test("a file and a link resolved to it have one identity; another file has its own")
    func identityOfFileAndLink() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.chosen)
        let other = try scratch.file("other.pdf", in: scratch.chosen)
        let link = try scratch.link("link.pdf", to: file)

        let identity = try #require(files.identity(ofResolved: files.resolve(file)))

        #expect(files.identity(ofResolved: files.resolve(link)) == identity)
        #expect(files.identity(ofResolved: files.resolve(other)) != identity)
    }

    @Test("a hard link is the same file")
    func hardLinkIsTheSameFile() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.inbox)
        let hard = scratch.inbox.appendingPathComponent("cv-1.pdf")
        try FileManager.default.linkItem(at: file, to: hard)

        #expect(files.identity(ofResolved: files.resolve(hard)) == files.identity(ofResolved: files.resolve(file)))
    }

    @Test("no identity for a pipe, a folder, a link left unresolved or a missing path")
    func noIdentityForWhatIsNotARegularFile() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let pipe = try scratch.pipe("cv.pdf", in: scratch.inbox)
        let file = try scratch.file("target.pdf", in: scratch.chosen)
        let link = try scratch.link("link.pdf", to: file)

        #expect(files.identity(ofResolved: pipe) == nil)
        #expect(files.identity(ofResolved: scratch.inbox) == nil)
        #expect(files.identity(ofResolved: link) == nil)
        #expect(files.identity(ofResolved: scratch.chosen.appendingPathComponent("gone.pdf")) == nil)
    }

    @Test("a path spelled with . and .. resolves to the file's own path")
    func resolveRemovesDots() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.inbox)
        let spelled = URL(fileURLWithPath: scratch.inbox.path + "/../app.example-Inbox/./cv.pdf")

        #expect(files.resolve(spelled) == files.resolve(file))
        #expect(files.resolve(spelled).lastPathComponent == "cv.pdf")
    }

    // MARK: Read

    @Test("a read of another identity is refused")
    func readOfAnotherIdentity() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.inbox)

        #expect(throws: ImportFileError.notTheFile) {
            try files.read(file, identity: FileIdentity(device: 0, file: 0), atMost: 1_000)
        }
    }

    @Test("a read of a pipe is refused without waiting for a writer", .timeLimit(.minutes(1)))
    func readOfAPipe() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let pipe = try scratch.pipe("cv.pdf", in: scratch.inbox)
        let identity = try #require(scratch.identity(of: pipe))

        #expect(throws: ImportFileError.notTheFile) {
            try files.read(pipe, identity: identity, atMost: 1_000)
        }
    }

    @Test("a file one byte above the bound is not read; one at the bound is")
    func readAtTheBound() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let above = try scratch.file("above.pdf", in: scratch.inbox, "12345678901")
        let at = try scratch.file("at.pdf", in: scratch.inbox, "1234567890")

        let aboveRead = try files.read(above, identity: #require(scratch.identity(of: above)), atMost: 10)
        let atRead = try files.read(at, identity: #require(scratch.identity(of: at)), atMost: 10)

        #expect(aboveRead == .aboveTheLimit)
        #expect(atRead == .bytes(Data("1234567890".utf8)))
    }

    @Test(
        "a file that states a size of 0 is still read only up to the bound",
        .enabled(if: FileManager.default.fileExists(atPath: "/proc/self/status"))
    )
    func readOfAnUnderstatedSize() throws {
        let status = URL(fileURLWithPath: "/proc/self/status")
        let identity = try #require(files.identity(ofResolved: status))

        #expect(try files.read(status, identity: identity, atMost: 10) == .aboveTheLimit)
    }

    @Test("a file larger than one buffer is read whole")
    func readOfALargeFile() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let bytes = Data((0..<200_000).map { UInt8(truncatingIfNeeded: $0) })
        let file = scratch.inbox.appendingPathComponent("large.pdf")
        try bytes.write(to: file)

        let read = try files.read(file, identity: #require(scratch.identity(of: file)), atMost: 300_000)

        #expect(read == .bytes(bytes))
    }

    @Test("a read of a path that is gone gives the system's error")
    func readOfAMissingFile() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.inbox)
        let identity = try #require(scratch.identity(of: file))
        try FileManager.default.removeItem(at: file)

        #expect(throws: ImportFileError.system(ENOENT)) {
            try files.read(file, identity: identity, atMost: 1_000)
        }
    }

    // MARK: Remove

    @Test("the received file is deleted and nothing is left beside it")
    func removeOfTheFile() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.inbox)

        try files.remove(file, identity: #require(scratch.identity(of: file)))

        #expect(try scratch.names(in: scratch.inbox) == [])
    }

    @Test("a file that took the name is put back, untouched")
    func removeOfAReplacedFile() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.inbox, "mine")
        let identity = try #require(scratch.identity(of: file))
        try scratch.replace(file, with: "other")

        #expect(throws: ImportFileError.notTheFile) {
            try files.remove(file, identity: identity)
        }
        #expect(try String(contentsOf: file, encoding: .utf8) == "other")
        #expect(try scratch.names(in: scratch.inbox) == ["cv.pdf"])
    }

    @Test("a pipe that took the name is put back as a pipe")
    func removeOfAPipe() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.inbox)
        let identity = try #require(scratch.identity(of: file))
        try FileManager.default.removeItem(at: file)
        try scratch.pipe("cv.pdf", in: scratch.inbox)

        #expect(throws: ImportFileError.notTheFile) {
            try files.remove(file, identity: identity)
        }
        #expect(scratch.kind(of: file) == S_IFIFO)
        #expect(try scratch.names(in: scratch.inbox) == ["cv.pdf"])
    }

    @Test("a folder that took the name is put back with what it holds")
    func removeOfAFolder() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.inbox)
        let identity = try #require(scratch.identity(of: file))
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        try scratch.file("inside.pdf", in: file)

        #expect(throws: ImportFileError.notTheFile) {
            try files.remove(file, identity: identity)
        }
        #expect(scratch.kind(of: file) == S_IFDIR)
        #expect(try scratch.names(in: file) == ["inside.pdf"])
        #expect(try scratch.names(in: scratch.inbox) == ["cv.pdf"])
    }

    @Test("a link that took the name is put back as a link, even one to the file itself")
    func removeOfALink() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.inbox)
        let identity = try #require(scratch.identity(of: file))
        let moved = scratch.chosen.appendingPathComponent("moved.pdf")
        try FileManager.default.moveItem(at: file, to: moved)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: moved)

        #expect(throws: ImportFileError.notTheFile) {
            try files.remove(file, identity: identity)
        }
        #expect(scratch.kind(of: file) == S_IFLNK)
        #expect(scratch.kind(of: moved) == S_IFREG)
        #expect(try scratch.names(in: scratch.inbox) == ["cv.pdf"])
    }

    @Test("a path already gone is no error")
    func removeOfAMissingFile() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("cv.pdf", in: scratch.inbox)
        let identity = try #require(scratch.identity(of: file))
        try FileManager.default.removeItem(at: file)

        try files.remove(file, identity: identity)

        #expect(try scratch.names(in: scratch.inbox) == [])
    }

    // MARK: Contents and store

    @Test("the contents of a file are read within the bound, and nothing at the path gives none")
    func contentsOfAFile() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("found.json", in: scratch.chosen, "{}")

        #expect(try files.contents(of: file, atMost: 2) == .bytes(Data("{}".utf8)))
        #expect(try files.contents(of: file, atMost: 1) == .aboveTheLimit)
        #expect(try files.contents(of: scratch.chosen.appendingPathComponent("none.json"), atMost: 2) == nil)
    }

    @Test("the contents of a folder, a pipe or a link are refused without following the link or waiting for a writer", .timeLimit(.minutes(1)))
    func contentsOfWhatIsNotAFile() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("found.json", in: scratch.chosen, "{}")
        let link = try scratch.link("link.json", to: file)
        let pipe = try scratch.pipe("pipe.json", in: scratch.chosen)

        for url in [scratch.inbox, pipe, link] {
            #expect(throws: ImportFileError.notTheFile, "\(url.lastPathComponent)") {
                try files.contents(of: url, atMost: 100)
            }
        }
    }

    @Test("the contents of a path under a file give the system's error")
    func contentsUnderAFile() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("ImportCopies", in: scratch.chosen)

        #expect(throws: ImportFileError.system(ENOTDIR)) {
            try files.contents(of: file.appendingPathComponent("found.json"), atMost: 100)
        }
    }

    @Test("a stored file is written whole, in a folder made for it, and a second store replaces it, leaving nothing beside")
    func storeMakesTheFolderAndReplaces() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let folder = scratch.chosen.appendingPathComponent("ImportCopies", isDirectory: true)
        let url = folder.appendingPathComponent("found.json")
        let large = Data((0..<200_000).map { UInt8(truncatingIfNeeded: $0) })

        try files.store(large, at: url)
        #expect(try Data(contentsOf: url) == large)

        try files.store(Data("{}".utf8), at: url)
        #expect(try Data(contentsOf: url) == Data("{}".utf8))
        #expect(try scratch.names(in: folder) == ["found.json"])
    }

    @Test("a store under a path whose folder's own folder is missing, or that is a file, gives the system's error")
    func storeThatCannotBeWritten() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let file = try scratch.file("ImportCopies", in: scratch.chosen)
        let missing = scratch.chosen.appendingPathComponent("none/ImportCopies/found.json")

        #expect(throws: ImportFileError.system(ENOTDIR)) {
            try files.store(Data("{}".utf8), at: file.appendingPathComponent("found.json"))
        }
        #expect(throws: ImportFileError.system(ENOENT)) {
            try files.store(Data("{}".utf8), at: missing)
        }
        #expect(try scratch.names(in: scratch.chosen) == ["ImportCopies"])
    }

    @Test("a link at the stored path is replaced by the file, and what it named is untouched")
    func storeReplacesALink() throws {
        let scratch = try Scratch()
        defer { scratch.remove() }
        let mine = try scratch.file("mine.pdf", in: scratch.inbox, "%PDF-1.7 mine")
        let link = try scratch.link("found.json", to: mine)

        try files.store(Data("{}".utf8), at: link)

        #expect(scratch.kind(of: link) == S_IFREG)
        #expect(try Data(contentsOf: link) == Data("{}".utf8))
        #expect(try Data(contentsOf: mine) == Data("%PDF-1.7 mine".utf8))
    }

    // MARK: Log codes

    @Test("an error is logged by its errno name, or as system for one the import does not name")
    func logCodes() {
        #expect(ImportFileError.system(ENOENT).logCode.description == "ENOENT")
        #expect(ImportFileError.system(EACCES).logCode.description == "EACCES")
        #expect(ImportFileError.system(9_999).logCode.description == "system")
        #expect(ImportFileError.notTheFile.logCode.description == "notTheFile")
        #expect(ImportFileError.leftAside.logCode.description == "leftAside")
    }
}
