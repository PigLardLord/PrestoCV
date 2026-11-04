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
        /// Texts that a design printed in the order of its page reads one whole after the other, in this order: a title
        /// with the items under it. Empty when the CV has none to check.
        var runs: [String] = []
    }

    /// The languages of the CV, with the level as the English documents print it
    private static let languages = [
        ("Italian", LanguageProficiencyLevel.native, "Native"), ("English", .c2, "C2"), ("French", .b1, "B1"),
        ("Spanish", .a2, "A2"), ("German", .a1, "A1"), ("Portuguese", .a1, "A1")
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

    /// The lists at the foot of a CV, and what a test looks for in them: `markers` are texts that must be in the PDF, and
    /// `runs` are the lists as a reader goes through them, each with its title
    private static func lists(languages languageCount: Int, profiles profileCount: Int, interests interestCount: Int)
        -> (languages: [Language], profiles: [Social], interests: [String], markers: [String], runs: [String]) {
        let chosen = languages.prefix(languageCount)
        let chosenProfiles = profiles.prefix(profileCount)
        let chosenInterests = interests.prefix(interestCount)
        let runs = [
            (["Languages"] + chosen.flatMap { [$0.0, $0.2] }).joined(separator: " "),
            (["Profiles"] + chosenProfiles.flatMap { [$0.platform, $0.url] }).joined(separator: " "),
            (["Interests"] + chosenInterests).joined(separator: " ")
        ]
        return (chosen.map { Language(name: $0.0, level: $0.1) }, Array(chosenProfiles), Array(chosenInterests),
                chosen.map(\.0) + chosenProfiles.map(\.url) + chosenInterests, runs)
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
        return Short(label: cv.name, cv: cv, markers: markers, runs: trailing.runs)
    }()

    /// A CV with a few lists and a first job of `lines` lines. For a design that sets its small lists in a sidebar, the main
    /// column is what decides the page: a first job of the right length takes two pages whatever the tightening, and one page
    /// with the compact step. The designs that set the lists under the text take two pages for it, whatever the step.
    static func longFirstJob(lines: Int) -> Short {
        var cv = trailingLists.cv
        cv.name = "long-first-job-\(lines)"
        cv.relevant_experience[0].description = responsibilities(lines)
        return Short(label: cv.name, cv: cv, markers: trailingLists.markers + ["Responsibility number \(lines) on the ward"])
    }

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
