import Testing
import PrestoCVDomain
@testable import PrestoCVPersistence

@Suite("PersistedSchema · quarantined names")
struct QuarantinedNameTests {
    @Test("a quarantined name is a stored file name, with the prefix of an earlier copy when there is one")
    func parsesStoredAndPrefixedNames() throws {
        let plain = try #require(QuarantinedName(fileName(id1)))
        let copy = try #require(QuarantinedName("12~" + fileName(id1)))
        #expect(plain.value == fileName(id1) && plain.storedName == fileName(id1) && plain.id == id1)
        #expect(copy.value == "12~" + fileName(id1) && copy.storedName == fileName(id1) && copy.id == id1)
    }

    @Test("anything that is not a stored file name with an optional prefix of ASCII digits is refused",
          arguments: ["", "x.cv.json", "x" + fileName(id1), "\u{0661}~" + fileName(id1), "\u{FF11}~" + fileName(id1), "../" + fileName(id1), "a~" + fileName(id1), "1~2~" + fileName(id1), "~" + fileName(id1),
                      fileName(id1) + "\n", "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa.cv.json", "1~" + fileName(id1) + ".bak", "\(id1.raw.uuidString).json"])
    func refusesOtherNames(name: String) {
        #expect(QuarantinedName(name) == nil)
    }

    @Test("a copy is the stored name itself or the stored name with a prefix, and nothing else")
    func copies() {
        let name = fileName(id1)
        #expect(QuarantinedName.isCopy(name, of: name) && QuarantinedName.isCopy("3~" + name, of: name))
        #expect(!QuarantinedName.isCopy(fileName(id2), of: name) && !QuarantinedName.isCopy("3~" + fileName(id2), of: name))
        #expect(!QuarantinedName.isCopy("x" + name, of: name), "a prefix without its tilde is not a copy")
    }
}
