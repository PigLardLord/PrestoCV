import Foundation
import Testing
import PrestoCVDomain
import PrestoCVPresentation

/// The choices of the level and proficiency menus are the domain's, so that whatever the person picks can be stored; a
/// date's month and year stand in the order of the person's locale.
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

    @Test("the month comes before the year where the locale writes it so, and after it where the locale writes the year first")
    func monthAndYearInTheLocaleOrder() {
        #expect(EditorChoices.monthBeforeYear(in: Locale(identifier: "en_US")))
        #expect(EditorChoices.monthBeforeYear(in: Locale(identifier: "de_DE")))
        #expect(!EditorChoices.monthBeforeYear(in: Locale(identifier: "ja_JP")))
        #expect(!EditorChoices.monthBeforeYear(in: Locale(identifier: "hu_HU")))
    }
}
