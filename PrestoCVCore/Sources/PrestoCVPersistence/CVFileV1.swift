import Foundation
import PrestoCVDomain

/// The stored form of a CV, schema 1: a DTO separate from the domain (ADR 0009, R12). The envelope is frozen:
/// `schemaVersion` is a top-level integer in every future version. The content of the CV sits at the same level as the
/// envelope's keys, and is `CVContentV1`, which `ApplicationFileV1` writes too.
struct CVFileV1: Codable, Equatable {
    static let version = 1

    let schemaVersion: Int
    let id: UUID
    let revision: Int
    let createdAt: Date, updatedAt: Date
    let content: CVContentV1

    typealias Invalid = FileInvalid

    private enum EnvelopeKeys: String, CodingKey { case schemaVersion, id, revision, createdAt, updatedAt }

    // MARK: Coding

    init(from decoder: any Decoder) throws {
        let envelope = try decoder.container(keyedBy: EnvelopeKeys.self)
        schemaVersion = try envelope.decode(Int.self, forKey: .schemaVersion)
        id = try envelope.decode(UUID.self, forKey: .id)
        revision = try envelope.decode(Int.self, forKey: .revision)
        createdAt = try envelope.decode(Date.self, forKey: .createdAt)
        updatedAt = try envelope.decode(Date.self, forKey: .updatedAt)
        content = try CVContentV1(from: decoder)
    }

    func encode(to encoder: any Encoder) throws {
        var envelope = encoder.container(keyedBy: EnvelopeKeys.self)
        try envelope.encode(schemaVersion, forKey: .schemaVersion)
        try envelope.encode(id, forKey: .id)
        try envelope.encode(revision, forKey: .revision)
        try envelope.encode(createdAt, forKey: .createdAt)
        try envelope.encode(updatedAt, forKey: .updatedAt)
        try content.encode(to: encoder)
    }

    static func decode(_ data: Data) throws -> CVFileV1 { try StoredJSON.decode(CVFileV1.self, from: data) }

    func encoded() throws -> Data { try StoredJSON.encode(self) }

    // MARK: From the domain

    init(_ cv: CV, createdAt: Date, updatedAt: Date) {
        schemaVersion = Self.version; id = cv.id.raw; revision = cv.revision
        self.createdAt = createdAt; self.updatedAt = updatedAt; content = CVContentV1(cv)
    }

    // MARK: To the domain

    func toDomain() throws(Invalid) -> CV {
        guard schemaVersion == Self.version else { throw Invalid(reason: "version") }
        guard (1...Int(Int32.max)).contains(revision) else { throw Invalid(reason: "revision") }   // no overflow on +1
        return try content.toCV(id: CVID(id), revision: revision, createdAt: createdAt, updatedAt: updatedAt)
    }
}
