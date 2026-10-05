import Testing
import Foundation
import PrestoCVDomain
import PrestoCVCoreTestSupport
@testable import PrestoCVPersistence

/// The full fixture in its stored form, as JSON text with its slashes unescaped, so a value can be found by its text.
private func storedFixture() throws -> String {
    let time = Date(timeIntervalSince1970: 1_700_000_000)
    let data = try CVFileV1(FixtureCV.full().stored(revision: 1, at: time), createdAt: time, updatedAt: time).encoded()
    return String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\\/", with: "/")
}

/// Every text of the stored fixture except the identifier and the timestamps, which the schema does not cap.
private func cappedTexts() throws -> [String] {
    guard var object = try JSONSerialization.jsonObject(with: Data(storedFixture().utf8)) as? [String: Any] else { return [] }
    for key in ["id", "createdAt", "updatedAt"] { object[key] = nil }
    return stringLeaves(of: object)
}

private func stringLeaves(of value: Any) -> [String] {
    switch value {
    case let text as String: return [text]
    case let object as [String: Any]: return object.values.flatMap(stringLeaves)
    case let list as [Any]: return list.flatMap(stringLeaves)
    default: return []
    }
}

@Suite("PersistedSchema · stored form")
struct StoredCVMappingTests {
    @Test("every text of a stored CV is capped, so a field added to the schema cannot escape the size check", arguments: try cappedTexts())
    func everyTextIsCapped(text: String) throws {
        let json = try storedFixture()
        let token = "\"\(text)\""
        try #require(json.components(separatedBy: token).count == 2, "the fixture holds \(token) exactly once")
        let tooLong = json.replacingOccurrences(of: token, with: "\"" + String(repeating: "x", count: CVFileV1.maxText + 1) + "\"")
        #expect(throws: CVFileV1.Invalid(reason: "size limits")) { try decode(tooLong) }
    }

    @Test("a period that ended on an unknown date is stored with a start only, and is not current")
    func unknownEnd() throws {
        let period = try #require(try Period.make(start: (2019, 4), end: nil, current: false))
        var cv = FixtureCV.full()
        var sections = cv.sections
        sections.experiences = [Experience(role: "r", company: "c", period: period)]
        cv.setSections(sections)
        let stored = CVFileV1(cv, createdAt: .distantPast, updatedAt: .distantPast).experiences[0]
        #expect(stored.start == .init(year: 2019, month: 4) && stored.end == nil && !stored.current)
    }
}
