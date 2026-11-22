import Foundation

/// What the launch sweep writes of the copies it found in the copy folders, for the next launch to delete (R12).
///
/// The record is the sweep's own memory in the app's temporary folder, not the person's data: a record that cannot be
/// read, one of another version too, is replaced by the launch that finds it, which only delays by one launch the
/// sweep of the copies it named.
struct CopiesRecord: Codable, Equatable {
    /// A copy by its name in its copy folder and its file. By the name and not the path, as a container's path changes
    /// when the app is updated; with the file, as a file number a delete frees can come back under the same name.
    struct Copy: Codable, Hashable {
        let name: String
        let device: UInt64
        let file: UInt64
    }

    /// Why a record is not read or not written.
    enum Problem: Error, Equatable {
        /// Not a record of the current version: not JSON, a field missing, or a limit passed.
        case notARecord
        /// A record of a version this app does not read.
        case unknownVersion
        /// A record that would not read back as it is, so it is not written.
        case wouldNotReadBack

        var reason: StaticString {
            switch self {
            case .notARecord: "notARecord"
            case .unknownVersion: "unknownVersion"
            case .wouldNotReadBack: "wouldNotReadBack"
            }
        }
    }

    static let currentVersion = 1
    /// The most copies a record holds; the sweep keeps the first ones it found.
    static let maximumCopies = 1_000
    /// The longest name a record holds, in bytes: no file system the app runs on takes a longer one (255 characters of
    /// at most four bytes).
    static let maximumNameBytes = 1_024
    /// The most bytes of a record that are read: `maximumCopies` copies of the longest names fit, even with each byte
    /// written as six (`\u0001`).
    static let maximumBytes = 8 << 20

    let schemaVersion: Int
    let copies: [Copy]

    init(copies: [Copy]) {
        schemaVersion = Self.currentVersion
        self.copies = copies
    }

    /// The record in `data`, taken only when it is of the current version and within the limits.
    static func decoded(from data: Data) throws(Problem) -> CopiesRecord {
        let decoder = JSONDecoder()
        let envelope: Envelope
        do {
            envelope = try decoder.decode(Envelope.self, from: data)
        } catch {
            throw Problem.notARecord
        }
        guard envelope.schemaVersion == currentVersion else { throw Problem.unknownVersion }
        let record: CopiesRecord
        do {
            record = try decoder.decode(CopiesRecord.self, from: data)
        } catch {
            throw Problem.notARecord
        }
        guard record.copies.count <= maximumCopies,
              record.copies.allSatisfy({ $0.name.utf8.count <= maximumNameBytes }) else { throw Problem.notARecord }
        return record
    }

    /// The bytes to write, given only when they read back as this record: within `maximumBytes` and through `decoded`.
    func encoded() throws(Problem) -> Data {
        let data: Data
        do {
            data = try JSONEncoder().encode(self)
        } catch {
            throw Problem.wouldNotReadBack
        }
        guard data.count <= Self.maximumBytes else { throw Problem.wouldNotReadBack }
        do throws(Problem) {
            guard try Self.decoded(from: data) == self else { throw Problem.wouldNotReadBack }
        } catch {
            throw Problem.wouldNotReadBack
        }
        return data
    }

    /// The frozen part of every version: what a record of any version is read by first.
    private struct Envelope: Decodable {
        let schemaVersion: Int
    }
}
