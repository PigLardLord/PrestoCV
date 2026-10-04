import Foundation
import CVDocumentModel
import CVDesignCatalog
import CVRendering

/// The document the native renderers' contract runs print, shared by the iOS and macOS tests (R10). It exercises every
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

    /// A letter that populates every field, in the language given: what the native renderers' letter contract prints.
    public static func letter(language: String) -> LetterDocument {
        LetterDocument(
            language: language,
            sender: Person(name: "Ada Lovelace", professionalTitle: "Analyst", email: "ada@example.com", phone: "+39 06 1234567",
                           location: "Via Roma 1, 00100 Roma", website: "https://ada.example"),
            recipient: LetterRecipient(formOfAddress: .feminine, name: "Maria Rossi", familyName: "Rossi", company: "Babbage & Co",
                                       address: ["Via Milano 2", "20100 Milano"]),
            place: "Roma", date: LetterDate(year: 2026, month: 10, day: 4), reference: "REF-2026-14", subject: "Application for the position of Analyst",
            body: ["I am writing to apply for the position of Analyst at Babbage & Co.", "My CV is attached, and it tells {{title}} <b>literally</b>."],
            closing: "I am available for an interview.", name: "Ada Lovelace", attachments: ["Curriculum vitae", "Degree certificate"])
    }

    /// The same letter with as many paragraphs, address lines and attachments as a letter may have, of two lines each in
    /// the paragraphs: more than any page holds, and still a letter the validator accepts.
    public static func overlongLetter(language: String) -> LetterDocument {
        var letter = letter(language: language)
        letter.body = (1...21).map {
            "Paragraph \($0) says something about the role and about the person who applies for it, and it goes on for a second line of text."
        }
        letter.recipient.address = (1...8).map { "Address line \($0)" }
        letter.attachments = (1...20).map { "Attachment \($0)" }
        return letter
    }

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
