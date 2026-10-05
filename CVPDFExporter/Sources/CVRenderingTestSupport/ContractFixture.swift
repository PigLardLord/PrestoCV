import Foundation
import CVDocumentModel
import CVDesignCatalog
import CVRendering

/// The document the native renderers' contract runs print, shared by the iOS and macOS tests (LSP). It exercises every
/// section: a current period and one that ended on an unknown date, a rated and an unrated skill, a native level, a
/// certification with a link, a profile, and text that must be escaped.
public enum ContractFixture {
    public static let document = CVDocument(language: "it", person: Person(
        name: "Ada <Lovelace>", professionalTitle: "Engineer", email: "ada@example.com", phone: "+39 06 1234567",
        location: "Roma", website: "https://ada.example"), sections: [
        .summary("Writes {{title}} literally & <script>alert(1)</script>"),
        .experience([ExperienceItem(role: "Analyst", company: "Babbage & Co", location: "London",
                                    period: DocumentPeriod(start: DocumentDate(year: 2019, month: 3), end: .present), description: "Line 1"),
                     ExperienceItem(role: "Clerk", company: "Old Firm", period: DocumentPeriod(start: DocumentDate(year: 2015), end: .unspecified))]),
        .education([EducationItem(degree: "Mathematics", school: "Home",
                                  period: DocumentPeriod(start: DocumentDate(year: 2010), end: .date(DocumentDate(year: 2014))), description: "Tutored")]),
        .skills([SkillItem(name: "Swift", rating: 5), SkillItem(name: "Git")]),
        .languages([LanguageItem(language: "English", level: .native), LanguageItem(language: "Italiano", level: .b2)]),
        .certifications([CertificationItem(name: "Swift Certified", issuer: "Apple", year: 2021, url: "https://cert.example/1", description: "Concurrency")]),
        .profiles([ProfileLink(platform: "GitHub", url: "https://github.com/ada")]),
        .interests(["Poetry"]),
    ])

    public static let palette = Palette(primary: HexColor("#1F3A5F")!, text: HexColor("#111111")!, background: HexColor("#FFFFFF")!)!

    /// A plain design that passes the CSS policy.
    public static func stylesheet(_ css: String = ".cv-name{color:var(--color-primary)}.cv-entry-title{font-weight:600}") throws -> ValidatedStylesheet {
        let package: [String: Any] = ["manifest": ["id": "contract", "name": "Contract", "version": "1", "description": "",
                                                    "markupContract": MarkupContract.version], "cssContent": css]
        return try DesignPackageValidator().validate(JSONSerialization.data(withJSONObject: package)).stylesheet
    }

    /// The fixture as the builder renders it: the HTML and the text nodes the PDF must contain.
    public static func rendered(css: String? = nil) throws -> RenderedDocument {
        let sheet = try css.map { try stylesheet($0) } ?? stylesheet()
        return DocumentHTMLBuilder().render(document, stylesheet: sheet, palette: palette, headings: try HeadingsCatalog.headings(for: "it"))
    }
}
