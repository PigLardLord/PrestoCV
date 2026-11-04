import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
import enum PrestoCVDomain.CVField

/// The fields a rule of PrestoCVDomain names reach the editor's CVs: clearing one leaves the rest as they were.
@Suite("CVModel - the fields of the rules")
struct CVModelCVFieldTests {

    private static let full = CVModel(
        name: "iOS roles",
        personalInfo: PersonalInfo(name: "Ada", title: "Engineer", location: "Roma", email: "ada@example.com",
                                   phone: "+39 06 1234567", portfolio: "https://ada.example", profile: "Builds software."),
        social: [Social(platform: "GitHub", url: "https://github.com/ada")]
    )

    /// The full CV as `field` leaves it once cleared
    private static func expected(clearing field: CVField) -> CVModel {
        var cv = full
        switch field {
        case .title: cv.name = ""
        case .fullName: cv.personalInfo.name = ""
        case .professionalTitle: cv.personalInfo.title = ""
        case .email: cv.personalInfo.email = ""
        case .phone: cv.personalInfo.phone = ""
        case .location: cv.personalInfo.location = ""
        case .website: cv.personalInfo.portfolio = ""
        case .summary: cv.personalInfo.profile = ""
        case .profileLinks: cv.social[0].url = ""
        }
        return cv
    }

    @Test("each field clears its own value and nothing else", arguments: CVField.allCases)
    func clearsOneField(field: CVField) {
        #expect(Self.full.clearing([field]) == Self.expected(clearing: field))
    }

    @Test("a profile keeps its platform when its link is cleared")
    func profileKeepsPlatform() {
        let cleared = Self.full.clearing([.profileLinks])
        #expect(cleared.social.map(\.platform) == ["GitHub"])
        #expect(cleared.social.map(\.id) == Self.full.social.map(\.id))
    }

    @Test("clearing nothing changes nothing")
    func nothing() {
        #expect(Self.full.clearing([]) == Self.full)
    }
}
