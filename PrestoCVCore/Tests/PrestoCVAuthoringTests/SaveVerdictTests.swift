import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

@Suite("R7 · SaveCV words each verdict")
struct SaveVerdictTests {
    private let long = String(repeating: "a", count: 10_001)

    @Test("SaveCV maps each verdict to its AuthoringError, and writes nothing")
    func verdicts() async throws {
        let tooManySkills = CVSections(skills: (0..<201).map { Skill(name: "s\($0)") })
        let tooLarge = CVSections(experiences: (0..<27).map { _ in Experience(role: "", company: "", description: String(repeating: "a", count: 10_000)) })
        let cases: [(CV, AuthoringError)] = [
            (CV(id: id1), .notEnoughContent),
            (CV(id: id1, personal: PersonalDetails(summary: long)), .textTooLong(.summary)),
            (CV(id: id1, sections: tooManySkills), .tooManyEntries(.skills)),
            (CV(id: id1, sections: tooLarge), .cvTooLarge),
        ]
        for (cv, error) in cases {
            let repository = InMemoryCVRepository()
            await #expect(throws: error) { _ = try await SaveCV(repository: repository)(cv) }
            #expect(try await repository.list().cvs.isEmpty)
        }
    }

    @Test("a stored CV above the limits is refused on its next save, whatever the edit, and is never cut")
    func renameRefused() async throws {
        let repository = InMemoryCVRepository()
        let stored = try await repository.create(CV(id: id1, personal: PersonalDetails(fullName: "Ada", summary: long)))
        await #expect(throws: AuthoringError.textTooLong(.summary)) { _ = try await RenameCV(repository: repository)(stored, to: "New") }
        #expect(try await LoadCV(repository: repository)(id1).personal.summary == long)
    }
}
