import Foundation
import PrestoCVApplication
import PrestoCVDomain
import PrestoCVImporting
import PrestoCVImportingTestSupport

/// An id the test names.
struct FixedID: IDGenerator {
    let id: CVID
    init(_ last: Int = 1) {
        guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-" + String(format: "%012d", last)) else { preconditionFailure("uuid") }
        id = CVID(uuid)
    }
    func next() -> CVID { id }
}

func link(_ raw: String) -> WebLink {
    guard let link = WebLink(raw) else { preconditionFailure("link: \(raw)") }
    return link
}

func yearMonth(_ year: Int, _ month: Int? = nil) -> YearMonth { YearMonth(year: year, month: month) }

/// An import that fills every field of `ImportedCV`, of an invented person. Every value is quoted from `text` and no
/// value repeats, so a value found in the CV can only come from its own field.
enum FullImport {
    static let text = """
    Mira Valdez
    Platform Engineer
    mira.valdez@example.org
    +49 30 5550123
    Lisbon, Portugal
    linkedin.com/in/miravaldez
    github.com/miravaldez
    xing.com/profile/Mira_Valdez
    https://miravaldez.example.org
    Summary
    Builds reliable platforms for small teams.
    Experience
    Staff Engineer
    Northwind Labs
    Hamburg, Germany
    03/2019 - 05/2021
    Led the migration to containers
    Cut build times by half
    Junior Developer
    Tailspin Works
    2015 -
    Wrote internal tools
    Education
    MSc Computer Science
    Technical University of Aveiro
    Aveiro, Portugal
    2012 - 2014
    Thesis on distributed caches
    Skills
    Go, Kubernetes
    Languages
    Portuguese native
    English B2
    Spanish fluent
    Certifications
    Certified Kubernetes Administrator, Linux Foundation, 2017
    https://training.example.org/cka
    Renewed after a hands-on exam in a live cluster.
    Interests
    Chess
    Volunteering at the harbour clean-up.
    Contact
    https://blog.miravaldez.example.org
    """

    static let fixture = ImportFixture(text: text)

    static var result: ImportResult {
        let f = fixture
        var cv = ImportedCV()
        cv.person.name = f.quoted("Mira Valdez", check: .nameByPosition)
        cv.person.title = f.quoted("Platform Engineer", check: .titleByPosition)
        cv.person.email = f.sourced(EmailAddress("mira.valdez@example.org")!, quoting: "mira.valdez@example.org")
        cv.person.phone = f.sourced(PhoneNumber("+49 30 5550123")!, quoting: "+49 30 5550123")
        cv.person.location = f.quoted("Lisbon, Portugal", check: .locationByPosition)
        cv.person.links = [
            f.link(.linkedIn, f.sourced(link("https://linkedin.com/in/miravaldez"), quoting: "linkedin.com/in/miravaldez", reading: .webAddress)),
            f.link(.gitHub, f.sourced(link("https://github.com/miravaldez"), quoting: "github.com/miravaldez", reading: .webAddress)),
            f.link(.xing, f.sourced(link("https://xing.com/profile/Mira_Valdez"), quoting: "xing.com/profile/Mira_Valdez", reading: .webAddress)),
            f.link(.website, f.sourced(link("https://miravaldez.example.org"), quoting: "https://miravaldez.example.org")),
            f.link(.website, f.sourced(link("https://blog.miravaldez.example.org"), quoting: "https://blog.miravaldez.example.org"),
                   heading: "Contact"),
        ]
        cv.person.summary = f.quoted("Builds reliable platforms for small teams.", check: .summaryWithoutHeading)
        cv.experience = [
            f.experience(
                role: f.quoted("Staff Engineer"), employer: f.quoted("Northwind Labs"), location: f.quoted("Hamburg, Germany"),
                period: f.sourced(ImportedPeriod(start: yearMonth(2019, 3), end: .date(yearMonth(2021, 5))), quoting: "03/2019 - 05/2021", reading: .period),
                details: [f.quoted("Led the migration to containers"), f.quoted("Cut build times by half")], check: .entryBoundsUnsure),
            f.experience(
                role: f.quoted("Junior Developer"), employer: f.quoted("Tailspin Works"),
                period: f.sourced(ImportedPeriod(start: yearMonth(2015), end: .unstated), quoting: "2015 -", reading: .period, check: .periodOpenEnd),
                details: [f.quoted("Wrote internal tools")], check: .roleOrEmployerByOrder),
        ]
        cv.education = [
            f.education(
                degree: f.quoted("MSc Computer Science"), school: f.quoted("Technical University of Aveiro"),
                location: f.quoted("Aveiro, Portugal"),
                period: f.sourced(ImportedPeriod(start: yearMonth(2012), end: .date(yearMonth(2014))), quoting: "2012 - 2014", reading: .period),
                details: [f.quoted("Thesis on distributed caches")], check: .locationByPosition, heading: "Education"),
        ]
        cv.skills = [f.quoted("Go"), f.quoted("Kubernetes")]
        cv.languages = [
            f.language(f.quoted("Portuguese"), level: f.sourced(.native, quoting: "native", reading: .languageLevel), heading: "Languages"),
            f.language(f.quoted("English"), level: f.sourced(.b2, quoting: "B2", reading: .languageLevel), heading: "Languages"),
            f.language(f.sourced("Spanish", quoting: "Spanish"), levelWords: f.quoted("fluent", check: .levelNotCEFR), heading: "Languages"),
        ]
        cv.certifications = [
            f.certification(f.quoted("Certified Kubernetes Administrator"), issuer: f.quoted("Linux Foundation"),
                            year: f.sourced(2017, quoting: "2017", reading: .year),
                            link: f.sourced(link("https://training.example.org/cka"), quoting: "https://training.example.org/cka"),
                            description: f.quoted("Renewed after a hands-on exam in a live cluster.")),
        ]
        cv.interests = [f.quoted("Chess")]
        return f.result(cv, language: .en, unplaced: [f.unplaced("Volunteering at the harbour clean-up.")])
    }
}
