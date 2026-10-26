import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (R11)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVDomain

/// One stored CV file, read the one way every reader in this target uses (R12): opened once, without following a
/// link or blocking, checked and read through that descriptor within a size cap, then decoded strictly. The outcome
/// distinguishes what must not be touched (an I/O failure, anything but a regular file, too large, a newer schema)
/// from what is genuinely corrupt.
enum StoredCVFile {
    case cv(CV), absent, newer(Int), corrupt(String), unreadable, tooLarge(Int)

    static func read(_ url: URL, maxBytes: Int) -> StoredCVFile {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return errno == ENOENT ? .absent : .unreadable }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var status = stat()
        guard fstat(fd, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { return .unreadable }
        guard Int(status.st_size) <= maxBytes else { return .tooLarge(Int(status.st_size)) }
        let data: Data
        do { data = try handle.read(upToCount: maxBytes + 1) ?? Data() } catch { return .unreadable }
        guard data.count <= maxBytes else { return .tooLarge(data.count) }
        // The frozen envelope: a newer integer schemaVersion is valid data from a newer build.
        struct Peek: Decodable { let schemaVersion: Int }
        do {
            let peek = try JSONDecoder().decode(Peek.self, from: data)
            if peek.schemaVersion > CVFileV1.version { return .newer(peek.schemaVersion) }
        } catch { return .corrupt("no schemaVersion envelope") }
        do { return .cv(try CVFileV1.decode(data).toDomain()) }
        catch let invalid as CVFileV1.Invalid { return .corrupt(invalid.reason) }
        catch { return .corrupt("not a CV file") }
    }
}
