import CVDocumentModel

/// The document `FixtureRenderingGate` prints to prove a design before it is stored, and the native renderers' contract runs
/// print (R10). It exercises every section: a current period and one that ended on an unknown date, a rated and an unrated
/// skill, a native level, a certification with a link, a profile, and text that must be escaped.
///
/// The bundled designs are proven against this document on both renderers, so it stays as it is: a change means running
/// the gate again on both. It is in Italian, and its headings are read in its own language; its text is never shown.
public enum GateFixture {
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
}
