import Foundation
@testable import PrestoCVCore

/// Invented CVs of a known size around one page, to find where the designs put the page break of a CV that runs a
/// little over one page, and of one that runs far over. Both are built on the English nurse of `EverydayCVs`.
///
/// Their sizes were chosen on iOS 26.5 and iOS 27.0 so that none sits on the edge of fitting: a CV that fits with 99%
/// of the page used on one system takes two pages on the other.
enum ShortCVs {

    /// A CV, with texts from its first and its last sections that must be in the PDF whatever the pagination
    struct Short {
        let label: String
        let cv: CVModel
        let markers: [String]
    }

    private static let languages = [
        ("Italian", LanguageProficiencyLevel.native), ("English", .c2), ("French", .b1), ("Spanish", .a2), ("German", .a1), ("Portuguese", .a1)
    ]
    private static let profiles = [
        Social(platform: "LinkedIn", url: "linkedin.com/in/saraconti"), Social(platform: "GitHub", url: "github.com/saraconti"),
        Social(platform: "Portfolio", url: "saraconti.example.com")
    ]
    private static let interests = ["Running", "Photography", "Chess", "Cooking", "Hiking", "Painting", "Gardening", "Reading"]

    /// The first lines of the first job: `count` short sentences, one to a line
    private static func responsibilities(_ count: Int) -> String {
        (0..<count).map { "- Responsibility number \($0 + 1) on the ward" }.joined(separator: "\n")
    }

    /// The lists at the foot of a CV, and what a test looks for in them
    private static func lists(languages languageCount: Int, profiles profileCount: Int, interests interestCount: Int) -> (languages: [Language], profiles: [Social], interests: [String], markers: [String]) {
        let chosen = languages.prefix(languageCount)
        return (chosen.map { Language(name: $0.0, level: $0.1) }, Array(profiles.prefix(profileCount)), Array(interests.prefix(interestCount)),
                chosen.map(\.0) + profiles.prefix(profileCount).map(\.url) + interests.prefix(interestCount))
    }

    /// The case of the product review of 2026-10-16: a short CV whose experience and education fill four fifths of its
    /// first page. The languages do not fit in what is left, and go whole to a second page with the profiles and the
    /// interests, so the first page ends a fifth empty and the second holds a few lists. Tightening the spacing a little
    /// is not enough to bring them back.
    static let trailingLists: Short = {
        var cv = EverydayCVs.nurseEnglish()
        cv.name = "trailing-lists"
        cv.personalInfo.profile = "Registered nurse with 4 years of experience on acute medical and surgical wards."
        cv.relevant_experience[0].description = responsibilities(1)
        cv.relevant_experience[1].description = ""
        cv.skills = ["Medication administration", "IV therapy", "Wound care", "Patient assessment", "Electronic records"].map { Skill(name: $0) }
        let trailing = lists(languages: 6, profiles: 3, interests: 8)
        cv.languages = trailing.languages
        cv.social = trailing.profiles
        cv.interests = trailing.interests
        let markers = ["Registered nurse with 4 years", "Southmead Hospital", "NMC Registered Nurse (Adult)"] + trailing.markers
        return Short(label: cv.name, cv: cv, markers: markers)
    }()

    /// A CV of two pages that no step brings onto one: a long first job and a few lists. A design prints it as it lays itself out.
    static let tooLongForOnePage: Short = {
        var cv = EverydayCVs.nurseEnglish()
        cv.name = "too-long"
        cv.relevant_experience[0].description += "\n" + responsibilities(22)
        let trailing = lists(languages: 2, profiles: 1, interests: 3)
        cv.languages = trailing.languages
        cv.social = trailing.profiles
        cv.interests = trailing.interests
        let markers = ["Registered nurse with 4 years", "Responsibility number 22 on the ward"] + trailing.markers
        return Short(label: cv.name, cv: cv, markers: markers)
    }()
}
