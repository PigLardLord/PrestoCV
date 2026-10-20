import Testing
import Foundation
import PrestoCVDomain

@Suite("R6 · the save rule")
struct SaveRuleTests {
    @Test("a CV with nothing written cannot be saved, and white space is nothing")
    func nothingWritten() {
        #expect(!SaveRule.allowsSaving(personalDetails: [], sectionSizes: []))
        #expect(!SaveRule.allowsSaving(personalDetails: ["", " ", "\n\t"], sectionSizes: [0, 0, 0]))
    }

    @Test("any detail of the person that is written allows saving", arguments: 0..<7)
    func anyDetail(index: Int) {
        var details = Array(repeating: "", count: 7)
        details[index] = " Ada "
        #expect(SaveRule.allowsSaving(personalDetails: details, sectionSizes: [0, 0]))
    }

    @Test("an entry in any section allows saving, even one the person has only just added", arguments: 0..<7)
    func anySection(index: Int) {
        var sizes = Array(repeating: 0, count: 7)
        sizes[index] = 1
        #expect(SaveRule.allowsSaving(personalDetails: ["", ""], sectionSizes: sizes))
    }

    @Test("the CV's own title is not content: it only names the CV in the list")
    func titleIsNotContent() {
        #expect(!CV(id: id1, title: "iOS roles").canBeSaved)
    }

    @Test("a CV can be saved by any detail of its person, not only the name",
          arguments: [PersonalDetails(professionalTitle: "Engineer"), PersonalDetails(email: EmailAddress("ada@example.com")),
                      PersonalDetails(phone: PhoneNumber("+39 06 1234567")), PersonalDetails(location: "Roma"),
                      PersonalDetails(website: WebLink("https://ada.example")), PersonalDetails(summary: "Builds software.")])
    func cvByDetail(details: PersonalDetails) {
        #expect(CV(id: id1, personal: details).canBeSaved)
    }

    @Test("a CV can be saved by an entry in any section",
          arguments: [CVSections(experiences: [Experience(role: "", company: "")]), CVSections(education: [Education(degree: "", school: "")]),
                      CVSections(skills: [Skill(name: "Swift")]), CVSections(languages: [LanguageSkill(language: "Italian", proficiency: .native)]),
                      CVSections(certifications: [Certification(name: "", issuer: "")]),
                      CVSections(profiles: [ProfileLink(platform: "GitHub", link: WebLink("https://github.com/ada")!)]),
                      CVSections(interests: ["Chess"])])
    func cvBySection(sections: CVSections) {
        #expect(CV(id: id1, sections: sections).canBeSaved)
    }
}
