import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (R11)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif

/// The device's file system for the import: POSIX calls, and security-scoped access where the platform has it.
public struct SystemImportFiles: ImportFileSystem {
    public init() {}

    public func startAccess(_ url: URL) -> Bool {
        #if canImport(Darwin)
        url.startAccessingSecurityScopedResource()
        #else
        false
        #endif
    }

    public func stopAccess(_ url: URL) {
        #if canImport(Darwin)
        url.stopAccessingSecurityScopedResource()
        #endif
    }

    public func resolve(_ url: URL) -> URL {
        guard let resolved = realpath(url.path, nil) else { return url.standardizedFileURL }
        defer { free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved))
    }

    public func identity(ofResolved url: URL) -> FileIdentity? {
        var status = stat()
        guard lstat(url.path, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { return nil }
        return FileIdentity(status)
    }

    public func read(_ url: URL, identity: FileIdentity, atMost limit: Int) throws(ImportFileError) -> FileRead {
        try readFile(at: url.path, identity: identity, atMost: limit)
    }

    public func remove(_ url: URL, identity: FileIdentity) throws(ImportFileError) {
        try removeFile(url, identity: identity)
    }

    public func entries(in folder: URL) throws(ImportFileError) -> [URL] {
        try folderEntries(at: folder)
    }

    public func contents(of url: URL, atMost limit: Int) throws(ImportFileError) -> FileRead? {
        try fileContents(at: url.path, atMost: limit)
    }

    public func store(_ data: Data, at url: URL) throws(ImportFileError) {
        try storeFile(data, at: url)
    }
}

fileprivate extension FileIdentity {
    init(_ status: stat) {
        self.init(device: UInt64(truncatingIfNeeded: status.st_dev), file: UInt64(truncatingIfNeeded: status.st_ino))
    }
}

// The members `read` and `remove` hide the C functions of the same names, so the work is in free functions.

private func folderEntries(at folder: URL) throws(ImportFileError) -> [URL] {
    guard let directory = opendir(folder.path) else {
        let code = errno
        if code == ENOENT { return [] }
        throw ImportFileError.system(code)
    }
    defer { closedir(directory) }
    var entries: [URL] = []
    while let entry = readdir(directory) {
        let name = withUnsafeBytes(of: entry.pointee.d_name) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        guard name != ".", name != ".." else { continue }
        entries.append(folder.appendingPathComponent(name))
    }
    return entries
}

private func readFile(at path: String, identity: FileIdentity, atMost limit: Int) throws(ImportFileError) -> FileRead {
    let descriptor = open(path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
    guard descriptor >= 0 else { throw ImportFileError.system(errno) }
    defer { close(descriptor) }
    var status = stat()
    guard fstat(descriptor, &status) == 0 else { throw ImportFileError.system(errno) }
    guard (status.st_mode & S_IFMT) == S_IFREG, FileIdentity(status) == identity else { throw ImportFileError.notTheFile }
    guard status.st_size <= Int64(limit) else { return .aboveTheLimit }
    // The stated size is a hint: a file that grows, or one that states 0 (/proc), is read up to the bound plus one byte
    var data = Data()
    data.reserveCapacity(Int(status.st_size))
    var buffer = [UInt8](repeating: 0, count: 65_536)
    while data.count <= limit {
        let wanted = min(buffer.count, limit + 1 - data.count)
        let count = buffer.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, wanted) }
        if count < 0 {
            let code = errno
            if code == EINTR { continue }
            throw ImportFileError.system(code)
        }
        if count == 0 { break }
        data.append(contentsOf: buffer[0..<count])
    }
    return data.count > limit ? .aboveTheLimit : .bytes(data)
}

/// The regular file at the path, read through `readFile`, which checks that the file it opens is the one looked at.
private func fileContents(at path: String, atMost limit: Int) throws(ImportFileError) -> FileRead? {
    var status = stat()
    guard lstat(path, &status) == 0 else {
        let code = errno
        if code == ENOENT { return nil }
        throw ImportFileError.system(code)
    }
    guard (status.st_mode & S_IFMT) == S_IFREG else { throw ImportFileError.notTheFile }
    return try readFile(at: path, identity: FileIdentity(status), atMost: limit)
}

/// Makes the folder when it is missing, writes the data whole to a file beside the path, then renames it over the path.
/// A file left beside by a write that failed is overwritten by the next one.
private func storeFile(_ data: Data, at url: URL) throws(ImportFileError) {
    let folder = url.deletingLastPathComponent().path
    if mkdir(folder, 0o700) != 0 {
        let code = errno
        guard code == EEXIST else { throw ImportFileError.system(code) }
    }
    let path = url.path
    let beside = path + ".writing"
    let descriptor = open(beside, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard descriptor >= 0 else { throw ImportFileError.system(errno) }
    if let code = writeAll(data, to: descriptor) {
        close(descriptor)
        throw ImportFileError.system(code)
    }
    guard close(descriptor) == 0 else { throw ImportFileError.system(errno) }
    guard rename(beside, path) == 0 else { throw ImportFileError.system(errno) }
}

/// Writes every byte, again after an interruption; the `errno` of a write that failed, or nil.
private func writeAll(_ data: Data, to descriptor: Int32) -> Int32? {
    data.withUnsafeBytes { bytes -> Int32? in
        guard let start = bytes.baseAddress else { return nil }
        var written = 0
        while written < bytes.count {
            let count = write(descriptor, start + written, bytes.count - written)
            if count < 0 {
                let code = errno
                if code == EINTR { continue }
                return code
            }
            written += count
        }
        return nil
    }
}

/// Moves the file aside under a name of its own, checks that what moved is the received file, then deletes it; anything
/// else is put back where it was. A path already gone is not an error.
private func removeFile(_ url: URL, identity: FileIdentity) throws(ImportFileError) {
    let path = url.path
    let aside = url.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).releasing").path
    guard rename(path, aside) == 0 else {
        let code = errno
        if code == ENOENT { return }
        throw ImportFileError.system(code)
    }
    var status = stat()
    guard lstat(aside, &status) == 0 else { throw ImportFileError.system(errno) }
    let kind = status.st_mode & S_IFMT
    guard kind == S_IFREG, FileIdentity(status) == identity else {
        guard putBack(aside, to: path, isDirectory: kind == S_IFDIR) else { throw ImportFileError.leftAside }
        throw ImportFileError.notTheFile
    }
    guard unlink(aside) == 0 else {
        let code = errno
        guard putBack(aside, to: path, isDirectory: false) else { throw ImportFileError.leftAside }
        throw ImportFileError.system(code)
    }
}

/// Puts a moved file back under its name, never over a file that took the name meanwhile: a link fails on an existing
/// name, and links a symbolic link itself. A folder cannot be linked, so it is renamed back.
private func putBack(_ aside: String, to path: String, isDirectory: Bool) -> Bool {
    if isDirectory { return rename(aside, path) == 0 }
    return linkat(AT_FDCWD, aside, AT_FDCWD, path, 0) == 0 && unlink(aside) == 0
}
