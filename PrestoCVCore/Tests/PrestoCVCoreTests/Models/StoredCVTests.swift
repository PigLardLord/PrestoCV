import Testing
import Foundation
@testable import PrestoCVCore

@Suite("StoredCV Tests")
struct StoredCVTests {
    
    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    private func decode(_ json: String) throws -> StoredCV {
        try decoder().decode(StoredCV.self, from: Data(json.utf8))
    }
    
    // MARK: - Strict Identity Tests
    
    @Test("An empty object is rejected")
    func emptyObjectIsRejected() {
        #expect(throws: DecodingError.self) {
            _ = try decode("{}")
        }
    }
    
    @Test("A CV without an id is rejected")
    func cvWithoutIdIsRejected() {
        #expect(throws: DecodingError.self) {
            _ = try decode(#"{"name": "Ghost", "personalInfo": {"name": "Jane"}}"#)
        }
    }
    
    @Test("An id that is not a UUID is rejected")
    func invalidIdIsRejected() {
        #expect(throws: DecodingError.self) {
            _ = try decode(#"{"id": "not-a-uuid", "name": "Broken"}"#)
        }
    }
    
    @Test("A CV with an id and no times is accepted")
    func cvWithoutTimesIsAccepted() throws {
        let id = UUID()
        
        let stored = try decode(#"{"id": "\#(id.uuidString)", "name": "Older file"}"#)
        
        #expect(stored.cv.id == id)
        #expect(stored.cv.name == "Older file")
        #expect(stored.createdAt == nil)
        #expect(stored.updatedAt == nil)
    }
    
    // MARK: - Encoding Tests
    
    @Test("A stored CV is encoded flat, next to its times")
    func encodingIsFlat() throws {
        let cv = CVTestDataBuilder.completeCV().build()
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let updated = Date(timeIntervalSince1970: 1_700_000_090)
        
        let data = try encoder().encode(StoredCV(cv: cv, createdAt: created, updatedAt: updated))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        #expect(object["id"] as? String == cv.id.uuidString)
        #expect(object["name"] as? String == cv.name)
        #expect(object["createdAt"] as? String == "2023-11-14T22:13:20Z")
        #expect(object["updatedAt"] as? String == "2023-11-14T22:14:50Z")
        #expect(object["cv"] == nil)
    }
    
    @Test("A stored CV without times writes no time keys")
    func encodingOmitsMissingTimes() throws {
        let data = try encoder().encode(StoredCV(cv: CVTestDataBuilder.minimalCV().build()))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        
        #expect(object["createdAt"] == nil)
        #expect(object["updatedAt"] == nil)
    }
    
    @Test("A stored CV survives a round trip")
    func roundTrip() throws {
        let stored = StoredCV(
            cv: CVTestDataBuilder.completeCV().build(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_090)
        )
        
        let decoded = try decoder().decode(StoredCV.self, from: encoder().encode(stored))
        
        #expect(decoded == stored)
    }
    
    @Test("A CV encoded by the model alone is read as a stored CV")
    func modelEncodingIsReadable() throws {
        let cv = CVTestDataBuilder.completeCV().build()
        
        let decoded = try decoder().decode(StoredCV.self, from: encoder().encode(cv))
        
        #expect(decoded.cv == cv)
    }
    
    // MARK: - List Order Tests
    
    @Test("The most recently changed CV is listed first")
    func newestIsListedFirst() {
        let older = StoredCV(cv: CVModel(name: "Older"), updatedAt: Date(timeIntervalSince1970: 100))
        let newer = StoredCV(cv: CVModel(name: "Newer"), updatedAt: Date(timeIntervalSince1970: 200))
        
        #expect(StoredCV.isListedBefore(newer, older))
        #expect(!StoredCV.isListedBefore(older, newer))
    }
    
    @Test("A CV with a time is listed before one without")
    func stampedIsListedBeforeUnstamped() {
        let stamped = StoredCV(cv: CVModel(name: "Z"), updatedAt: Date(timeIntervalSince1970: 100))
        let unstamped = StoredCV(cv: CVModel(name: "A"))
        
        #expect(StoredCV.isListedBefore(stamped, unstamped))
        #expect(!StoredCV.isListedBefore(unstamped, stamped))
    }
    
    @Test("Equal times fall back to the name, ignoring case, and then to the id")
    func equalTimesFallBackToNameThenId() {
        let time = Date(timeIntervalSince1970: 100)
        let lowId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let highId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let alpha = StoredCV(cv: CVModel(name: "alpha"), updatedAt: time)
        let beta = StoredCV(cv: CVModel(name: "Beta"), updatedAt: time)
        let sameLow = StoredCV(cv: CVModel(id: lowId, name: "Same"), updatedAt: time)
        let sameHigh = StoredCV(cv: CVModel(id: highId, name: "Same"), updatedAt: time)
        
        #expect(StoredCV.isListedBefore(alpha, beta))
        #expect(StoredCV.isListedBefore(sameLow, sameHigh))
        #expect(!StoredCV.isListedBefore(sameHigh, sameLow))
        #expect(!StoredCV.isListedBefore(sameLow, sameLow))
    }
}
