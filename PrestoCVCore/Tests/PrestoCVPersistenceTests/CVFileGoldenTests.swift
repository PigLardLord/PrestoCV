import Testing
import Foundation
import PrestoCVDomain
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

/// The bytes `CVFileV1` writes, pinned (ADR 0009, R12): the stored format does not change when the code that writes
/// it is reorganised. Changing a byte here is a change of the schema, and it ships with a new version.
private let fullGolden = #"{"certifications":[{"description":"Concurrency","issued":{"month":6,"year":2021},"issuer":"Apple","link":"https:\/\/cert.example\/1","name":"Swift Certified"}],"createdAt":"2023-11-14T22:13:20Z","design":{"design":"modern","fonts":"classic","palette":"ocean"},"education":[{"current":false,"degree":"Mathematics","description":"Tutored","end":{"month":7,"year":2015},"school":"Home","start":{"month":9,"year":2012}}],"experiences":[{"company":"Analytical","current":true,"description":"Engines","location":"London","role":"Engineer","start":{"month":3,"year":2019}}],"id":"11111111-1111-1111-1111-111111111111","interests":["Chess","Running"],"language":"it","languages":[{"language":"Italian","proficiency":"native"},{"language":"English","proficiency":"c1"}],"personal":{"email":"ada@example.com","fullName":"Ada Lovelace","location":"Roma","phone":"+39 06 1234567","professionalTitle":"iOS Engineer","summary":"Builds careful software.","website":"https:\/\/ada.example"},"profiles":[{"link":"https:\/\/github.com\/ada","platform":"GitHub"}],"revision":3,"schemaVersion":1,"skills":[{"level":5,"name":"Swift"},{"level":3,"name":"Git"}],"title":"iOS roles","updatedAt":"2023-11-14T22:28:20Z"}"#

private let minimalGolden = #"{"certifications":[],"createdAt":"2023-11-14T22:13:20Z","education":[],"experiences":[],"id":"11111111-1111-1111-1111-111111111111","interests":[],"languages":[],"personal":{"fullName":"A","location":"","professionalTitle":"","summary":""},"profiles":[],"revision":1,"schemaVersion":1,"skills":[],"title":"","updatedAt":"2023-11-14T22:13:20Z"}"#

private let created = Date(timeIntervalSince1970: 1_700_000_000), updated = Date(timeIntervalSince1970: 1_700_000_900)

private func stamped(_ cv: CV, revision: Int, updatedAt: Date) -> CV {
    CV(id: cv.id, revision: revision, createdAt: created, updatedAt: updatedAt, title: cv.title, personal: cv.personal,
       sections: cv.sections, design: cv.design, language: cv.language)
}

@Suite("ADR 0009 · the stored form of a CV is pinned")
struct CVFileGoldenTests {
    @Test("a CV with every field is written as exactly these bytes, and reads back as the same CV")
    func full() throws {
        let cv = stamped(FixtureCV.full(), revision: 3, updatedAt: updated)
        let data = try CVFileV1(cv, createdAt: created, updatedAt: updated).encoded()
        #expect(String(decoding: data, as: UTF8.self) == fullGolden)
        #expect(try CVFileV1.decode(Data(fullGolden.utf8)).toDomain() == cv)
    }

    @Test("a CV with nothing but a name is written as exactly these bytes, and reads back as the same CV")
    func minimal() throws {
        let cv = stamped(CV(id: FixtureCV.full().id, personal: PersonalDetails(fullName: "A")), revision: 1, updatedAt: created)
        let data = try CVFileV1(cv, createdAt: created, updatedAt: created).encoded()
        #expect(String(decoding: data, as: UTF8.self) == minimalGolden)
        #expect(try CVFileV1.decode(Data(minimalGolden.utf8)).toDomain() == cv)
    }
}
