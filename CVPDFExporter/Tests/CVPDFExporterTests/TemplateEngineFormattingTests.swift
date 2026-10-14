import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Engine Formatting (periods, levels, empty values, user text)

@Suite("TemplateEngine Formatting")
struct TemplateEngineFormattingTests {

    private let person = PersonalInfo(name: "Ada Lovelace", email: "ada@example.com", phone: "+44 20 7946 0000")

    private func render(_ html: String, sections: [CVSection] = [], personalInfo: PersonalInfo? = nil) async throws -> String {
        let template = Template(id: "test", name: "Test", htmlContent: html)
        let document = CVDocument(personalInfo: personalInfo ?? person, sections: sections)
        return try await MustacheTemplateEngine().render(template: template, data: document, customization: CustomizationOptions())
    }

    private func workSection(_ items: CVItem...) -> CVSection {
        CVSection(id: "work", type: .work, title: "Work", items: items)
    }

    private func skillsSection(levels: [Int]) -> CVSection {
        let items = levels.enumerated().map { index, level in
            CVItem(title: "Skill\(index)", metadata: ["level": String(level)])
        }
        return CVSection(id: "skills", type: .skills, title: "Skills", items: items)
    }

    // MARK: - Periods

    @Test("A period is printed as one string, with no start and end dash added")
    func periodPassesThroughAsOneString() async throws {
        let item = CVItem(title: "Engineer", period: "March 2020 – Present")

        let html = try await render("{{#workExperience}}[{{period}}]{{/workExperience}}", sections: [workSection(item)])

        #expect(html == "[March 2020 – Present]")
    }

    @Test("Start and end dates are joined into a period when the item has none")
    func periodIsBuiltFromDates() async throws {
        let item = CVItem(title: "Engineer", startDate: "April 2021", endDate: "Present")

        let html = try await render("{{#workExperience}}[{{period}}]{{/workExperience}}", sections: [workSection(item)])

        #expect(html == "[April 2021 – Present]")
    }

    @Test("A start date alone is printed without a separator")
    func periodWithStartDateOnly() async throws {
        let item = CVItem(title: "Engineer", startDate: "2015")

        let html = try await render("{{#workExperience}}[{{period}}]{{/workExperience}}", sections: [workSection(item)])

        #expect(html == "[2015]")
    }

    @Test("Education items carry the period too")
    func educationPeriod() async throws {
        let education = CVSection(id: "education", type: .education, title: "Education", items: [CVItem(title: "MSc", period: "2013 – 2015")])

        let html = try await render("{{#education}}[{{degree}}|{{period}}]{{/education}}", sections: [education])

        #expect(html == "[MSc|2013 – 2015]")
    }

    // MARK: - Skill levels

    @Test("Skill level dots are printed for ratings from 1 to 5", arguments: [
        (1, "● ○ ○ ○ ○"), (3, "● ● ● ○ ○"), (5, "● ● ● ● ●")
    ])
    func levelDots(level: Int, expected: String) async throws {
        let html = try await render("{{#skills}}{{#hasLevel}}[{{levelDots}}]{{/hasLevel}}{{/skills}}", sections: [skillsSection(levels: [level])])

        #expect(html == "[\(expected)]")
    }

    @Test("An unrated skill prints no dots")
    func unratedSkillHasNoDots() async throws {
        let html = try await render("{{#skills}}{{name}}{{#hasLevel}}[{{levelDots}}]{{/hasLevel}};{{/skills}}", sections: [skillsSection(levels: [0, 2])])

        #expect(html == "Skill0;Skill1[● ● ○ ○ ○];")
    }

    @Test("A rating above 5 is clamped to five dots")
    func levelAboveFiveIsClamped() async throws {
        let html = try await render("{{#skills}}[{{level}}|{{levelDots}}]{{/skills}}", sections: [skillsSection(levels: [9])])

        #expect(html == "[5|● ● ● ● ●]")
    }

    // MARK: - Empty values

    @Test("An empty string is false in a conditional block")
    func emptyStringIsFalse() async throws {
        let items = [CVItem(title: "Engineer"), CVItem(title: "Lead", description: "Led a team")]

        let html = try await render("{{#workExperience}}{{title}}{{#description}}:{{description}}{{/description}};{{/workExperience}}", sections: [workSection(items[0], items[1])])

        #expect(html == "Engineer;Lead:Led a team;")
    }

    @Test("An item with no period leaves the conditional block out")
    func emptyPeriodRendersNothing() async throws {
        let item = CVItem(title: "Engineer", period: "")

        let html = try await render("{{#workExperience}}<i>{{#period}}{{period}} –{{/period}}</i>{{/workExperience}}", sections: [workSection(item)])

        #expect(html == "<i></i>")
    }

    @Test("An empty string is true in an inverted block")
    func emptyStringShowsInvertedBlock() async throws {
        let html = try await render("{{#workExperience}}{{^description}}none{{/description}}{{/workExperience}}", sections: [workSection(CVItem(title: "Engineer"))])

        #expect(html == "none")
    }

    // MARK: - User text

    @Test("Braces in user text are printed literally and never evaluated")
    func bracesInSummaryAreLiteral() async throws {
        let info = PersonalInfo(name: "Ada", email: "ada@example.com", phone: "+44 20 7946 0000", summary: "See {{phone}} and {{#hasPhone}}x{{/hasPhone}}")

        let html = try await render("<p>{{summary}}</p>", personalInfo: info)

        #expect(html == "<p>See &#123;&#123;phone&#125;&#125; and &#123;&#123;#hasPhone&#125;&#125;x&#123;&#123;/hasPhone&#125;&#125;</p>")
    }

    @Test("Braces in an item description are printed literally and never evaluated")
    func bracesInDescriptionAreLiteral() async throws {
        let item = CVItem(title: "Engineer", subtitle: "Acme", description: "Worked at {{company}} on {{email}}")

        let html = try await render("{{#workExperience}}<p>{{description}}</p>{{/workExperience}}", sections: [workSection(item)])

        #expect(html == "<p>Worked at &#123;&#123;company&#125;&#125; on &#123;&#123;email&#125;&#125;</p>")
    }

    @Test("Braces in a list item are printed literally")
    func bracesInInterestAreLiteral() async throws {
        let interests = CVSection(id: "interests", type: .interests, title: "Interests", items: [CVItem(title: "{{name}}")])

        let html = try await render("{{#interests}}[{{.}}]{{/interests}}", sections: [interests])

        #expect(html == "[&#123;&#123;name&#125;&#125;]")
    }

    // MARK: - Social links

    @Test("The social section is found by its identifier, whatever its title")
    func socialSectionIsFoundById() async throws {
        let item = CVItem(title: "LinkedIn", url: "https://linkedin.com/in/ada")
        let social = CVSection(id: CVSection.socialID, type: .custom, title: "Profili online", items: [item])

        let html = try await render("{{#hasSocialLinks}}{{#socialLinks}}[{{platform}}|{{url}}]{{/socialLinks}}{{/hasSocialLinks}}", sections: [social])

        #expect(html == "[LinkedIn|https://linkedin.com/<wbr>in/<wbr>ada]")
    }

    @Test("A custom section that is not the social section is not listed as social links")
    func otherCustomSectionsAreNotSocial() async throws {
        let other = CVSection(id: "hobbies", type: .custom, title: "Online Profiles", items: [CVItem(title: "Chess")])

        let html = try await render("{{#hasSocialLinks}}yes{{/hasSocialLinks}}{{^hasSocialLinks}}no{{/hasSocialLinks}}", sections: [other])

        #expect(html == "no")
    }

    // MARK: - Web addresses

    @Test("A web address can break after the slashes that follow a name, and never inside \"https://\"")
    func webAddressBreaksAfterItsSlashes() async throws {
        let info = PersonalInfo(name: "Ada", email: "ada@example.com", website: "https://ada.example.com/work/portfolio/2024")

        let html = try await render("{{website}}", personalInfo: info)

        #expect(html == "https://ada.example.com/<wbr>work/<wbr>portfolio/<wbr>2024")
    }

    @Test("A web address is escaped like any other text, and a trailing slash is left alone")
    func webAddressIsEscaped() async throws {
        let item = CVItem(title: "Certificate", url: "https://example.com/a?x=1&y=<2>/")
        let certifications = CVSection(id: "certs", type: .certifications, title: "Certificates", items: [item])

        let html = try await render("{{#certifications}}{{url}}{{/certifications}}", sections: [certifications])

        #expect(html == "https://example.com/<wbr>a?x=1&amp;y=&lt;2&gt;/")
    }

    @Test("An item without an address has no address block")
    func itemWithoutAddress() async throws {
        let certifications = CVSection(id: "certs", type: .certifications, title: "Certificates", items: [CVItem(title: "ACLS")])

        let html = try await render("{{#certifications}}[{{title}}{{#url}} {{url}}{{/url}}]{{/certifications}}", sections: [certifications])

        #expect(html == "[ACLS]")
    }

    // MARK: - First entry of a section

    @Test("The first entry of work, education and certifications is flagged, and only the first")
    func firstEntryIsFlagged() async throws {
        let sections = [
            CVSection(id: "work", type: .work, title: "Work", items: [CVItem(title: "A"), CVItem(title: "B"), CVItem(title: "C")]),
            CVSection(id: "education", type: .education, title: "Education", items: [CVItem(title: "D"), CVItem(title: "E")]),
            CVSection(id: "certs", type: .certifications, title: "Certificates", items: [CVItem(title: "F"), CVItem(title: "G")])
        ]
        let template = """
        {{#workExperience}}[{{#isFirst}}first {{/isFirst}}{{title}}]{{/workExperience}}\
        {{#education}}[{{#isFirst}}first {{/isFirst}}{{degree}}]{{/education}}\
        {{#certifications}}[{{#isFirst}}first {{/isFirst}}{{title}}]{{/certifications}}
        """

        let html = try await render(template, sections: sections)

        #expect(html == "[first A][B][C][first D][E][first F][G]")
    }

    // MARK: - Style values

    @Test("Font stacks are written into CSS with their quotes intact", arguments: FontScheme.allCases)
    func fontStacksKeepTheirQuotes(scheme: FontScheme) async throws {
        let template = Template(id: "test", name: "Test", htmlContent: "body { font-family: {{fontBody}}; }")
        let document = CVDocument(personalInfo: person)

        let html = try await MustacheTemplateEngine().render(template: template, data: document, customization: CustomizationOptions(fontScheme: scheme))

        #expect(html == "body { font-family: \(scheme.fonts.body); }")
    }

    @Test("Palette colours are written into CSS as they are", arguments: ColorPalette.allCases)
    func paletteColoursAreWrittenAsTheyAre(palette: ColorPalette) async throws {
        let template = Template(id: "test", name: "Test", htmlContent: "a { color: {{colorPrimary}}; background: {{colorBackground}}; }")
        let document = CVDocument(personalInfo: person)

        let html = try await MustacheTemplateEngine().render(template: template, data: document, customization: CustomizationOptions(colorPalette: palette))

        #expect(html == "a { color: \(palette.colors.primary); background: \(palette.colors.background); }")
    }
}
