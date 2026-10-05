import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (PlatformAdapters)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVApplication
import PrestoCVDomain

/// One stored CV file, read the one way every reader in this target uses (PersistedSchema): opened once, without following a
/// link or blocking, checked and read through that descriptor within a size cap, then decoded strictly. The outcome
/// distinguishes what must not be touched (an I/O failure, anything but a regular file, too large, a newer schema)
/// from what is genuinely corrupt.
enum StoredCVFile {
    case cv(CV), absent, newer(Int), corrupt(String), unreadable, tooLarge(Int)

    static func read(_ url: URL, maxBytes: Int) -> StoredCVFile {
        do throws(Unusable) {
            let handle = try openForReading(url)
            return classify(try contents(of: handle, maxBytes: maxBytes))
        } catch {
            return error.file
        }
    }

    /// A file that cannot be read any further, with the outcome to report for it.
    private struct Unusable: Error { let file: StoredCVFile }

    private static func openForReading(_ url: URL) throws(Unusable) -> FileHandle {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw Unusable(file: errno == ENOENT ? .absent : .unreadable) }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    private static func contents(of handle: FileHandle, maxBytes: Int) throws(Unusable) -> Data {
        let size = try sizeOfRegularFile(handle.fileDescriptor)
        guard size <= maxBytes else { throw Unusable(file: .tooLarge(size)) }
        let data: Data
        do { data = try handle.read(upToCount: maxBytes + 1) ?? Data() } catch { throw Unusable(file: .unreadable) }
        guard data.count <= maxBytes else { throw Unusable(file: .tooLarge(data.count)) }
        return data
    }

    private static func sizeOfRegularFile(_ descriptor: Int32) throws(Unusable) -> Int {
        var status = stat()
        guard fstat(descriptor, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { throw Unusable(file: .unreadable) }
        return Int(status.st_size)
    }

    private static func classify(_ data: Data) -> StoredCVFile {
        let version: Int
        do { version = try JSONDecoder().decode(Envelope.self, from: data).schemaVersion } catch { return .corrupt("no schemaVersion envelope") }
        guard version <= CVFileV1.version else { return .newer(version) }
        return decodeCV(data)
    }

    private static func decodeCV(_ data: Data) -> StoredCVFile {
        do { return .cv(try CVFileV1.decode(data).toDomain()) }
        catch let invalid as CVFileV1.Invalid { return .corrupt(invalid.reason) }
        catch { return .corrupt("not a CV file") }
    }
}

extension StoredCVFile {
    /// The CV, or the typed failure for the file called `name`. A file that is not there is unreadable: the caller knew it existed.
    func requireCV(named name: String) throws(RepositoryError) -> CV {
        switch self {
        case .cv(let cv): return cv
        case .absent, .unreadable: throw .unreadable(file: name)
        case .newer(let version): throw .upgradeRequired(file: name, version: version)
        case .corrupt: throw .corrupt(file: name)
        case .tooLarge: throw .tooLarge(file: name)
        }
    }
}

/// The frozen envelope: a newer integer `schemaVersion` is valid data from a newer build, so it is read before anything else.
private struct Envelope: Decodable { let schemaVersion: Int }
