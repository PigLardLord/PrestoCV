import Testing
import Foundation
import PrestoCVCore
@testable import CVPDFExporter

// MARK: - Bundled Template Rendering
//
// Every bundled template is rendered from a CV in which each field has a value of its own, through the same
// path as an export: the adapter, the engine, and the HTML composed from the package.

@Suite("Bundled template rendering")
struct BundledTemplateRenderTests {

    static let templateIDs = ["professional", "modern", "minimal"]

    // MARK: - Fixture

    private enum Field {
        static let name = "Ada Lovelace"
        static let title = "Analytical Engineer"
        static let email = "ada@example.com"
        static let phone = "+44 20 7946 0000"
        static let location = "London"
        static let website = "https://ada.example.com"
        static let summary = "Wrote the first program"

        static let jobTitle = "Lead Engineer"
        static let company = "Difference Works"
        static let jobLocation = "Manchester"
        static let jobPeriod = "March 2020 – Present"
        static let jobDescription = "Built the engine"

        static let degree = "Mathematics"
        static let school = "Cambridge"
        static let studyPeriod = "2010 – 2014"
        static let studyDescription = "First class honours"

        static let ratedSkill = "Algorithms"
        static let unratedSkill = "Poetry"

        static let firstLanguage = "Italian"
        static let firstLevel = "B2"
        static let secondLanguage = "French"
        static let secondLevel = "Native"

        static let certification = "Analytical Society Prize"
        static let issuer = "Royal Society"
        static let certYear = "1843"
        static let certURL = "https://certs.example.com/prize"
        static let certDescription = "For the notes on the engine"

        static let firstInterest = "Music"
        static let secondInterest = "Horses"

        static let platform = "GitHub"
        static let profileURL = "https://github.com/ada"
    }

    private static let header = [Field.name, Field.title, Field.email, Field.phone, Field.location, Field.website]

    /// The localized heading of each section and the fields that must be printed inside it
    private static let sections: [(heading: String, fields: [String])] = [
        ("Work experience", [Field.jobTitle, Field.company, Field.jobLocation, Field.jobPeriod, Field.jobDescription]),
        ("Education", [Field.degree, Field.school, Field.studyPeriod, Field.studyDescription]),
        ("Skills", [Field.ratedSkill, Field.unratedSkill]),
        ("Languages", [Field.firstLanguage, Field.firstLevel, Field.secondLanguage, Field.secondLevel]),
        ("Certifications", [Field.certification, Field.issuer, Field.certYear, Field.certURL, Field.certDescription]),
        ("Interests", [Field.firstInterest, Field.secondInterest]),
        ("Profiles", [Field.platform, Field.profileURL]),
    ]

    private static func fullCV() -> CVModel {
        CVModel(
            name: "Ada",
            personalInfo: PrestoCVCore.PersonalInfo(
                name: Field.name, title: Field.title, location: Field.location, email: Field.email,
                phone: Field.phone, portfolio: Field.website, profile: Field.summary
            ),
            relevant_experience: [Experience(
                title: Field.jobTitle, company: Field.company, location: Field.jobLocation,
                period: Field.jobPeriod, description: Field.jobDescription
            )],
            education: [Education(
                degree: Field.degree, school: Field.school, period: Field.studyPeriod, description: Field.studyDescription
            )],
            skills: [Skill(name: Field.ratedSkill, level: 4), Skill(name: Field.unratedSkill, level: 0)],
            languages: [
                Language(name: Field.firstLanguage, level: .b2),
                Language(name: Field.secondLanguage, level: .native),
            ],
            certifications: [Certification(
                name: Field.certification, issuer: Field.issuer, year: 1843, url: Field.certURL, description: Field.certDescription
            )],
            interests: [Field.firstInterest, Field.secondInterest],
            social: [Social(platform: Field.platform, url: Field.profileURL)]
        )
    }

    // MARK: - Helpers

    /// Every value of the CV that an export has to print: the strings and numbers of the CV as it is stored.
    /// Left out are the ids, the name of the CV (a label in the list of CVs, not part of the document),
    /// the language setting, and the skill ratings, which are printed as dots and checked on their own.
    private static func printedValues(of cv: CVModel) throws -> [String] {
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(cv))
        let notPrinted: Set<String> = ["name", "documentLanguage", "skills.level"]
        var values: [String] = []
        func collect(_ node: Any, path: String) {
            switch node {
            case let object as [String: Any]:
                for (key, child) in object { collect(child, path: path.isEmpty ? key : "\(path).\(key)") }
            case let array as [Any]:
                for child in array { collect(child, path: path) }
            case let text as String:
                if !notPrinted.contains(path), !path.hasSuffix("id") { values.append(text) }
            case let number as NSNumber:
                if !notPrinted.contains(path) { values.append(number.stringValue) }
            default:
                break
            }
        }
        collect(json, path: "")
        return values
    }

    private static func loadPackage(_ id: String) throws -> TemplatePackage {
        let url = try #require(
            Bundle.module.url(forResource: id, withExtension: "mcvt", subdirectory: "Templates/Bundled"),
            "Bundled template '\(id)' should be in the module bundle"
        )
        return try JSONDecoder().decode(TemplatePackage.self, from: Data(contentsOf: url))
    }

    private static func render(_ id: String, language: String = "en", cv: CVModel = fullCV()) async throws -> String {
        let package = try loadPackage(id)
        let template = Template(id: id, name: package.manifest.name, htmlContent: package.composedHTML)
        let converted = PrestoCVCoreAdapter().convertToCV(from: cv)
        let document = CVDocument(personalInfo: converted.personalInfo, sections: converted.sections, metadata: DocumentMetadata(language: language))
        return try await MustacheTemplateEngine().render(template: template, data: document, customization: CustomizationOptions())
    }

    private static func body(of html: String) throws -> String {
        let start = try #require(html.range(of: "<body"))
        let end = try #require(html.range(of: "</body>"))
        return String(html[start.lowerBound..<end.upperBound])
    }

    private static func occurrences(of text: String, in html: String) -> Int {
        html.components(separatedBy: text).count - 1
    }

    private static func block(_ tag: String, containing marker: String, in html: String) throws -> String {
        let pattern = try NSRegularExpression(pattern: "<\(tag)[ >].*?</\(tag)>", options: [.dotMatchesLineSeparators])
        let blocks = pattern.matches(in: html, range: NSRange(html.startIndex..., in: html)).compactMap { Range($0.range, in: html).map { String(html[$0]) } }
        return try #require(blocks.first { $0.contains(marker) }, "No <\(tag)> contains \(marker)")
    }

    // MARK: - Tests

    @Test("Rendered HTML has no template tag left", arguments: templateIDs)
    func noTemplateTagIsLeft(id: String) async throws {
        let html = try await Self.render(id)

        #expect(!html.contains("{{"))
    }

    @Test("The fixture has a value for every field of the CV, and each has a place in the expected page")
    func fixtureCoversEveryField() throws {
        let stored = try Self.printedValues(of: Self.fullCV())
        let expected = Self.header + [Field.summary] + Self.sections.flatMap(\.fields)

        #expect(stored.count >= 30)
        #expect(Set(stored) == Set(expected), "Values of the CV missing from the expectations: \(Set(stored).subtracting(expected).sorted()); expected but not in the CV: \(Set(expected).subtracting(stored).sorted())")
        #expect(Set(stored).count == stored.count, "Each value of the fixture must be unique")
    }

    @Test("Every field of the CV is printed exactly once", arguments: templateIDs)
    func everyFieldIsPrintedOnce(id: String) async throws {
        let body = try Self.body(of: try await Self.render(id))

        for value in try Self.printedValues(of: Self.fullCV()) {
            #expect(Self.occurrences(of: value, in: body) == 1, "'\(value)' should appear once in \(id)")
        }
    }

    @Test("The contact details and the professional title are in the header", arguments: templateIDs)
    func headerFields(id: String) async throws {
        let body = try Self.body(of: try await Self.render(id))
        let header = try Self.block("header", containing: Field.name, in: body)

        for field in Self.header {
            #expect(header.contains(field), "'\(field)' should be in the header of \(id)")
        }
    }

    @Test("Each field is printed in the section it belongs to", arguments: templateIDs)
    func fieldsAreInTheirSection(id: String) async throws {
        let body = try Self.body(of: try await Self.render(id))

        for (heading, fields) in Self.sections {
            #expect(Self.occurrences(of: ">\(heading)<", in: body) == 1, "The heading '\(heading)' should appear once in \(id)")
            let section = try Self.block("section", containing: ">\(heading)<", in: body)
            for field in fields {
                #expect(section.contains(field), "'\(field)' should be in the \(heading) section of \(id)")
            }
        }
    }

    @Test("Headings follow the document language", arguments: templateIDs)
    func headingsFollowTheLanguage(id: String) async throws {
        let body = try Self.body(of: try await Self.render(id, language: "it"))

        for heading in ["Esperienza professionale", "Formazione", "Competenze", "Lingue", "Certificazioni", "Interessi", "Profili"] {
            #expect(Self.occurrences(of: ">\(heading)<", in: body) == 1, "'\(heading)' should appear once in \(id)")
        }
        #expect(!body.contains(">Work experience<"))
    }

    @Test("The page declares the document language", arguments: templateIDs)
    func pageDeclaresTheLanguage(id: String) async throws {
        let html = try await Self.render(id, language: "de")

        #expect(html.contains("<html lang=\"de\">"))
    }

    @Test("A CV with only the required fields renders no empty element", arguments: templateIDs)
    func minimalCVRendersWithoutLeftovers(id: String) async throws {
        let cv = CVModel(personalInfo: PrestoCVCore.PersonalInfo(name: Field.name, email: Field.email))

        let body = try Self.body(of: try await Self.render(id, cv: cv))

        #expect(!body.contains("{{"))
        #expect(!body.contains("<h2></h2>"))
        #expect(!body.contains("<section"))
        #expect(Self.occurrences(of: Field.name, in: body) == 1)
        #expect(Self.occurrences(of: Field.email, in: body) == 1)
    }

    @Test("Line breaks in descriptions are kept", arguments: templateIDs)
    func descriptionsKeepTheirLineBreaks(id: String) throws {
        let package = try Self.loadPackage(id)

        #expect(package.cssContent.contains("white-space: pre-line"))
    }

    @Test("Every class the stylesheet targets exists in the rendered page", arguments: templateIDs)
    func stylesheetClassesExistInThePage(id: String) async throws {
        let package = try Self.loadPackage(id)
        let html = try await Self.render(id)

        let ruleHeads = try NSRegularExpression(pattern: "([^{}]+)\\{")
        let classSelector = try NSRegularExpression(pattern: "\\.([A-Za-z_][A-Za-z0-9_-]*)")
        let css = package.cssContent
        var targeted = Set<String>()
        for head in ruleHeads.matches(in: css, range: NSRange(css.startIndex..., in: css)) {
            let selector = String(css[Range(head.range(at: 1), in: css)!])
            for match in classSelector.matches(in: selector, range: NSRange(selector.startIndex..., in: selector)) {
                targeted.insert(String(selector[Range(match.range(at: 1), in: selector)!]))
            }
        }

        let classAttributes = try NSRegularExpression(pattern: "class=\"([^\"]*)\"")
        var present = Set<String>()
        for match in classAttributes.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            present.formUnion(String(html[Range(match.range(at: 1), in: html)!]).split(separator: " ").map(String.init))
        }

        #expect(!targeted.isEmpty)
        #expect(targeted.subtracting(present).isEmpty, "Classes in the \(id) stylesheet that no element has: \(targeted.subtracting(present).sorted())")
    }

    @Test("Modern sets the page for print and keeps blocks whole")
    func modernSetsThePageForPrint() throws {
        let css = try Self.loadPackage("modern").cssContent

        #expect(css.contains("@page"))
        #expect(css.contains("page-break-inside: avoid"))
    }

    @Test("The rating of a skill is printed as dots, and an unrated skill has none", arguments: templateIDs)
    func skillRatingIsPrinted(id: String) async throws {
        let body = try Self.body(of: try await Self.render(id))

        #expect(Self.occurrences(of: "● ● ● ● ○", in: body) == 1, "The rating of \(Field.ratedSkill) should be printed once in \(id)")
        #expect(!body.contains("○ ○ ○ ○ ○"))
    }
}
