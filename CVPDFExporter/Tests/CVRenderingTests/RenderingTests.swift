import Testing
import Foundation
import CVDocumentModel
import CVDesignCatalog
@testable import CVRendering
import CVRenderingTestSupport
import CVBundledHeadings

let cleanCSS = ".cv-name{color:var(--color-primary)}.cv-entry-title{font-weight:600}.cv-section-title{text-transform:uppercase}"

func designData(_ css: String, id: String = "clean") -> Data {
    let object: [String: Any] = ["manifest": ["id": id, "name": "Clean", "version": "1.0.0", "description": "", "defaultPalette": "ink",
                                              "defaultFonts": "system", "markupContract": 1], "cssContent": css]
    return try! JSONSerialization.data(withJSONObject: object)   // test fixture only
}

func stylesheet(_ css: String = cleanCSS) throws -> ValidatedStylesheet {
    try DesignPackageValidator().validate(designData(css)).stylesheet
}

let palette = Palette(primary: HexColor("#1F3A5F")!, text: HexColor("#111111")!, background: HexColor("#FFFFFF")!)!

/// The heading tables the package ships, read through the bundled adapter (ADR 0026).
let headingsCatalog = HeadingsCatalog(source: BundleHeadingTableSource())

let fixture = CVDocument(language: "it", person: Person(name: "Ada <Lovelace>", professionalTitle: "Engineer", email: "ada@example.com",
                                                        phone: "+39 06 1234567", location: "Roma", website: "https://ada.example"), sections: [
    .summary("Writes {{title}} literally & <script>alert(1)</script>"),
    .experience([ExperienceItem(role: "Analyst", company: "Babbage & Co", location: "London", period: DocumentPeriod(start: DocumentDate(year: 2019, month: 3), end: .present), description: "Line 1"),
                 ExperienceItem(role: "Clerk", company: "Old Firm", period: DocumentPeriod(start: DocumentDate(year: 2015), end: .unspecified))]),
    .education([EducationItem(degree: "Mathematics", school: "Home", period: DocumentPeriod(start: DocumentDate(year: 2010), end: .date(DocumentDate(year: 2014))),
                              description: "Tutored")]),
    .skills([SkillItem(name: "Swift", rating: 5), SkillItem(name: "Git")]),
    .languages([LanguageItem(language: "English", level: .native), LanguageItem(language: "Italiano", level: .b2)]),
    .certifications([CertificationItem(name: "Swift Certified", issuer: "Apple", year: 2021, url: "https://cert.example/1", description: "Concurrency")]),
    .profiles([ProfileLink(platform: "GitHub", url: "https://github.com/ada"), ProfileLink(platform: "Evil", url: "javascript:alert(1)")]),
    .interests(["Poetry"]),
])

@Suite("ADR 0011 · typed HTML builder")
struct BuilderTests {
    @Test("every field lands in its own section; no parent-context leak (#2)")
    func fieldsInPlace() throws {
        let html = DocumentHTMLBuilder().build(fixture, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "it"))
        #expect(html.contains(#"<p class="cv-entry-subtitle">Babbage &amp; Co</p>"#))
        #expect(html.contains(#"<h3 class="cv-entry-title">Mathematics</h3>"#))
        #expect(html.contains(#"<p class="cv-entry-subtitle">Home</p>"#))
        #expect(html.components(separatedBy: "Engineer").count == 2)        // title printed once, in the header only
        #expect(html.contains(#"<span class="cv-skill" data-rating="5">Swift</span>"#))
        #expect(html.contains(#"<span class="cv-skill">Git</span>"#))         // no bare "0" rating (#21)
    }

    @Test("an entry prints what it has: a blank title, subtitle or issuer leaves no empty element")
    func blankEntryPartsAreOmitted() throws {
        let doc = CVDocument(language: "en", person: Person(name: "A"), sections: [
            .experience([ExperienceItem(role: "", company: "Co"), ExperienceItem(role: "Dev", company: "")]),
            .education([EducationItem(degree: "", school: "School"), EducationItem(degree: "Degree", school: "")]),
            .certifications([CertificationItem(name: "Cert", issuer: "")]),
        ])
        let html = DocumentHTMLBuilder().build(doc, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "en"))
        #expect(!html.contains("></h3>"))
        #expect(!html.contains("></p>"))
        #expect(html.contains(#"<h3 class="cv-entry-title">Dev</h3>"#))
        #expect(html.contains(#"<p class="cv-entry-subtitle">School</p>"#))
    }

    @Test("the person's line breaks reach the page: one paragraph per line in the summary and in every description (#21)")
    func lineBreaksArePreserved() throws {
        let doc = CVDocument(language: "en", person: Person(name: "A"), sections: [
            .summary("Summary one\nSummary two"),
            .experience([ExperienceItem(role: "Dev", company: "Co", description: "- led a team\n- shipped X\n\n  \n- fixed Y")]),
            .education([EducationItem(degree: "D", school: "S", description: "Thesis\nHonours")]),
            .certifications([CertificationItem(name: "C", issuer: "I", description: "Part one\nPart two")]),
        ])
        let rendered = DocumentHTMLBuilder().render(doc, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "en"))
        let html = rendered.html
        #expect(html.contains(#"<p class="cv-summary">Summary one</p><p class="cv-summary">Summary two</p>"#))
        #expect(html.contains(#"<p class="cv-entry-description">- led a team</p><p class="cv-entry-description">- shipped X</p><p class="cv-entry-description">- fixed Y</p>"#))
        #expect(html.contains(#"<p class="cv-entry-description">Thesis</p><p class="cv-entry-description">Honours</p>"#))
        #expect(html.contains(#"<p class="cv-entry-description">Part one</p><p class="cv-entry-description">Part two</p>"#))
        #expect(!html.contains("\n"))
        #expect(rendered.textNodes.contains("Summary two"))
        #expect(!rendered.textNodes.contains { $0.contains("\n") })
    }

    @Test("user text is escaped and never re-parsed as template syntax (#21, R8)")
    func escaping() throws {
        let html = DocumentHTMLBuilder().build(fixture, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "it"))
        #expect(html.contains("Writes {{title}} literally &amp; &lt;script&gt;alert(1)&lt;/script&gt;"))
        #expect(!html.contains("<script>"))
        #expect(html.contains("Ada &lt;Lovelace&gt;"))
    }

    @Test("links that could mislead or execute are dropped (R8, security S1)", arguments: [
        "javascript:alert(1)", "JaVaScRiPt:alert(1)", " javascript:alert(1)", "java\tscript:alert(1)",
        "data:text/html,<script>", "vbscript:x", "https://ok.example/ with space", "//evil.example",
        "https://linkedin.com@example.org/", "http://@example.org", "https://аpple.com/", "https://example.org/\u{202E}fdp.exe",
        "https://example.org/\u{00A0}", "https:\\\\example.org\\x", "https://example.org/" + String(repeating: "a", count: 3000),
        "mailto:ada@example.com?bcc=all@example.org", "https:javascript:alert(1)", "https://example.org:8443/",
    ])
    func linkSchemes(url: String) throws {
        let doc = CVDocument(language: "en", person: Person(name: "A"), sections: [.profiles([ProfileLink(platform: "P", url: url)])])
        let html = DocumentHTMLBuilder().build(doc, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "en"))
        #expect(!html.contains("<a "))
    }

    @Test("safe links are kept in their parsed form", arguments: [
        "https://github.com/ada", "mailto:ada@example.com", "tel:+39-06-1234567", "http://example.org/path?q=1",
    ])
    func safeLinks(url: String) throws {
        let doc = CVDocument(language: "en", person: Person(name: "A"), sections: [.profiles([ProfileLink(platform: "P", url: url)])])
        let html = DocumentHTMLBuilder().build(doc, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "en"))
        #expect(startTags(in: html).contains { $0.name == "a" && $0.attributes["href"] == url })
    }

    @Test("a quote followed by a combining mark cannot break out of an attribute (review finding 1)")
    func combiningMarkAttributeInjection() throws {
        let hostile = "x\"\u{0301} onload=alert(1) y=\""
        let tag = startTags(in: HTML.element(.a, attributes: [(.href, hostile)], children: [.text("t")]).rendered).first
        #expect(tag.map { Set($0.attributes.keys) } == ["href"])
        #expect(tag?.attributes["href"]?.contains("onload") == true)   // the payload stays inside the value
    }

    @Test("an invalid language tag becomes 'und' instead of reaching an attribute")
    func languageTag() throws {
        let doc = CVDocument(language: "en\" onload=\"x", person: Person(name: "A"), sections: [])
        let html = DocumentHTMLBuilder().build(doc, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "en"))
        #expect(html.contains(#"<html lang="und">"#))
    }

    @Test("headings and dates follow the document language, not the device (R13)")
    func headings() throws {
        let it = DocumentHTMLBuilder().build(fixture, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: fixture.language))
        #expect(it.contains(#"<html lang="it">"#))
        #expect(it.contains("Esperienza professionale"))
        #expect(it.contains("03/2019 – Oggi"))
        #expect(it.contains("2010 – 2014"))
        #expect(it.contains("Madrelingua"))
        #expect(try headingsCatalog.headings(for: "en-GB").experience == "Work experience")
    }

    @Test("an ended period with no end date is never printed as current (review: H1)")
    func unspecifiedEnd() throws {
        let html = DocumentHTMLBuilder().build(fixture, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "it"))
        #expect(html.contains(#"<p class="cv-entry-period">2015</p>"#))
        #expect(!html.contains("2015 – Oggi"))
    }

    @Test("unsupported languages are an error, never English; matching uses the whole primary subtag", arguments: ["ja", "fil", "fi", "e", "en_GB", "en-\n"])
    func unsupportedLanguage(tag: String) {
        #expect(throws: HeadingsCatalog.Failure.self) { _ = try headingsCatalog.headings(for: tag) }
    }

    @Test("every supported language has a complete heading table")
    func headingTablesComplete() throws {
        let languages = try headingsCatalog.supportedLanguages()
        #expect(languages == ["en", "it", "de", "es", "fr", "pt"])
        for tag in languages {
            _ = try headingsCatalog.headings(for: tag)
            let table = try #require(try headingsCatalog.table(tag))
            #expect(Set(table.keys) == Set(HeadingsCatalog.keys), "\(tag) has unknown or missing keys")
        }
    }

    @Test("a regional tag uses its language's table (#81)",
          arguments: [("de-CH", "Berufserfahrung"), ("es-419", "Experiencia laboral"), ("fr-CA", "Expérience professionnelle"),
                      ("pt-BR", "Experiência profissional"), ("pt-PT", "Experiência profissional")])
    func regionalTags(tag: String, experience: String) throws {
        #expect(try headingsCatalog.headings(for: tag).experience == experience)
    }

    @Test("a document in each new language prints its own headings, period end and native level (#81)",
          arguments: [("de", "Berufserfahrung", "Heute", "Muttersprache"), ("es", "Experiencia laboral", "Actualidad", "Lengua materna"),
                      ("fr", "Expérience professionnelle", "Aujourd’hui", "Langue maternelle"), ("pt", "Experiência profissional", "Presente", "Língua materna")])
    func newLanguages(tag: String, experience: String, present: String, native: String) throws {
        let doc = CVDocument(language: tag, person: fixture.person, sections: fixture.sections)
        let html = DocumentHTMLBuilder().build(doc, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: tag))
        #expect(html.contains(#"<html lang="\#(tag)">"#))
        #expect(html.contains(#"<h2 class="cv-section-title">\#(experience)</h2>"#))
        #expect(html.contains("03/2019 – \(present)"))
        #expect(html.contains(#"<span class="cv-language-level">\#(native)</span>"#))
    }

    /// Golden test (R10): the committed file is the reviewed output. To change it on purpose, set
    /// UPDATE_GOLDEN=1, run once, and review the diff of Golden/fixture-it.html like code.
    @Test("golden output: the fixture renders exactly to the reviewed HTML")
    func golden() throws {
        let html = DocumentHTMLBuilder().build(fixture, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "it"))
        try GoldenFile.updateIfRequested("fixture-it.html", with: html)
        let url = try #require(Bundle.module.url(forResource: "Golden/fixture-it", withExtension: "html"))
        #expect(html == (try String(contentsOf: url, encoding: .utf8)))
    }

    @Test("contact fields, certifications and links are rendered in their contract classes; links print their destination")
    func contactAndCertifications() throws {
        let html = DocumentHTMLBuilder().build(fixture, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "it"))
        for needle in [#"<p class="cv-phone">+39 06 1234567</p>"#, #"<p class="cv-location">Roma</p>"#, #"<a class="cv-website" href="https://ada.example">https://ada.example</a>"#,
                       #"<section class="cv-section" data-section="certifications"><h2 class="cv-section-title">Certificazioni</h2>"#,
                       #"<h3 class="cv-entry-title">Swift Certified</h3><p class="cv-entry-subtitle">Apple</p><p class="cv-entry-period">2021</p>"#,
                       #"<a class="cv-entry-link" href="https://cert.example/1">https://cert.example/1</a>"#,
                       #"<a class="cv-profile" href="https://github.com/ada"><span class="cv-profile-platform">GitHub</span> <span class="cv-profile-url">https://github.com/ada</span></a>"#] {
            #expect(html.contains(needle), "\(needle)")
        }
    }

    @Test("completeness counts occurrences: repeated, contained and duplicated values, and dates")
    func completenessOccurrences() throws {
        let doc = CVDocument(language: "en", person: Person(name: "Ada"), sections: [
            .summary("I write Swift every day"),
            .experience([ExperienceItem(role: "Dev", company: "A", period: DocumentPeriod(start: DocumentDate(year: 2019), end: .present)),
                         ExperienceItem(role: "Dev", company: "A", period: DocumentPeriod(start: DocumentDate(year: 2015), end: .date(DocumentDate(year: 2018))))]),
            .skills([SkillItem(name: "Swift"), SkillItem(name: "Git")]),
        ])
        let rendered = DocumentHTMLBuilder().render(doc, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "en"))
        let full = rendered.textNodes.joined(separator: "\n")
        #expect(DocumentCompleteness.missing(in: full.uppercased(), expected: rendered.textNodes).isEmpty)          // case-insensitive
        // The Swift skill removed: "Swift" still appears in the summary, but one occurrence is missing.
        #expect(DocumentCompleteness.missing(in: full.replacingOccurrences(of: "\nSwift\n", with: "\n"), expected: rendered.textNodes) == ["Swift"])
        // One of two identical "Dev" entries removed.
        let oneDev = full.replacingOccurrences(of: "Dev\nA\n2015 – 2018", with: "")
        #expect(!DocumentCompleteness.missing(in: oneDev, expected: rendered.textNodes).isEmpty)
        // Every date removed.
        let noDates = full.replacingOccurrences(of: "2019 – Present", with: "").replacingOccurrences(of: "2015 – 2018", with: "")
        #expect(Set(DocumentCompleteness.missing(in: noDates, expected: rendered.textNodes)) == ["2019 – Present", "2015 – 2018"])
    }

    @Test("a field made of the end of one value and the start of the next does not count (final gate)")
    func completenessDistinctSpans() {
        #expect(DocumentCompleteness.missing(in: "Greg\nOfficer\nSkills", expected: ["Greg", "Officer", "Skills", "Go"]) == ["Go"])
        #expect(DocumentCompleteness.missing(in: "Greg\nOfficer\nSkills\nGo", expected: ["Greg", "Officer", "Skills", "Go"]).isEmpty)
        #expect(DocumentCompleteness.missing(in: "Dev A Dev", expected: ["Dev", "A", "Dev"]).isEmpty)
        #expect(DocumentCompleteness.missing(in: "Dev A", expected: ["Dev", "A", "Dev"]) == ["Dev"])
    }

    @Test("an intact document is complete even when one value runs into the next (final gate, delta)")
    func completenessNoFalseAlarm() {
        #expect(DocumentCompleteness.missing(in: "Ann\nAnna", expected: ["Ann", "Anna"]).isEmpty)
        #expect(DocumentCompleteness.missing(in: "Anna\nAnn", expected: ["Ann", "Anna"]).isEmpty)
        #expect(DocumentCompleteness.missing(in: "ababa", expected: ["aba", "ab"]).isEmpty)        // needs backtracking
        #expect(DocumentCompleteness.missing(in: "Ann", expected: ["Ann", "Anna"]) == ["Anna"])
        // Repeated values must not turn the search factorial (final gate, delta 2).
        let nodes = ["Anna", "An Naan"] + Array(repeating: "Paris", count: 9)
        #expect(DocumentCompleteness.missing(in: nodes.joined(separator: "\n"), expected: nodes).isEmpty)
        let many = ["Anna", "An Naan"] + Array(repeating: "Paris", count: 60) + Array(repeating: "Go", count: 40)
        #expect(DocumentCompleteness.missing(in: many.joined(separator: "\n"), expected: many).isEmpty)
        #expect(DocumentCompleteness.missing(in: many.dropLast().joined(separator: "\n"), expected: many) == ["Go"])
        // Overlapping repeated values with no whitespace between fields (fix check).
        let overlapping = Array(repeating: "aba", count: 15) + Array(repeating: "ab", count: 15)
        #expect(DocumentCompleteness.missing(in: String(repeating: "ababa", count: 15), expected: overlapping).isEmpty)
        #expect(!DocumentCompleteness.missing(in: String(repeating: "ababa", count: 14) + "abab", expected: overlapping).isEmpty)
    }

    @Test("an experience's location and an education's description are rendered (final gate)")
    func locationAndEducationDescription() throws {
        let html = DocumentHTMLBuilder().build(fixture, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "it"))
        #expect(html.contains(#"<p class="cv-entry-subtitle">Babbage &amp; Co</p><p class="cv-entry-location">London</p>"#))
        #expect(html.contains(#"<p class="cv-entry-description">Tutored</p>"#))
    }

    @Test("inline entries and a profile's parts are separated, so printed text never runs together")
    func inlineSeparators() throws {
        let doc = CVDocument(language: "en", person: Person(name: "Ada"), sections: [
            .skills([SkillItem(name: "Swift"), SkillItem(name: "Git")]),
            .profiles([ProfileLink(platform: "GitHub", url: "https://github.com/ada"), ProfileLink(platform: "LinkedIn", url: "https://linkedin.com/in/ada")]),
            .interests(["Chess", "Running"]),
        ])
        let rendered = DocumentHTMLBuilder().render(doc, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "en"))
        let body = String(rendered.html[rendered.html.range(of: "<body>")!.upperBound...])
        let visible = body.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for phrase in ["Swift Git", "GitHub https://github.com/ada LinkedIn https://linkedin.com/in/ada", "Chess Running"] {
            #expect(visible.contains(phrase), "\(phrase)")
        }
        #expect(!rendered.textNodes.contains { $0.allSatisfy(\.isWhitespace) })            // separators are not fields
    }

    @Test("a PDF that keeps link labels but loses their destinations is incomplete")
    func completenessLinkDestinations() throws {
        let rendered = DocumentHTMLBuilder().render(fixture, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "it"))
        let full = rendered.textNodes.joined(separator: "\n")
        #expect(DocumentCompleteness.missing(in: full, expected: rendered.textNodes).isEmpty)
        let noDestinations = ["https://ada.example", "https://cert.example/1", "https://github.com/ada"]
            .reduce(full) { $0.replacingOccurrences(of: $1, with: "") }
        // Occurrences count substrings too, so "GitHub" and "Git" inside the removed URL are reported as well.
        #expect(Set(DocumentCompleteness.missing(in: noDestinations, expected: rendered.textNodes)).isSuperset(of: ["https://ada.example", "https://cert.example/1", "https://github.com/ada"]))
    }
}

@Suite("ADR 0002 · CVDocument is a JSON contract")
struct DocumentContractTests {
    @Test("sections carry an explicit kind; round trip is lossless")
    func roundTrip() throws {
        let data = try JSONEncoder().encode(fixture)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains(#""kind":"summary""#) && !json.contains("_0"))
        #expect(try JSONDecoder().decode(CVDocument.self, from: data) == fixture)
    }
    @Test("an unknown schema version is rejected")
    func version() {
        let json = #"{"schemaVersion":99,"language":"en","person":{"name":"A"},"sections":[]}"#
        #expect(throws: DecodingError.self) { _ = try JSONDecoder().decode(CVDocument.self, from: Data(json.utf8)) }
    }
    @Test("the validator rejects what a backend must not accept", arguments: [
        CVDocument(language: "en", person: Person(name: " "), sections: []),
        CVDocument(language: "en", person: Person(name: "A"), sections: [.skills([SkillItem(name: "x", rating: 9)])]),
        CVDocument(language: "en", person: Person(name: "A"), sections: [.summary(String(repeating: "x", count: 16_385))]),
        CVDocument(language: "en", person: Person(name: "A"), sections: [.interests(Array(repeating: "x", count: 201))]),
        CVDocument(language: "en", person: Person(name: "A\u{0007}"), sections: []),
        CVDocument(language: "en", person: Person(name: "A"), sections: [.experience([ExperienceItem(role: "r", company: "c", period: DocumentPeriod(start: DocumentDate(year: 2020), end: .date(DocumentDate(year: 2019))))])]),
    ])
    func validator(doc: CVDocument) {
        #expect(throws: CVDocumentValidator.Invalid.self) { try CVDocumentValidator.validate(doc) }
    }
    @Test("the fixture is valid") func fixtureValid() throws { try CVDocumentValidator.validate(fixture) }

    @Test("text is bounded in bytes: a letter with endless combining marks is refused (final gate)")
    func combiningMarks() {
        let zalgo = "a" + String(repeating: "\u{0301}", count: 20_000)
        #expect(zalgo.count == 1)
        #expect(throws: CVDocumentValidator.Invalid.self) { try CVDocumentValidator.validate(CVDocument(language: "en", person: Person(name: zalgo), sections: [])) }
    }

    @Test("the whole document has a budget, not only each field (final gate)")
    func documentBudget() {
        let field = String(repeating: "x", count: 10_000)
        let doc = CVDocument(language: "en", person: Person(name: "Ada"), sections: [.interests(Array(repeating: field, count: 30))])
        #expect(throws: CVDocumentValidator.Invalid.self) { try CVDocumentValidator.validate(doc) }
    }

    @Test("bidirectional overrides are refused, since they reorder what is printed (final gate)", arguments: ["\u{202E}evil", "a\u{2066}b", "x\u{202A}y"])
    func bidiOverrides(text: String) {
        #expect(throws: CVDocumentValidator.Invalid.self) { try CVDocumentValidator.validate(CVDocument(language: "en", person: Person(name: text), sections: [])) }
    }

    @Test("JSON documents are size-checked before decoding and validated after (final gate)")
    func jsonEntryPoint() throws {
        let data = try JSONEncoder().encode(fixture)
        #expect(try CVDocumentValidator.decode(json: data) == fixture)
        #expect(throws: CVDocumentValidator.Invalid.self) { _ = try CVDocumentValidator.decode(json: Data(repeating: 0x20, count: CVDocumentValidator.maxJSONBytes + 1)) }
        #expect(throws: CVDocumentValidator.Invalid.self) { _ = try CVDocumentValidator.decode(json: Data("{}".utf8)) }
    }
}

@Suite("ADR 0003 · PDFRendering contract")
struct ContractTests {
    func fixtureHTML() throws -> String {
        DocumentHTMLBuilder().build(fixture, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "it"))
    }
    var expected: [String] { get throws {
        DocumentHTMLBuilder().render(fixture, stylesheet: try stylesheet(), palette: palette, headings: try headingsCatalog.headings(for: "it")).textNodes
    } }

    @Test("the fake renderer passes the contract, checked by reading the PDF it wrote")
    func fakePassesContract() async throws {
        try await PDFRenderingContract.verify(FakePDFRenderer(), inspector: MinimalPDFInspector(), html: try fixtureHTML(), expectedText: try expected)
    }

    struct Fabricating: PDFRendering {   // Review probe: bytes that are not a PDF, invented metadata
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            RenderedPDF(data: Data("not a PDF".utf8), pageCount: 999, requiredPages: 999)
        }
    }
    @Test("fabricated output fails")
    func fabricatedFails() async throws {
        await #expect(throws: PDFRenderingContractFailure.notAPDF) {
            try await PDFRenderingContract.verify(Fabricating(), inspector: MinimalPDFInspector(), html: try fixtureHTML(), expectedText: try expected)
        }
    }

    struct DroppingContent: PDFRendering {
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            try await FakePDFRenderer().render(html: html.replacingOccurrences(of: "Mathematics", with: ""), page: page)
        }
    }
    @Test("a renderer that loses content fails")
    func droppedContentFails() async throws {
        await #expect(throws: PDFRenderingContractFailure.self) {
            try await PDFRenderingContract.verify(DroppingContent(), inspector: MinimalPDFInspector(), html: try fixtureHTML(), expectedText: try expected)
        }
    }

    struct PaddingTruncates: PDFRendering {   // a design that pushes the fixture past the page limit
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            try await FakePDFRenderer().render(html: html + String(repeating: "<p>pad</p>", count: 400), page: page)
        }
    }
    @Test("a truncated fixture fails instead of skipping the content check (security C4)")
    func truncatedFixtureFails() async throws {
        await #expect(throws: PDFRenderingContractFailure.fixtureTruncated) {
            try await PDFRenderingContract.verify(PaddingTruncates(), inspector: MinimalPDFInspector(), html: try fixtureHTML(), expectedText: try expected)
        }
    }

    struct SilentlyTruncating: PDFRendering {   // today's behaviour (#8): cuts pages, claims nothing was needed
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            let r = try await FakePDFRenderer().render(html: html, page: page)
            return RenderedPDF(data: r.data, pageCount: r.pageCount, requiredPages: r.pageCount)
        }
    }
    @Test("a renderer that truncates silently fails (#8)")
    func silentTruncationFails() async throws {
        await #expect(throws: PDFRenderingContractFailure.truncationNotReported) {
            try await PDFRenderingContract.verify(SilentlyTruncating(), inspector: MinimalPDFInspector(), html: try fixtureHTML(), expectedText: try expected)
        }
    }

    struct OverReporting: PDFRendering {   // review probe: claims truncation it did not do, drops content
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            let r = try await FakePDFRenderer().render(html: html.replacingOccurrences(of: "Babbage", with: ""), page: page)
            return RenderedPDF(data: r.data, pageCount: r.pageCount, requiredPages: r.pageCount + 1)
        }
    }
    @Test("a renderer that declares truncation it did not do fails (review: H2)")
    func overReportingFails() async throws {
        await #expect(throws: PDFRenderingContractFailure.self) {
            try await PDFRenderingContract.verify(OverReporting(), inspector: MinimalPDFInspector(), html: try fixtureHTML(), expectedText: try expected)
        }
    }

    struct Misreporting: PDFRendering {
        func render(html: String, page: PageSetup) async throws -> RenderedPDF {
            let r = try await FakePDFRenderer().render(html: html, page: page)
            return RenderedPDF(data: r.data, pageCount: r.pageCount + 3, requiredPages: r.requiredPages + 3)
        }
    }
    @Test("a renderer that misreports its page count fails")
    func misreportedPagesFail() async throws {
        await #expect(throws: PDFRenderingContractFailure.self) {
            try await PDFRenderingContract.verify(Misreporting(), inspector: MinimalPDFInspector(), html: try fixtureHTML(), expectedText: try expected)
        }
    }
}

/// Minimal start-tag tokenizer working on Unicode scalars, the way an HTML parser does.
func startTags(in html: String) -> [(name: String, attributes: [String: String])] {
    let scalars = Array(html.unicodeScalars)
    var tags: [(String, [String: String])] = []
    var i = 0
    func isSpace(_ c: Unicode.Scalar) -> Bool { c == " " || c == "\n" || c == "\t" || c == "\r" }
    while i < scalars.count {
        guard scalars[i] == "<", i + 1 < scalars.count, scalars[i + 1] != "/", scalars[i + 1] != "!" else { i += 1; continue }
        i += 1
        var name = ""
        while i < scalars.count, !isSpace(scalars[i]), scalars[i] != ">" { name.unicodeScalars.append(scalars[i]); i += 1 }
        var attrs: [String: String] = [:]
        while i < scalars.count, scalars[i] != ">" {
            while i < scalars.count, isSpace(scalars[i]) { i += 1 }
            var key = ""
            while i < scalars.count, !isSpace(scalars[i]), scalars[i] != "=", scalars[i] != ">" { key.unicodeScalars.append(scalars[i]); i += 1 }
            var value = ""
            if i < scalars.count, scalars[i] == "=" {
                i += 1
                if i < scalars.count, scalars[i] == "\"" {
                    i += 1
                    while i < scalars.count, scalars[i] != "\"" { value.unicodeScalars.append(scalars[i]); i += 1 }
                    i += 1
                } else {
                    while i < scalars.count, !isSpace(scalars[i]), scalars[i] != ">" { value.unicodeScalars.append(scalars[i]); i += 1 }
                }
            }
            if !key.isEmpty { attrs[key] = value }
        }
        tags.append((name, attrs)); i += 1
    }
    return tags
}

@Suite("ADR 0011 · installing a design goes through the rendering gate")
struct InstallTests {
    let noBundledDesigns = FixedBundledSource(packages: [])
    func gate(_ renderer: any PDFRendering) throws -> FixtureRenderingGate {
        FixtureRenderingGate(renderer: renderer, inspector: MinimalPDFInspector(), fixture: fixture,
                             headings: try headingsCatalog.headings(for: "it"))
    }
    @Test("a valid design that renders completely is stored")
    func installs() async throws {
        let store = InMemoryDesignStore()
        _ = try await InstallDesign(source: noBundledDesigns, gate: try gate(FakePDFRenderer()), store: store)(designData(cleanCSS, id: "clean"))
        #expect(try await store.design(id: "clean") != nil)
    }
    @Test("a design whose rendering loses content is not stored")
    func dropped() async throws {
        struct Dropping: PDFRendering {
            func render(html: String, page: PageSetup) async throws -> RenderedPDF {
                try await FakePDFRenderer().render(html: html.replacingOccurrences(of: "Mathematics", with: ""), page: page)
            }
        }
        let store = InMemoryDesignStore()
        await #expect(throws: FixtureRenderingGate.Rejection.self) { _ = try await InstallDesign(source: noBundledDesigns, gate: try gate(Dropping()), store: store)(designData(cleanCSS, id: "clean")) }
        #expect(try await store.design(id: "clean") == nil)
    }
    @Test("an invalid package is not stored and never rendered")
    func invalid() async throws {
        struct Unreachable: PDFRendering { func render(html: String, page: PageSetup) async throws -> RenderedPDF { Issue.record("rendered"); throw CancellationError() } }
        let store = InMemoryDesignStore()
        await #expect(throws: DesignPackageRejected.self) { _ = try await InstallDesign(source: noBundledDesigns, gate: try gate(Unreachable()), store: store)(designData(".cv{display:none}", id: "bad")) }
        #expect(try await store.design(id: "bad") == nil)
    }
}

/// Heading tables held in memory, as an Android app's edge passes them from its assets (ADR 0026).
struct InMemoryHeadingTables: HeadingTableSource {
    struct Unreadable: Error {}
    /// nil: the index cannot be read.
    var indexData: Data?
    var tables: [String: Data]
    /// The tags whose table cannot be read.
    var unreadable: Set<String> = []
    func index() throws -> Data {
        guard let indexData else { throw Unreadable() }
        return indexData
    }
    func table(_ tag: String) throws -> Data? {
        if unreadable.contains(tag) { throw Unreadable() }
        return tables[tag]
    }
}

@Suite("ADR 0026 · the rendering reads its heading tables through a port")
struct HeadingTableSourceTests {
    static let italian = Data(#"{"experience":"Esperienze","education":"Studi","skills":"Competenze","languages":"Lingue","certifications":"Certificazioni","profiles":"Profili","interests":"Interessi","summary":"Profilo","present":"Oggi","native":"Madrelingua"}"#.utf8)

    @Test("the catalog reads the tables of the source it is given, not a bundle")
    func injected() throws {
        let catalog = HeadingsCatalog(source: InMemoryHeadingTables(indexData: Data(#"["it"]"#.utf8), tables: ["it": Self.italian]))
        #expect(try catalog.headings(for: "it-CH").experience == "Esperienze")
        #expect(try catalog.supportedLanguages() == ["it"])
    }

    @Test("a language the source has no table for is unsupported")
    func missing() {
        let catalog = HeadingsCatalog(source: InMemoryHeadingTables(indexData: nil, tables: ["it": Self.italian]))
        #expect(throws: HeadingsCatalog.Failure.unsupportedLanguage("de-AT")) { _ = try catalog.headings(for: "de-AT") }
    }

    @Test("a table or an index the source cannot read, or that is not a table, is corrupt, never a missing language (R7)")
    func unreadable() {
        let catalog = HeadingsCatalog(source: InMemoryHeadingTables(indexData: nil, tables: ["pt": Data("not json".utf8)], unreadable: ["it"]))
        #expect(throws: HeadingsCatalog.Failure.corruptTable("it")) { _ = try catalog.headings(for: "it") }
        #expect(throws: HeadingsCatalog.Failure.corruptTable("pt")) { _ = try catalog.headings(for: "pt-BR") }
        #expect(throws: HeadingsCatalog.Failure.corruptTable("index")) { _ = try catalog.supportedLanguages() }
    }

    @Test("only a tag that reads as BCP 47 reaches the source, so a source may name a file after it", arguments: ["../it", "it/../en", "it\n", ""])
    func validatedTag(tag: String) {
        // Every read of this source fails, so a tag that reached it would be reported as a corrupt table.
        let catalog = HeadingsCatalog(source: InMemoryHeadingTables(indexData: nil, tables: [:], unreadable: [tag, "it", "en"]))
        #expect(throws: HeadingsCatalog.Failure.unsupportedLanguage(tag)) { _ = try catalog.headings(for: tag) }
        #expect(throws: HeadingsCatalog.Failure.corruptTable("it")) { _ = try catalog.headings(for: "it") }
    }

    @Test("the bundled source serves the index and the tables the package ships, and no table for a language it does not ship")
    func bundled() throws {
        let source = BundleHeadingTableSource()
        #expect(try JSONDecoder().decode([String].self, from: source.index()) == ["en", "it", "de", "es", "fr", "pt"])
        #expect(try source.table("it") != nil)
        #expect(try source.table("ja") == nil)
    }
}
