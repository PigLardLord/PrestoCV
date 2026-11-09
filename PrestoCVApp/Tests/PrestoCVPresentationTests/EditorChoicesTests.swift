import Testing
import PrestoCVDomain
import PrestoCVPresentation

/// The choices of the level and proficiency menus are the domain's, so that whatever the person picks can be stored.
@Suite("Editor choices")
struct EditorChoicesTests {

    @Test("the skill levels offered are those the domain accepts, in order")
    func levelsAreTheDomainLevels() {
        #expect(EditorChoices.skillLevels == (-10...10).filter { SkillLevel($0) != nil })
    }

    @Test("the proficiencies offered are the codes of the domain, in its order")
    func proficienciesAreTheDomainCodes() {
        #expect(EditorChoices.proficiencies == LanguageProficiency.allCases.map(\.rawValue))
    }
}
