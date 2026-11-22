import Foundation
@testable import PrestoCVImportFiles
import Testing

/// The record the launch sweep keeps of the copies it found: what it writes reads back through the same strict decoding.
@Suite("The record of the copies a launch found")
struct CopiesRecordTests {
    private static func copies(_ count: Int, name: String = "CV.pdf") -> [CopiesRecord.Copy] {
        (0..<count).map { CopiesRecord.Copy(name: name, device: 1, file: UInt64($0)) }
    }

    @Test("a record within its limits is written with its version and reads back as it was")
    func readsBack() throws {
        let record = CopiesRecord(copies: Self.copies(CopiesRecord.maximumCopies, name: String(repeating: "é", count: 512)))

        let data = try record.encoded()

        #expect(try CopiesRecord.decoded(from: data) == record)
        #expect(record.schemaVersion == 1)
    }

    @Test("a record that the decoding would refuse is not written: more than 1,000 copies, or a name longer than 1,024 bytes")
    func refusesWhatWouldNotReadBack() {
        let tooMany = CopiesRecord(copies: Self.copies(CopiesRecord.maximumCopies + 1))
        let tooLong = CopiesRecord(copies: Self.copies(1, name: String(repeating: "é", count: 512) + "x"))

        #expect(throws: CopiesRecord.Problem.wouldNotReadBack) { try tooMany.encoded() }
        #expect(throws: CopiesRecord.Problem.wouldNotReadBack) { try tooLong.encoded() }
    }
}
