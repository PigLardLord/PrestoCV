import Foundation
import PrestoCVDomain

/// The three texts of the letter defaults in schema 1, without an envelope: what `LetterDefaultsFileV1` and the provenance
/// of `ApplicationFileV1` both write, so the bounds exist once, in `LetterDefaults` (R6, R12).
struct LetterDefaultsContentV1: Codable, Equatable {
    let salaryExpectation: String, startDate: String, note: String

    init(_ defaults: LetterDefaults) {
        salaryExpectation = defaults.salaryExpectation; startDate = defaults.startDate; note = defaults.note
    }

    /// A stored text is exactly what the domain produces from it: trimmed and within its bound. A text that is not is corrupt,
    /// never normalised on read.
    func toDomain() throws(FileInvalid) -> LetterDefaults {
        let defaults: LetterDefaults
        do { defaults = try LetterDefaults(salaryExpectation: salaryExpectation, startDate: startDate, note: note) }
        catch { throw FileInvalid(reason: "letter defaults: \(error)") }
        guard LetterDefaultsContentV1(defaults) == self else { throw FileInvalid(reason: "letter defaults are not canonical") }
        return defaults
    }
}

/// The stored form of the person's letter defaults, schema 1: a DTO separate from the domain (ADR 0019, R12). The envelope is
/// frozen, `schemaVersion`, `revision` and `updatedAt`, and the three texts sit at the same level. Decoding is strict, and
/// every text must be in the canonical form the domain produces from it.
struct LetterDefaultsFileV1: Codable, Equatable {
    static let version = 1

    let schemaVersion: Int
    let revision: Int
    let updatedAt: Date
    let content: LetterDefaultsContentV1

    typealias Invalid = FileInvalid

    private enum EnvelopeKeys: String, CodingKey { case schemaVersion, revision, updatedAt }

    // MARK: Coding

    init(from decoder: any Decoder) throws {
        let envelope = try decoder.container(keyedBy: EnvelopeKeys.self)
        schemaVersion = try envelope.decode(Int.self, forKey: .schemaVersion)
        revision = try envelope.decode(Int.self, forKey: .revision)
        updatedAt = try envelope.decode(Date.self, forKey: .updatedAt)
        content = try LetterDefaultsContentV1(from: decoder)
    }

    func encode(to encoder: any Encoder) throws {
        var envelope = encoder.container(keyedBy: EnvelopeKeys.self)
        try envelope.encode(schemaVersion, forKey: .schemaVersion)
        try envelope.encode(revision, forKey: .revision)
        try envelope.encode(updatedAt, forKey: .updatedAt)
        try content.encode(to: encoder)
    }

    static func decode(_ data: Data) throws -> LetterDefaultsFileV1 { try StoredJSON.decode(LetterDefaultsFileV1.self, from: data) }

    func encoded() throws -> Data { try StoredJSON.encode(self) }

    /// The strict read of stored letter defaults: the file must decode, and every value in it must be valid.
    static func read(_ data: Data) throws(Invalid) -> StoredLetterDefaults {
        let file: LetterDefaultsFileV1
        do { file = try decode(data) } catch { throw Invalid(reason: "not a letter defaults file") }
        return try file.toDomain()
    }

    // MARK: From and to the domain

    init(_ stored: StoredLetterDefaults, updatedAt: Date) {
        schemaVersion = Self.version; revision = stored.revision; self.updatedAt = updatedAt; content = LetterDefaultsContentV1(stored.defaults)
    }

    func toDomain() throws(Invalid) -> StoredLetterDefaults {
        guard schemaVersion == Self.version else { throw Invalid(reason: "version") }
        guard (1...Int(Int32.max)).contains(revision) else { throw Invalid(reason: "revision") }   // no overflow on +1
        return StoredLetterDefaults(defaults: try content.toDomain(), revision: revision, updatedAt: updatedAt)
    }
}
