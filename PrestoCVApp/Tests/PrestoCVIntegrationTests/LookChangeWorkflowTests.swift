import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVWorkflowPorts
@testable import PrestoCVIntegration

@Suite("Changing the look and the language of a CV")
struct LookChangeWorkflowTests {
    let repository = RepositorySpy()
    let workflow: EditCVWorkflow
    let shown = Invented.design("minimal", palette: "mono", fonts: "serif")

    init() { workflow = EditCVWorkflow(repository: repository, ids: SequentialIDGenerator()) }

    private func stored(design: DesignChoice?) async throws -> CV {
        var cv = FixtureCV.full(id: workflow.new().id)
        cv.choose(design: design)
        return try await workflow.save(cv)
    }

    @Test("only the parts the person chose change")
    func onlyChosenPartsChange() async throws {
        let saved = try await stored(design: Invented.design("modern", palette: "ocean", fonts: "classic"))

        let changed = try await workflow.changeLook(of: saved, LookChange(shown: shown, parts: [.palette]))

        #expect(changed.design == Invented.design("modern", palette: "mono", fonts: "classic"))
        #expect(try await workflow.load(saved.id) == changed)
    }

    @Test("an id of a part the app does not know stays when another part is chosen")
    func unknownIdsOfOtherPartsStay() async throws {
        let saved = try await stored(design: Invented.design("from-a-newer-app", palette: "newer-palette", fonts: "newer-fonts"))

        let changed = try await workflow.changeLook(of: saved, LookChange(shown: shown, parts: [.fonts]))

        #expect(changed.design == Invented.design("from-a-newer-app", palette: "newer-palette", fonts: "serif"))
    }

    @Test("a CV with no look takes all of the look shown")
    func noLookTakesAllShown() async throws {
        let saved = try await stored(design: nil)

        let changed = try await workflow.changeLook(of: saved, LookChange(shown: shown, parts: [.design]))

        #expect(changed.design == shown)
    }

    @Test("two changes made before either is stored give one saved look, in one write")
    func twoChangesBeforeStoreGiveOneLook() async throws {
        let saved = try await stored(design: Invented.design("modern", palette: "ocean", fonts: "classic"))
        let first = LookChange(shown: Invented.design("minimal", palette: "ocean", fonts: "classic"), parts: [.design])
        let second = LookChange(shown: Invented.design("minimal", palette: "mono", fonts: "classic"), parts: [.palette])

        let changed = try await workflow.changeLook(of: saved, first.followed(by: second))

        #expect(changed.design == Invented.design("minimal", palette: "mono", fonts: "classic"))
        #expect(changed.revision == saved.revision + 1)
        #expect(await repository.updates == 1)
    }

    @Test("a look change of a stale CV is a conflict")
    func staleLookChangeIsConflict() async throws {
        let saved = try await stored(design: nil)
        let other = try await workflow.rename(saved, to: "Other window")

        await #expect(throws: EditFailure.conflict(storedRevision: other.revision)) {
            _ = try await workflow.changeLook(of: saved, LookChange(shown: shown, parts: [.design]))
        }
    }

    @Test("the document language is stored as its tag, and cleared for automatic")
    func languageTagIsStoredAndCleared() async throws {
        let saved = try await stored(design: nil)
        let german = DocumentLanguage("de")

        let set = try await workflow.setDocumentLanguage(of: saved, to: german)
        #expect(set.language?.tag == "de" && set.revision == saved.revision + 1)

        let cleared = try await workflow.setDocumentLanguage(of: set, to: nil)
        #expect(cleared.language == nil)
        #expect(try await workflow.load(saved.id) == cleared)
    }
}
