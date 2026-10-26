import Testing
@testable import PrestoCVCore

@Suite("Skill level Tests - the stars a skill is rated with")
struct SkillLevelTests {

    @Test("A skill is rated with up to five stars")
    func skillsAreRatedUpToFiveStars() {
        #expect(Skill.maxLevel == 5)
    }

    @Test("Tapping a star rates the skill with it", arguments: [(0, 3), (3, 5), (5, 1), (2, 3)])
    func tappingAStarRatesTheSkill(level: Int, star: Int) {
        var skill = Skill(name: "Swift", level: level)

        skill.chooseLevel(star)

        #expect(skill.level == star)
    }

    @Test("Tapping the star of the rating again takes the rating away", arguments: [1, 3, 5])
    func tappingTheSameStarClearsTheRating(level: Int) {
        var skill = Skill(name: "Swift", level: level)

        skill.chooseLevel(level)

        #expect(skill.level == 0)
    }
}
