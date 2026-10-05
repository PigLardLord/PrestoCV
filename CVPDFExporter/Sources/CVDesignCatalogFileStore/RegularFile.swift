import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Reads a file only when it is a regular file of a bounded size, and says why it did not otherwise.
enum RegularFile {
    enum Outcome {
        case absent, data(Data), unreadable, tooLarge(Int)
    }

    /// Reads a regular file of at most `cap` bytes. Anything else (a symbolic link, a named pipe, a directory, an I/O
    /// failure) is unreadable, and an oversized file is reported without being read. Opening never blocks.
    static func read(_ url: URL, cap: Int) -> Outcome {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { return errno == ENOENT ? .absent : .unreadable }
        return outcome(of: FileHandle(fileDescriptor: descriptor, closeOnDealloc: true), cap: cap)
    }

    private static func outcome(of handle: FileHandle, cap: Int) -> Outcome {
        guard let status = FileStatus.of(descriptor: handle.fileDescriptor), status.isRegularFile else { return .unreadable }
        guard status.size <= cap else { return .tooLarge(status.size) }
        return readBytes(of: handle, cap: cap)
    }

    /// Reads one byte more than `cap`, so a file that grew since it was measured is still caught.
    private static func readBytes(of handle: FileHandle, cap: Int) -> Outcome {
        do {
            let data = try handle.read(upToCount: cap + 1) ?? Data()
            return data.count <= cap ? .data(data) : .tooLarge(data.count)
        } catch {
            return .unreadable
        }
    }
}
