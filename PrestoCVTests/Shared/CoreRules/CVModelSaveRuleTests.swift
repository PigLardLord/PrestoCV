import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// The editor's CVs are judged by the save rule of PrestoCVDomain: each of their fields reaches it.
@Suite("CVModel - the save rule")
struct CVModelSaveRuleTests {

    @Test("a CV with only its own name has nothing to save")
    func nameOnly() {
        #expect(!CVModel(name: "iOS roles").allowsSaving)
        #expect(!CVModel(personalInfo: PersonalInfo(name: " ", title: "\n")).allowsSaving)
    }

    @Test("every detail of the person counts", arguments: [
        PersonalInfo(name: "Ada"), PersonalInfo(title: "Engineer"), PersonalInfo(location: "Roma"), PersonalInfo(email: "ada@example.com"),
        PersonalInfo(phone: "+39 06 1234567"), PersonalInfo(portfolio: "https://ada.example"), PersonalInfo(profile: "Builds software."),
    ])
    func personalDetail(info: PersonalInfo) {
        #expect(CVModel(personalInfo: info).allowsSaving)
    }

    @Test("an entry in every section counts, even an empty one", arguments: [
        CVModel(relevant_experience: [Experience()]), CVModel(education: [Education()]), CVModel(skills: [Skill()]),
        CVModel(languages: [Language()]), CVModel(certifications: [Certification()]), CVModel(interests: [""]), CVModel(social: [Social()]),
    ])
    func sectionEntry(cv: CVModel) {
        #expect(cv.allowsSaving)
    }
}
