import Foundation
import Testing
@testable import PrestoCVImporting

/// A heading the vocabulary does not know ("OWN VENTURES"), written in the look of the headings it knows, opens a section
/// of its own: its lines stay visible as text not imported under that heading, and are not read as jobs of the section
/// before it (ADR 0027). Only the known headings vouch for it, never the lines that could be headings themselves.
@Suite("An unknown heading in the look of the known ones (#454)")
struct UnknownHeadingTests {

    private func importText(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    private func importPDF(_ sketch: PageSketch) async throws -> ImportResult {
        try await ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([sketch.page])), limits: .standard).importPDF(Data([1]))
    }

    // MARK: The CV of the issue

    /// The lines of the CV, each with whether it is a heading.
    private static let lines: [(text: String, isHeading: Bool)] = [
        ("iOS Engineer", false),
        ("tobias.renn@example.com · Leipzig, Germany", false),
        ("SUMMARY", true),
        ("iOS engineer with ten years of apps for field teams.", false),
        ("EXPERIENCE", true),
        ("Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany", false),
        ("July 2017 – Present · Cloud tools for logistics teams", false),
        ("• Led the move to SwiftUI.", false),
        ("• Built the offline sync engine.", false),
        ("Mobile Developer — Northwind Labs, Lucca, Italy", false),
        ("May 2014 – June 2017 · Field service app for retail teams", false),
        ("• Built the offline order screens.", false),
        ("• Wrote the release scripts for the store builds.", false),
        ("OWN VENTURES", true),
        ("Tidepool Notes — maker, solo", false),
        ("2022 – Present · a markdown notes app for iPad", false),
        ("• Designed and shipped the app on the App Store.", false),
        ("Harbor Timer — co-founder", false),
        ("2018 – 2019 · a shift timer for dock workers", false),
        ("• Wrote the watch app.", false),
        ("SKILLS", true),
        ("Swift, SwiftUI, Combine", false),
        ("LANGUAGES", true),
        ("German — native", false),
        ("English — fluent", false),
    ]

    /// The words of the six lines under OWN VENTURES, without their bullets.
    private static let ventures = [
        "Tidepool Notes — maker, solo",
        "2022 – Present · a markdown notes app for iPad",
        "Designed and shipped the app on the App Store.",
        "Harbor Timer — co-founder",
        "2018 – 2019 · a shift timer for dock workers",
        "Wrote the watch app.",
    ]

    /// A CV as pasted text, its name first; with `blankLines`, a blank line before each heading.
    private static func pastedCV(_ name: String, _ lines: [(text: String, isHeading: Bool)], blankLines: Bool) -> String {
        var text = [name]
        for line in lines {
            if line.isHeading, blankLines { text.append("") }
            text.append(line.text)
        }
        return text.joined(separator: "\n")
    }

    /// A CV drawn on a page, its name first: every line at the same x, the headings at 11 pt over a body of 10 pt (not
    /// emphasized), not bold, after a wider gap.
    private static func drawnCV(_ name: String, _ lines: [(text: String, isHeading: Bool)]) -> PageSketch {
        var sketch = PageSketch()
        sketch.put(name, x: 50, y: 50, size: 20, bold: true)
        var y = 80.0
        for line in lines {
            if line.isHeading { y += 18 }
            sketch.put(line.text, x: 50, y: y, size: line.isHeading ? 11 : 10)
            y += line.isHeading ? 15 : 14
        }
        return sketch
    }

    /// Checks the import of the issue's CV: two jobs, the six lines under OWN VENTURES as text not imported with that
    /// heading, the skills and the languages read, nothing lost.
    private func expectTheVenturesStayVisible(_ result: ImportResult, _ label: String) {
        let jobs = result.cv.experience
        #expect(jobs.count == 2, "\(label): \(jobs.map { [$0.role?.value, $0.employer?.value] })")
        let jobTexts = jobs.flatMap { job in
            [job.role?.value, job.employer?.value, job.location?.value].compactMap { $0 } + job.details.map(\.value)
        }
        for word in ["Tidepool", "Harbor", "VENTURES", "markdown", "watch app"] {
            #expect(!jobTexts.contains { $0.contains(word) }, "\(label): \(word) in a job: \(jobTexts)")
        }
        let underVentures = result.unplaced.filter { $0.heading == "OWN VENTURES" }.map(\.text).joined(separator: "\n")
        for line in Self.ventures {
            #expect(underVentures.contains(line), "\(label): «\(line)» not under OWN VENTURES: \(result.unplaced.map { ($0.heading, $0.text) })")
        }
        #expect(result.cv.skills.map(\.value).contains("Swift"), "\(label): \(result.cv.skills.map(\.value))")
        #expect(result.cv.languages.count == 2, "\(label): \(result.cv.languages.map(\.name.value))")
        #expect(Coverage.lost(result).isEmpty, "\(label): \(Coverage.describe(Coverage.lost(result)))")
    }

    @Test("Pasted without blank lines, as in the issue: the ventures are a section of their own, not jobs")
    func pastedWithoutBlankLines() throws {
        expectTheVenturesStayVisible(try importText(Self.pastedCV("Tobias Renn", Self.lines, blankLines: false)), "no blank lines")
    }

    @Test("Pasted with a blank line before each heading: the ventures are a section of their own, not jobs")
    func pastedWithBlankLines() throws {
        expectTheVenturesStayVisible(try importText(Self.pastedCV("Tobias Renn", Self.lines, blankLines: true)), "blank lines")
    }

    @Test("Drawn in a PDF, the headings a size larger than the text but not emphasized: the ventures are a section of their own")
    func drawnInAPDF() async throws {
        expectTheVenturesStayVisible(try await importPDF(Self.drawnCV("Tobias Renn", Self.lines)), "PDF")
    }

    // MARK: A heading with a word of an entry

    /// A CV whose third heading the vocabulary of the sections does not know, after an entry that ends with a detail, as
    /// the ventures of the issue.
    private static func lines(under heading: String) -> [(text: String, isHeading: Bool)] {
        [
            ("SUMMARY", true),
            ("Mobile engineer.", false),
            ("EXPERIENCE", true),
            ("Developer — Cedar Labs", false),
            ("2018 – 2021", false),
            ("Built mobile tools.", false),
            (heading, true),
            ("Tidepool Notes — maker, solo", false),
            ("2022 – Present · notes app", false),
            ("• Shipped the app.", false),
            ("SKILLS", true),
            ("Swift", false),
            ("LANGUAGES", true),
            ("German — native", false),
        ]
    }

    /// An unknown heading with a word the vocabulary of the entries knows (a role, an organisation, a school, a degree),
    /// and the checks the jobs get.
    struct HeadingWithAWordOfAnEntry: Sendable, CustomTestStringConvertible {
        let heading: String
        let checks: [CheckReason?]
        var testDescription: String { heading }
    }

    /// Such a heading has the shape of a role in capitals over its employer and its dates (the rows of `entryParts` that
    /// start "A role in capitals after a detail"), and only its words tell them apart. So the line stays where the entries
    /// read it, a job is never cut from its section, and the job that takes the line is to be checked (#466): the job it
    /// heads for a role or an organisation, the job before it for a school or a degree, as with the other doubtful lines.
    static let headingsWithAWordOfAnEntry = [
        HeadingWithAWordOfAnEntry(heading: "FOUNDER VENTURES", checks: [nil, .headingUnsure]),
        HeadingWithAWordOfAnEntry(heading: "CONSULTING MANDATES", checks: [nil, .headingUnsure]),
        HeadingWithAWordOfAnEntry(heading: "SCHOOL OUTREACH", checks: [.headingUnsure, .roleOrEmployerByOrder]),
        HeadingWithAWordOfAnEntry(heading: "MASTER CLASSES", checks: [.headingUnsure, .roleOrEmployerByOrder]),
    ]

    @Test("A heading with a word of an entry, after a detail, stays in its section and the job that takes it is to be checked: pasted and drawn", arguments: headingsWithAWordOfAnEntry)
    func headingWithAWordOfAnEntry(_ row: HeadingWithAWordOfAnEntry) async throws {
        let lines = Self.lines(under: row.heading)
        let withoutBlankLines = try importText(Self.pastedCV("Mara Voss", lines, blankLines: false))
        let withBlankLines = try importText(Self.pastedCV("Mara Voss", lines, blankLines: true))
        let drawn = try await importPDF(Self.drawnCV("Mara Voss", lines))
        for (label, result) in [("no blank lines", withoutBlankLines), ("blank lines", withBlankLines), ("PDF", drawn)] {
            #expect(Coverage.lost(result).isEmpty, "\(label): \(Coverage.describe(Coverage.lost(result)))")
            let jobs = result.cv.experience
            try #require(jobs.count == 2, "\(label): \(jobs.map { [$0.role?.value, $0.employer?.value] })")
            #expect(jobs.map(\.check) == row.checks, "\(label): \(jobs.map(\.check))")
            for (index, check) in row.checks.enumerated() {
                let listed = result.reviewList.contains { $0.field == .experience(index) && $0.reason == .headingUnsure }
                #expect(listed == (check == .headingUnsure), "\(label), job \(index): \(result.reviewList.map { ($0.field, $0.reason) })")
                let holdsTheLine = [jobs[index].role?.value, jobs[index].employer?.value].contains(row.heading)
                    || jobs[index].details.contains { $0.value.contains(row.heading) }
                #expect(holdsTheLine == (check == .headingUnsure), "\(label), job \(index): the job to be checked is the one that took the line")
            }
            let under = result.unplaced.filter { $0.heading == row.heading }
            #expect(under.isEmpty, "\(label): no section of its own: \(under.map(\.text))")
        }
    }

    // MARK: A line with a word of an entry, outside the jobs and the studies

    /// A line in capitals with a word of an entry, under a heading of a section without employers or schools, drawn as
    /// the known headings: the items of that section before it and after it.
    struct LineInAListSection: Sendable, CustomTestStringConvertible {
        let heading: String
        let before: [String]
        let line: String
        let after: [String]
        var testDescription: String { "\(line) under \(heading)" }
    }

    /// Only an entry with an employer or a school can take such a line as its role or its employer: in any other section
    /// the line was never a heading candidate, and it stays a part of the section (#466).
    static let linesInAListSection = [
        LineInAListSection(heading: "SKILLS", before: ["Swift", "Go"], line: "PROJECT MANAGEMENT", after: ["Scrum", "Kanban"]),
        LineInAListSection(heading: "INTERESTS", before: ["Chess", "Cycling"], line: "SCHOOL OUTREACH", after: ["Mentoring", "Robotics"]),
    ]

    @Test("Outside the jobs and the studies, a line in capitals with a word of an entry stays in its section: pasted and drawn", arguments: linesInAListSection)
    func lineWithAWordOfAnEntryInAListSection(_ row: LineInAListSection) async throws {
        let lines: [(text: String, isHeading: Bool)] = [
            ("SUMMARY", true),
            ("Mobile engineer.", false),
            ("EXPERIENCE", true),
            ("Developer — Cedar Labs", false),
            ("2018 – 2021", false),
            ("Built mobile tools.", false),
            (row.heading, true),
        ] + row.before.map { ($0, false) } + [(row.line, true)] + row.after.map { ($0, false) } + [
            ("LANGUAGES", true),
            ("German — native", false),
        ]
        let withoutBlankLines = try importText(Self.pastedCV("Mara Voss", lines, blankLines: false))
        let withBlankLines = try importText(Self.pastedCV("Mara Voss", lines, blankLines: true))
        let drawn = try await importPDF(Self.drawnCV("Mara Voss", lines))
        for (label, result) in [("no blank lines", withoutBlankLines), ("blank lines", withBlankLines), ("PDF", drawn)] {
            #expect(Coverage.lost(result).isEmpty, "\(label): \(Coverage.describe(Coverage.lost(result)))")
            let read = (row.heading == "SKILLS" ? result.cv.skills : result.cv.interests).map(\.value)
            for item in row.before + row.after {
                #expect(read.contains(item), "\(label): \(item) not read in \(row.heading): \(read)")
            }
            let under = result.unplaced.filter { $0.heading == row.line }
            #expect(under.isEmpty, "\(label): no section of its own: \(under.map(\.text))")
            #expect(result.cv.experience.count == 1, "\(label): \(result.cv.experience.map { [$0.role?.value, $0.employer?.value] })")
        }
    }

    // MARK: What does not open a section

    private func kinds(_ text: String) -> [SectionKind] {
        pasted(text).1.map(\.kind)
    }

    @Test("An employer in capitals on a line of its own, above each job, opens no section")
    func employersInCapitals() throws {
        let text = """
        Tobias Renn
        iOS Engineer
        tobias.renn@example.com

        EXPERIENCE
        KESTREL CLOUD GMBH
        Senior iOS Engineer
        July 2017 – Present
        • Led the move to SwiftUI.

        NORTHWIND LABS
        Mobile Developer
        May 2014 – June 2017
        • Built the offline order screens.

        SKILLS
        Swift, SwiftUI

        LANGUAGES
        German — native
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
        let result = try importText(text)
        #expect(result.cv.experience.count == 2, "\(result.cv.experience.map { [$0.role?.value, $0.employer?.value] })")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.describe(Coverage.lost(result)))")
    }

    @Test("One known heading in capitals vouches for nothing")
    func oneKnownHeading() {
        let text = """
        Tobias Renn
        iOS Engineer

        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present
        • Led the move to SwiftUI.

        OWN VENTURES
        Tidepool Notes — maker, solo
        • Designed and shipped the app on the App Store.

        Skills
        Swift, SwiftUI
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    @Test("A line in capitals followed by a period is a job, not a heading")
    func capitalsBeforeAPeriod() {
        let text = """
        Tobias Renn
        iOS Engineer

        EXPERIENCE
        Kestrel Cloud — Leipzig, Germany
        • Led the move to SwiftUI.

        PLATFORM ENGINEER
        July 2017 – Present
        • Built the offline sync engine.

        SKILLS
        Swift

        LANGUAGES
        German — native
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    @Test("Sub-headings in capitals inside a section open no section")
    func subHeadingsInCapitals() {
        #expect(SectionVocabulary.kind(ofHeading: "TECHNICAL") == nil)
        #expect(SectionVocabulary.kind(ofHeading: "LEADERSHIP") == nil)
        let text = """
        Tobias Renn
        iOS Engineer

        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present

        SKILLS

        TECHNICAL
        Swift, SwiftUI

        LEADERSHIP
        Mentoring, hiring

        LANGUAGES
        German — native
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    @Test("An acronym in capitals inside a section opens no section")
    func acronym() {
        let text = """
        Tobias Renn
        iOS Engineer

        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present

        SKILLS
        Swift
        Kotlin

        HTML
        CSS

        LANGUAGES
        German — native
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    @Test("A title in capitals in the head of the CV opens no section")
    func titleInCapitals() {
        let text = """
        TOBIAS RENN

        MOBILE ENGINEER
        tobias.renn@example.com

        SUMMARY
        iOS engineer with ten years of apps for field teams.

        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present

        SKILLS
        Swift
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    // MARK: A part of an entry in capitals

    /// A CV with a role, an employer or a school in capitals, where only one entry of its section writes it so, and
    /// what the import reads of it: as on main, with no section opened.
    struct EntryPart: Sendable, CustomTestStringConvertible {
        let testDescription: String
        let text: String
        let jobs: Int
        let studies: Int
        /// The roles, the employers and the schools the import reads, in order; empty when the entry reader does not tell
        /// them apart on main either (a role it does not know, before its employer).
        var roles: [String] = []
        var employers: [String] = []
        var schools: [String] = []
    }

    static let entryParts = [
        EntryPart(
            testDescription: "A role in capitals, then its employer and its dates",
            text: """
            Tobias Renn
            tobias.renn@example.com

            SUMMARY
            Mobile engineer.

            EXPERIENCE
            Developer — Northwind Labs
            2014 – 2017
            Built the offline order screens.

            PLATFORM ENGINEER
            Kestrel Cloud
            2017 – Present
            Led the move to SwiftUI.

            SKILLS
            Swift

            LANGUAGES
            German — native
            """,
            jobs: 2, studies: 0,
            roles: ["Developer", "PLATFORM ENGINEER"], employers: ["Northwind Labs", "Kestrel Cloud"]
        ),
        EntryPart(
            testDescription: "A role the vocabulary does not know, in capitals, then its employer and its dates",
            text: """
            Tobias Renn
            tobias.renn@example.com

            SUMMARY
            Mobile engineer.

            EXPERIENCE
            Developer — Northwind Labs
            2014 – 2017
            Built the offline order screens.

            CHIEF WIZARD
            Kestrel Cloud
            2017 – Present
            Led the move to SwiftUI.

            SKILLS
            Swift

            LANGUAGES
            German — native
            """,
            jobs: 2, studies: 0
        ),
        EntryPart(
            testDescription: "Roles in capitals after the employer and the dates of each job",
            text: """
            Tobias Renn
            iOS Engineer
            tobias.renn@example.com
            SUMMARY
            iOS engineer with ten years of apps for field teams.
            EXPERIENCE
            Kestrel Cloud, Leipzig — July 2017 – Present
            PLATFORM ENGINEER
            • Led the move to SwiftUI.
            Northwind Labs, Lucca — May 2014 – June 2017
            MOBILE DEVELOPER
            • Built the offline order screens.
            SKILLS
            Swift, SwiftUI
            LANGUAGES
            German — native
            """,
            jobs: 2, studies: 0,
            roles: ["PLATFORM ENGINEER", "MOBILE DEVELOPER"], employers: ["Kestrel Cloud", "Northwind Labs"]
        ),
        EntryPart(
            testDescription: "Roles the vocabulary does not know, in capitals, after the employer and the dates of each job",
            text: """
            Tobias Renn
            iOS Engineer
            tobias.renn@example.com
            SUMMARY
            iOS engineer with ten years of apps for field teams.
            EXPERIENCE
            Kestrel Cloud, Leipzig — July 2017 – Present
            CHIEF WIZARD
            • Led the move to SwiftUI.
            Northwind Labs, Lucca — May 2014 – June 2017
            GROWTH HACKER
            • Built the offline order screens.
            SKILLS
            Swift, SwiftUI
            LANGUAGES
            German — native
            """,
            jobs: 2, studies: 0
        ),
        EntryPart(
            testDescription: "A school in capitals under its degree",
            text: """
            Tobias Renn
            iOS Engineer
            EXPERIENCE
            Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
            July 2017 – Present
            EDUCATION
            BSc Computer Science
            UNIVERSITY OF NORTHBRIDGE
            Leipzig, Germany
            SKILLS
            Swift
            """,
            jobs: 1, studies: 1,
            schools: ["UNIVERSITY OF NORTHBRIDGE"]
        ),
        EntryPart(
            testDescription: "A degree in capitals under its school",
            text: """
            Tobias Renn
            iOS Engineer
            EXPERIENCE
            Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
            July 2017 – Present
            EDUCATION
            University of Northbridge
            BSC COMPUTER SCIENCE
            Leipzig, Germany
            SKILLS
            Swift
            """,
            jobs: 1, studies: 1
        ),
        EntryPart(
            testDescription: "An employer in capitals under its role, then its place",
            text: """
            Tobias Renn
            iOS Engineer
            EXPERIENCE
            Mobile Developer — Northwind Labs, Lucca, Italy
            May 2014 – June 2017
            Senior iOS Engineer
            KESTREL CLOUD GMBH
            Leipzig, Germany
            July 2017 – Present
            SKILLS
            Swift
            """,
            jobs: 2, studies: 0
        ),
        EntryPart(
            testDescription: "A role in capitals under its employer, then its place",
            text: """
            Tobias Renn
            iOS Engineer
            EXPERIENCE
            Mobile Developer — Northwind Labs, Lucca, Italy
            May 2014 – June 2017
            Kestrel Labs
            SENIOR DEVELOPER
            Leipzig, Germany
            July 2017 – Present
            SKILLS
            Swift
            """,
            jobs: 2, studies: 0
        ),
        EntryPart(
            testDescription: "A role in capitals after a detail, over its employer and its place (comma), with blank lines",
            text: """
            Tobias Renn
            tobias.renn@example.com

            SUMMARY
            Mobile engineer.

            EXPERIENCE
            Developer — Northwind Labs
            2014 – 2017
            Built the offline order screens.

            PLATFORM ENGINEER
            Kestrel Cloud, Leipzig
            2017 – Present
            Led the move to SwiftUI.

            SKILLS
            Swift

            LANGUAGES
            German — native
            """,
            jobs: 2, studies: 0
        ),
        EntryPart(
            testDescription: "A role in capitals after a detail, over its employer and its place (comma), without blank lines",
            text: """
            Tobias Renn
            tobias.renn@example.com
            SUMMARY
            Mobile engineer.
            EXPERIENCE
            Developer — Northwind Labs
            2014 – 2017
            Built the offline order screens.
            PLATFORM ENGINEER
            Kestrel Cloud, Leipzig
            2017 – Present
            Led the move to SwiftUI.
            SKILLS
            Swift
            LANGUAGES
            German — native
            """,
            jobs: 2, studies: 0
        ),
        EntryPart(
            testDescription: "A role in capitals after a detail, over its employer and its place (dash), with blank lines",
            text: """
            Tobias Renn
            tobias.renn@example.com

            SUMMARY
            Mobile engineer.

            EXPERIENCE
            Developer — Northwind Labs
            2014 – 2017
            Built the offline order screens.

            PLATFORM ENGINEER
            Kestrel Cloud — Leipzig
            2017 – Present
            Led the move to SwiftUI.

            SKILLS
            Swift

            LANGUAGES
            German — native
            """,
            jobs: 2, studies: 0
        ),
        EntryPart(
            testDescription: "A role in capitals after a detail, over its employer and its place (dash), without blank lines",
            text: """
            Tobias Renn
            tobias.renn@example.com
            SUMMARY
            Mobile engineer.
            EXPERIENCE
            Developer — Northwind Labs
            2014 – 2017
            Built the offline order screens.
            PLATFORM ENGINEER
            Kestrel Cloud — Leipzig
            2017 – Present
            Led the move to SwiftUI.
            SKILLS
            Swift
            LANGUAGES
            German — native
            """,
            jobs: 2, studies: 0
        ),
    ]

    @Test("A part of an entry in capitals opens no section: its entry is read, nothing is left out", arguments: entryParts)
    func entryPartInCapitals(_ example: EntryPart) throws {
        #expect(!kinds(example.text).contains(.unknown), "\(kinds(example.text))")
        let result = try importText(example.text)
        let jobs = result.cv.experience
        let studies = result.cv.education
        #expect(jobs.count == example.jobs, "\(jobs.map { [$0.role?.value, $0.employer?.value] })")
        #expect(studies.count == example.studies, "\(studies.map { [$0.degree?.value, $0.school?.value] })")
        if !example.roles.isEmpty {
            #expect(jobs.map { $0.role?.value ?? "" } == example.roles)
        }
        if !example.employers.isEmpty {
            #expect(jobs.map { $0.employer?.value ?? "" } == example.employers)
        }
        if !example.schools.isEmpty {
            #expect(studies.map { $0.school?.value ?? "" } == example.schools)
        }
        #expect(result.unplaced.isEmpty, "\(result.unplaced.map { ($0.heading, $0.text) })")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.describe(Coverage.lost(result)))")
    }

    @Test("An unknown heading after an entry that ends with its dates still opens a section")
    func afterAnEntryEndingWithItsDates() throws {
        let text = """
        Tobias Renn
        iOS Engineer
        SUMMARY
        iOS engineer with ten years of apps for field teams.
        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present
        OWN VENTURES
        Tidepool Notes — maker, solo
        2022 – Present · a markdown notes app for iPad
        • Designed and shipped the app on the App Store.
        SKILLS
        Swift, SwiftUI
        LANGUAGES
        German — native
        """
        let result = try importText(text)
        #expect(result.cv.experience.count == 1, "\(result.cv.experience.map { [$0.role?.value, $0.employer?.value] })")
        let underVentures = result.unplaced.filter { $0.heading == "OWN VENTURES" }.map(\.text).joined(separator: "\n")
        for line in Self.ventures.prefix(3) {
            #expect(underVentures.contains(line), "«\(line)» not under OWN VENTURES: \(result.unplaced.map { ($0.heading, $0.text) })")
        }
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.describe(Coverage.lost(result)))")
    }

    @Test("A line in capitals without the gap the known headings have opens no section")
    func gapDiffers() {
        let text = """
        Tobias Renn
        iOS Engineer

        EXPERIENCE
        Senior iOS Engineer — Kestrel Cloud, Leipzig, Germany
        July 2017 – Present
        • Led the move to SwiftUI.
        OWN VENTURES
        Tidepool Notes — maker, solo
        • Designed and shipped the app on the App Store.

        SKILLS
        Swift, SwiftUI

        LANGUAGES
        German — native
        """
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
    }

    // MARK: A doubtful heading

    /// A field technician's CV with `experience` under its heading, a skill and a language after it.
    private static func doubtfulCV(_ experience: [String], after tail: [String] = []) -> String {
        (["Lena Okafor", "lena.okafor@example.com", "SUMMARY", "Field technician.", "EXPERIENCE"] + experience
            + ["SKILLS", "Welding", "LANGUAGES", "Italian — native"] + tail).joined(separator: "\n")
    }

    /// Jobs with a line in capitals, drawn as the known headings, that the line below it does not settle: a bullet, a role
    /// alone, a role with a place, known or not, a team and its role, an organisation and its role. It may be a heading the
    /// vocabulary does not know or the employer of a job.
    struct DoubtfulHeading: Sendable, CustomTestStringConvertible {
        let testDescription: String
        let experience: [String]
        /// The roles, the employers and the places the import reads on main, in order.
        let roles: [String?]
        let employers: [String?]
        let places: [String?]
        let checks: [CheckReason?]
    }

    static let doubtful: [DoubtfulHeading] = [
        DoubtfulHeading(
            testDescription: "under a role, over a bullet",
            experience: [
                "2020 – Present", "Technician", "BRACKEN MILLS", "• Serviced pumps.",
                "2016 – 2020", "Technician — Marlow Studio", "• Serviced boilers.",
            ],
            roles: ["Technician", "Technician"], employers: ["BRACKEN MILLS", "Marlow Studio"], places: [nil, nil],
            checks: [.headingUnsure, nil]
        ),
        DoubtfulHeading(
            testDescription: "over a role alone",
            experience: [
                "2016 – 2020", "Technician — Marlow Studio", "• Serviced boilers.",
                "2020 – Present", "BRACKEN MILLS", "Technician", "• Serviced pumps.",
            ],
            roles: ["Technician", "Technician"], employers: ["Marlow Studio", "BRACKEN MILLS"], places: [nil, nil],
            checks: [nil, .headingUnsure]
        ),
        DoubtfulHeading(
            testDescription: "over a role and a place",
            experience: [
                "Technician — Marlow Studio, Bergamo", "2016 – 2020", "• Serviced boilers.",
                "BRACKEN MILLS", "Technician — Dresden", "2020 – Present", "• Serviced pumps.",
            ],
            roles: ["Technician", "Technician"], employers: ["Marlow Studio", nil], places: ["Bergamo", "Dresden"],
            checks: [.headingUnsure, nil]
        ),
        DoubtfulHeading(
            testDescription: "over a role and a town the places do not know",
            experience: [
                "Technician — Marlow Studio, Bergamo", "2016 – 2020", "• Serviced boilers.",
                "BRACKEN MILLS", "Technician — Hollowford", "2020 – Present", "• Serviced pumps.",
            ],
            roles: ["Technician", "Technician"], employers: ["Marlow Studio", "Hollowford"], places: ["Bergamo", nil],
            checks: [.headingUnsure, .roleOrEmployerByOrder]
        ),
        DoubtfulHeading(
            testDescription: "over a team and its role",
            experience: [
                "Technician — Marlow Studio", "2016 – 2020", "• Serviced boilers.",
                "BRACKEN MILLS", "Pump Division — Technician", "2020 – Present", "• Serviced pumps.",
            ],
            roles: ["Technician", "Technician"], employers: ["Marlow Studio", "Pump Division"], places: [nil, nil],
            checks: [.headingUnsure, .roleOrEmployerByOrder]
        ),
        DoubtfulHeading(
            testDescription: "among labelled jobs",
            experience: [
                "Dates: 2016 – 2020", "Employer: Marlow Studio", "Role: Technician", "BRACKEN MILLS", "• Serviced pumps.",
                "Dates: 2020 – Present", "Role: Technician",
            ],
            roles: ["Technician", "Technician"], employers: ["Marlow Studio", nil], places: [nil, nil],
            checks: [.headingUnsure, nil]
        ),
        DoubtfulHeading(
            testDescription: "over an organisation and its role",
            experience: [
                "Technician — Marlow Studio", "2016 – 2020", "• Serviced boilers.",
                "BRACKEN MILLS", "Hollow Pumps Ltd — Fitter", "2020 – Present", "• Serviced pumps.",
            ],
            roles: ["Technician", "Fitter"], employers: ["Marlow Studio", "Hollow Pumps Ltd"], places: [nil, nil],
            checks: [.headingUnsure, .roleOrEmployerByOrder]
        ),
        DoubtfulHeading(
            testDescription: "over a role and a word of an organisation",
            experience: [
                "Technician — Marlow Studio", "2016 – 2020", "• Serviced boilers.",
                "BRACKEN MILLS", "Fitter — Hollow Pump Services", "2020 – Present", "• Serviced pumps.",
            ],
            roles: ["Technician", "Fitter"], employers: ["Marlow Studio", "Hollow Pump Services"], places: [nil, nil],
            checks: [.headingUnsure, .roleOrEmployerByOrder]
        ),
    ]

    @Test("A line in capitals the line below does not settle stays where main reads it, in a job to be checked", arguments: doubtful)
    func doubtfulHeadingStaysInItsJob(_ row: DoubtfulHeading) throws {
        let text = Self.doubtfulCV(row.experience)
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
        let result = try importText(text)
        let jobs = result.cv.experience
        #expect(jobs.map(\.role?.value) == row.roles, "\(jobs.map { [$0.role?.value, $0.employer?.value] })")
        #expect(jobs.map(\.employer?.value) == row.employers, "\(jobs.map { [$0.role?.value, $0.employer?.value] })")
        #expect(jobs.map(\.location?.value) == row.places, "\(jobs.map(\.location?.value))")
        #expect(jobs.map(\.check) == row.checks, "\(jobs.map(\.check))")
        for (index, check) in row.checks.enumerated() {
            let listed = result.reviewList.contains { $0.field == .experience(index) && $0.reason == .headingUnsure }
            #expect(listed == (check == .headingUnsure), "job \(index): \(result.reviewList.map { ($0.field, $0.reason) })")
        }
        #expect(!result.unplaced.contains { $0.heading == "BRACKEN MILLS" }, "\(result.unplaced.map { ($0.heading, $0.text) })")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.describe(Coverage.lost(result)))")
    }

    /// Studies with a line in capitals under a degree, drawn as the known headings, that the line below it does not settle:
    /// a bullet, a degree and its school, a degree and a town, a school and its subject. It may be a heading the vocabulary
    /// does not know or the school of a study.
    struct DoubtfulStudy: Sendable, CustomTestStringConvertible {
        let testDescription: String
        /// The lines after the languages, from the heading of the studies on.
        let tail: [String]
        /// The degrees, the schools and the places the import reads on main, in order.
        let degrees: [String?]
        let schools: [String?]
        let places: [String?]
        let checks: [CheckReason?]
    }

    static let doubtfulStudies: [DoubtfulStudy] = [
        DoubtfulStudy(
            testDescription: "under a degree, over a bullet",
            tail: [
                "EDUCATION", "2013 – 2016", "Diploma in Welding", "HOLLOWAY TRUST", "• Practical modules.",
                "2009 – 2013", "BSc Geology — University of Northbridge",
            ],
            degrees: ["Diploma in Welding", "BSc Geology"], schools: ["HOLLOWAY TRUST", "University of Northbridge"],
            places: [nil, nil], checks: [.headingUnsure, nil]
        ),
        DoubtfulStudy(
            testDescription: "over a degree and its school",
            tail: [
                "EDUCATION", "2013 – 2016", "Diploma in Welding", "HOLLOWAY TRUST",
                "BSc Geology — University of Northbridge", "• Completed fieldwork.",
            ],
            degrees: ["Diploma in Welding"], schools: ["University of Northbridge"], places: ["HOLLOWAY TRUST"],
            checks: [.headingUnsure]
        ),
        DoubtfulStudy(
            testDescription: "over a degree and a town",
            tail: [
                "EDUCATION", "2013 – 2016", "Diploma in Welding", "HOLLOWAY TRUST", "BSc Geology — Northbridge",
                "2009 – 2013",
            ],
            degrees: ["Diploma in Welding", "BSc Geology"], schools: [nil, "HOLLOWAY TRUST"],
            places: [nil, "Northbridge"], checks: [nil, .headingUnsure]
        ),
        DoubtfulStudy(
            testDescription: "over a school and its subject",
            tail: [
                "EDUCATION", "2013 – 2016", "Diploma in Welding", "HOLLOWAY TRUST",
                "University of Northbridge — Geology", "2009 – 2013",
            ],
            degrees: ["Diploma in Welding", nil], schools: ["University of Northbridge", nil],
            places: ["HOLLOWAY TRUST", nil], checks: [.entryBoundsUnsure, .entryBoundsUnsure]
        ),
    ]

    @Test("A line in capitals the line below does not settle stays where main reads it, in a study to be checked", arguments: doubtfulStudies)
    func doubtfulHeadingStaysInItsStudy(_ row: DoubtfulStudy) throws {
        let text = Self.doubtfulCV(["2016 – 2020", "Technician — Marlow Studio", "• Serviced boilers."], after: row.tail)
        #expect(!kinds(text).contains(.unknown), "\(kinds(text))")
        let result = try importText(text)
        let studies = result.cv.education
        #expect(studies.map(\.degree?.value) == row.degrees, "\(studies.map { [$0.degree?.value, $0.school?.value] })")
        #expect(studies.map(\.school?.value) == row.schools, "\(studies.map { [$0.degree?.value, $0.school?.value] })")
        #expect(studies.map(\.location?.value) == row.places, "\(studies.map(\.location?.value))")
        #expect(studies.map(\.check) == row.checks, "\(studies.map(\.check))")
        for (index, check) in row.checks.enumerated() {
            let listed = result.reviewList.contains { $0.field == .education(index) && $0.reason == .headingUnsure }
            #expect(listed == (check == .headingUnsure), "study \(index): \(result.reviewList.map { ($0.field, $0.reason) })")
        }
        #expect(!result.unplaced.contains { $0.heading == "HOLLOWAY TRUST" }, "\(result.unplaced.map { ($0.heading, $0.text) })")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.describe(Coverage.lost(result)))")
    }

    @Test("A line in capitals after the studies, over an entry of its own, still opens a section")
    func unknownHeadingAfterTheStudies() throws {
        let text = [
            "Lena Okafor", "lena.okafor@example.com", "SUMMARY", "Field technician.", "EXPERIENCE",
            "2016 – 2020", "Technician — Marlow Studio", "• Serviced boilers.",
            "EDUCATION", "BSc Geology — University of Northbridge", "2009 – 2013",
            "SIDE PROJECTS", "Hive Monitor Kit — maker, solo", "SKILLS", "Welding",
        ].joined(separator: "\n")
        #expect(kinds(text).contains(.unknown), "\(kinds(text))")
        let result = try importText(text)
        let under = result.unplaced.filter { $0.heading == "SIDE PROJECTS" }.map(\.text).joined(separator: "\n")
        #expect(under.contains("Hive Monitor Kit — maker, solo"), "\(result.unplaced.map { ($0.heading, $0.text) })")
        #expect(result.cv.education.first?.location == nil, "\(result.cv.education.map(\.location?.value))")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.describe(Coverage.lost(result)))")
    }

    @Test("A line in capitals after the languages, over a bullet, still opens a section")
    func unknownHeadingAfterTheLanguages() throws {
        let text = Self.doubtfulCV(
            ["2016 – 2020", "Technician — Marlow Studio", "• Serviced boilers."], after: ["SIDE PROJECTS", "• Hive monitor kit"]
        )
        #expect(kinds(text).contains(.unknown), "\(kinds(text))")
        let result = try importText(text)
        let under = result.unplaced.filter { $0.heading == "SIDE PROJECTS" }.map(\.text).joined(separator: "\n")
        #expect(under.contains("Hive monitor kit"), "\(result.unplaced.map { ($0.heading, $0.text) })")
        #expect(Coverage.lost(result).isEmpty, "\(Coverage.describe(Coverage.lost(result)))")
    }
}
