import Testing
import Foundation
import PrestoCVDomain
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

private let savedAt = Date(timeIntervalSince1970: 1_700_000_000)

/// A kind of stored file, read through the one reader every store of this target uses.
enum StoredKind: String, CaseIterable, CustomTestStringConvertible, Sendable {
    case cv, application, letterDefaults
    var testDescription: String { rawValue }

    /// A healthy file of this kind at revision 3, and the key the revision is written under.
    func golden() throws -> String {
        let data: Data
        switch self {
        case .cv:
            let cv = FixtureCV.full().stored(revision: 1, at: savedAt)
            data = try CVFileV1(CV(id: cv.id, revision: 3, createdAt: savedAt, updatedAt: savedAt, title: cv.title, personal: cv.personal, sections: cv.sections,
                                   design: cv.design, language: cv.language), createdAt: savedAt, updatedAt: savedAt).encoded()
        case .application:
            let application = FixtureApplication.full().stamped(revision: 3, createdAt: savedAt, updatedAt: savedAt)
            data = try ApplicationFileV1(application, createdAt: savedAt, updatedAt: savedAt).encoded()
        case .letterDefaults:
            data = try LetterDefaultsFileV1(StoredLetterDefaults(defaults: LetterDefaults(note: "x"), revision: 3, updatedAt: savedAt), updatedAt: savedAt).encoded()
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// What the reader makes of `data`, as a short code: the revision it read, or why it did not.
    func outcome(of data: Data) throws -> String {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stored-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        switch self {
        case .cv: return Self.describe(StoredFile<CV>.read(url, maxBytes: 1 << 20, supportedVersion: CVFileV1.version, decode: CVFileV1.read)) { $0.revision }
        case .application:
            return Self.describe(StoredFile<Application>.read(url, maxBytes: 1 << 20, supportedVersion: ApplicationFileV1.version, decode: ApplicationFileV1.read)) { $0.revision }
        case .letterDefaults:
            return Self.describe(StoredFile<StoredLetterDefaults>.read(url, maxBytes: 1 << 20, supportedVersion: LetterDefaultsFileV1.version,
                                                                         decode: LetterDefaultsFileV1.read)) { $0.revision }
        }
    }

    private static func describe<V>(_ file: StoredFile<V>, revision: (V) -> Int) -> String {
        switch file {
        case .value(let value): "revision \(revision(value))"
        case .absent: "absent"
        case .newer(let version): "newer \(version)"
        case .corrupt(let reason): "corrupt: \(reason)"
        case .unreadable: "unreadable"
        case .tooLarge: "too large"
        }
    }
}

@Suite("R12 · the one reader of every stored file, for each kind of file")
struct StoredFileTests {
    @Test("a healthy file reads, at its revision", arguments: StoredKind.allCases)
    func healthy(kind: StoredKind) throws {
        #expect(try kind.outcome(of: Data(kind.golden().utf8)) == "revision 3")
    }

    @Test("a document nested far deeper than any file of ours is corrupt, whatever surrounds it", arguments: StoredKind.allCases)
    func deepNesting(kind: StoredKind) throws {
        let depth = 600
        let nested = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        #expect(try kind.outcome(of: Data(nested.utf8)) == "corrupt: no schemaVersion envelope")
        let golden = try kind.golden()
        let inside = String(golden.dropLast()) + #","extra":"# + nested + "}"
        #expect(try kind.outcome(of: Data(inside.utf8)) == "corrupt: no schemaVersion envelope")
        let objects = String(repeating: #"{"a":"#, count: depth) + "1" + String(repeating: "}", count: depth)
        #expect(try kind.outcome(of: Data((String(golden.dropLast()) + #","extra":"# + objects + "}").utf8)) == "corrupt: no schemaVersion envelope")
    }

    @Test("bytes that are not UTF-8 are corrupt, never read with a replacement", arguments: StoredKind.allCases)
    func invalidUTF8(kind: StoredKind) throws {
        var data = Data(try kind.golden().utf8)
        let marker = try #require(data.range(of: Data(#""revision":3"#.utf8)))
        data.insert(contentsOf: [0xFF, 0xFE], at: marker.lowerBound)
        #expect(try kind.outcome(of: data).hasPrefix("corrupt"))
        var inString = Data(try kind.golden().utf8)
        let quoted = try #require(inString.range(of: Data(#""schemaVersion""#.utf8)))
        inString.replaceSubrange(quoted, with: Data([0x22, 0xFF, 0x22]))
        #expect(try kind.outcome(of: inString).hasPrefix("corrupt"))
    }

    @Test("a key that is written twice reads as its first value, and a newer schema written second does not hide the file", arguments: StoredKind.allCases)
    func duplicateKeys(kind: StoredKind) throws {
        let golden = try kind.golden()
        let body = String(golden.dropLast())
        #expect(try kind.outcome(of: Data((body + #","revision":9}"#).utf8)) == "revision 3")
        #expect(try kind.outcome(of: Data((body + #","schemaVersion":2}"#).utf8)) == "revision 3")
        let newerFirst = golden.replacingOccurrences(of: #""schemaVersion":1"#, with: #""schemaVersion":2,"schemaVersion":1"#)
        #expect(try kind.outcome(of: Data(newerFirst.utf8)) == "newer 2")
    }

    @Test("a file with something after its document, or an empty one, is corrupt", arguments: StoredKind.allCases)
    func trailingAndEmpty(kind: StoredKind) throws {
        #expect(try kind.outcome(of: Data((try kind.golden() + " x").utf8)).hasPrefix("corrupt"))
        #expect(try kind.outcome(of: Data()) == "corrupt: no schemaVersion envelope")
    }
}
