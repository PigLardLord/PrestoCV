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

/// A scratch folder laid out as an app's container beside a folder of the person's files.
struct Scratch {
    let root: URL
    let container: URL
    /// Where the system puts the copy of a file opened in the app.
    let inbox: URL
    let documents: URL
    /// Where older systems put that copy.
    let documentsInbox: URL
    /// A folder of the person's own files, outside the container.
    let chosen: URL
    /// Where the sweep keeps its record of the copies a launch found, in a folder of the app's own that is not made yet.
    let record: URL

    var copyFolders: [URL] { [inbox, documentsInbox] }

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        container = root.appendingPathComponent("Container", isDirectory: true)
        inbox = container.appendingPathComponent("tmp/app.example-Inbox", isDirectory: true)
        documents = container.appendingPathComponent("Documents", isDirectory: true)
        documentsInbox = documents.appendingPathComponent("Inbox", isDirectory: true)
        chosen = root.appendingPathComponent("Files", isDirectory: true)
        record = container.appendingPathComponent("tmp/ImportCopies/found.json", isDirectory: false)
        for folder in [inbox, documentsInbox, chosen] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    @discardableResult
    func file(_ name: String, in folder: URL, _ text: String = "%PDF-1.7") throws -> URL {
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

    /// Puts another file at `url`: written beside it, then renamed over it, so the path names a new file.
    func replace(_ url: URL, with text: String) throws {
        let beside = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        try Data(text.utf8).write(to: beside)
        guard rename(beside.path, url.path) == 0 else { throw SystemCallFailed(call: "rename", code: errno) }
    }

    /// Dates the file at `url` to `date`: its modification date, and on Apple platforms its creation date too.
    func date(_ url: URL, _ date: Date) throws {
        var attributes: [FileAttributeKey: Any] = [.modificationDate: date]
        #if canImport(Darwin)
        attributes[.creationDate] = date
        #endif
        try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
    }

    /// Makes a named pipe: a reader that opens it without O_NONBLOCK waits for a writer that never comes.
    @discardableResult
    func pipe(_ name: String, in folder: URL) throws -> URL {
        let url = folder.appendingPathComponent(name)
        guard mkfifo(url.path, 0o600) == 0 else { throw SystemCallFailed(call: "mkfifo", code: errno) }
        return url
    }

    /// The kind of what the path names, without following a link (`S_IFREG`, `S_IFDIR`, `S_IFIFO`, `S_IFLNK`).
    func kind(of url: URL) -> mode_t? {
        var status = stat()
        guard lstat(url.path, &status) == 0 else { return nil }
        return status.st_mode & S_IFMT
    }

    /// The identity of what the path names, whatever its kind.
    func identity(of url: URL) -> FileIdentity? {
        var status = stat()
        guard lstat(url.path, &status) == 0 else { return nil }
        return FileIdentity(
            device: UInt64(truncatingIfNeeded: status.st_dev),
            file: UInt64(truncatingIfNeeded: status.st_ino)
        )
    }

    func names(in folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
    }

    func remove() {
        do {
            try FileManager.default.removeItem(at: root)
        } catch {
            Issue.record("the scratch folder stays: \(error)")
        }
    }
}

struct SystemCallFailed: Error {
    let call: String
    let code: Int32
}
