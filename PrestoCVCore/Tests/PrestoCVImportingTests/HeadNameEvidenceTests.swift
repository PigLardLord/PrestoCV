import Foundation
import Testing
@testable import PrestoCVImporting

/// A line drawn on a page: its words at one place, in one type.
struct DrawnLine: Sendable {
    let text: String
    let x: Double
    let y: Double
    let size: Double
    let bold: Bool

    init(_ text: String, x: Double = 50, y: Double, size: Double = 10, bold: Bool = false) {
        self.text = text
        self.x = x
        self.y = y
        self.size = size
        self.bold = bold
    }
}

/// A head drawn with a marked line: what marks it, where it stands, and whether a line in the shape of a name comes
/// before it. A second column stands at x 400, past the middle of the page, so that the column on the left, with the
/// largest type of the page or as large as the other, is read first.
struct MarkedHead: Sendable, CustomTestStringConvertible {
    enum Mark: String, Sendable { case heading = "a heading of the first level", largest = "the largest type", bold }
    enum Place: String, Sendable { case before = "before the contacts", after = "after them", beside = "in another column" }

    let mark: Mark
    let place: Place
    let underAName: Bool
    let lines: [DrawnLine]
    /// The name is read with no check.
    let isNameSure: Bool

    var testDescription: String { "\(mark.rawValue), \(place.rawValue), \(underAName ? "under a name" : "with no name before it")" }
}

/// The name of a head when a line after its name and contacts is marked (#301): such a line gains no evidence of the
/// name, whatever marks it and whatever column it stands in; contacts alone, with no name before them, take no evidence
/// away. The PDFs are drawn as their reader hands their words over.
@Suite("The evidence of the name after the head's name and contacts")
struct HeadNameEvidenceTests {

    /// The experience under the head, in the left column, its heading larger than the head's lines of 10 points.
    private static func experience(headingSize: Double = 12) -> [DrawnLine] {
        [DrawnLine("EXPERIENCE", y: 146, size: headingSize, bold: true), DrawnLine("2019 - 2021 Nurse, Northgate Hospital", y: 166)]
    }

    private func importing(_ lines: [DrawnLine]) async throws -> ImportResult {
        var sketch = PageSketch()
        for line in lines { sketch.put(line.text, x: line.x, y: line.y, size: line.size, bold: line.bold) }
        return try await ImportCV(pdfReader: ScriptedPDFReader(layout: .pages([sketch.page])), limits: .standard).importPDF(Data([1]))
    }

    private func importing(text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    // MARK: The findings

    @Test("A section's heading in larger type than the name, after the name and its contacts, is not the name: the name stays, to be checked, and the sentence under the heading is no title")
    func largerHeadingAfterTheContacts() async throws {
        let result = try await importing([
            DrawnLine("Anna Weber", y: 40, size: 14, bold: true), DrawnLine("person@example.com", y: 62),
            DrawnLine("Community Outreach", y: 90, size: 16, bold: true), DrawnLine("Built a scheduling application", y: 112),
        ] + Self.experience())
        let person = result.cv.person
        #expect(person.name?.value == "Anna Weber")
        #expect(person.name?.check == .nameByPosition)
        #expect(person.title?.value == "Community Outreach")
        #expect(person.title?.check == .titleByPosition)
        #expect(person.location == nil)
        #expect(person.email?.value.value == "person@example.com")
        #expect(result.unplaced.map(\.text) == ["Built a scheduling application"])
    }

    @Test("A heading of the first level in a column beside the name, under the e-mail, is not the name, whatever its shape", arguments: [
        "Leeds, United Kingdom", "+44 20 7946 0000",
    ])
    func headingBesideTheName(under: String) async throws {
        let result = try await importing([
            DrawnLine("Anna Weber", y: 40, size: 14, bold: true), DrawnLine(under, y: 62),
            DrawnLine("person@example.com", x: 400, y: 40), DrawnLine("# Community Outreach", x: 400, y: 62),
            DrawnLine("Built a scheduling application", x: 400, y: 84),
        ] + Self.experience())
        #expect(result.document.blocks.contains { $0.column == 1 }, "\(under): two columns")
        let person = result.cv.person
        // The name's own type marks it, so it stays sure
        #expect(person.name?.value == "Anna Weber", "\(under)")
        #expect(person.name?.check == nil, "\(under)")
        #expect(person.title == nil, "\(under)")
        #expect(person.email?.value.value == "person@example.com", "\(under)")
        #expect(result.unplaced.map(\.text).contains("Built a scheduling application"), "\(under)")
        if under.first == "L" {
            #expect(person.location?.value == under && person.location?.check == nil)
            #expect(result.unplaced.map(\.text) == ["Community Outreach", "Built a scheduling application"])
        } else {
            // The price: a lone line next to the contacts can still be read as the place, to be checked
            #expect(person.location == nil || person.location?.check == .locationByPosition)
        }
    }

    // MARK: The table

    static let heads: [MarkedHead] = {
        let job = experience()
        let email = "person@example.com"
        let built = "Built a scheduling application"
        return [
            MarkedHead(mark: .heading, place: .before, underAName: true, lines: [
                DrawnLine("Anna Weber", y: 40), DrawnLine("# Community Outreach", y: 56), DrawnLine(email, y: 72),
            ] + job, isNameSure: false),
            MarkedHead(mark: .heading, place: .before, underAName: false, lines: [
                DrawnLine("# Anna Weber", y: 40), DrawnLine(email, y: 56),
            ] + job, isNameSure: true),
            MarkedHead(mark: .heading, place: .after, underAName: true, lines: [
                DrawnLine("Anna Weber", y: 40), DrawnLine(email, y: 56), DrawnLine("# Community Outreach", y: 80), DrawnLine(built, y: 96),
            ] + job, isNameSure: false),
            MarkedHead(mark: .heading, place: .after, underAName: false, lines: [
                DrawnLine(email, y: 40), DrawnLine("# Anna Weber", y: 56), DrawnLine("Nurse", y: 72),
            ] + job, isNameSure: true),
            MarkedHead(mark: .heading, place: .beside, underAName: true, lines: [
                DrawnLine("Anna Weber", y: 40), DrawnLine("Leeds, United Kingdom", y: 62),
                DrawnLine(email, x: 400, y: 40), DrawnLine("# Community Outreach", x: 400, y: 62), DrawnLine(built, x: 400, y: 84),
            ] + job, isNameSure: false),
            MarkedHead(mark: .heading, place: .beside, underAName: false, lines: [
                DrawnLine(email, y: 40), DrawnLine("+44 20 7946 0000", y: 62),
                DrawnLine("# Anna Weber", x: 400, y: 40), DrawnLine("Nurse", x: 400, y: 62),
            ] + job, isNameSure: true),
            // A title printed small over the name, the name in larger type
            MarkedHead(mark: .largest, place: .before, underAName: true, lines: [
                DrawnLine("Senior Nurse", y: 40), DrawnLine("Anna Weber", y: 56, size: 18, bold: true), DrawnLine(email, y: 84),
            ] + job, isNameSure: true),
            MarkedHead(mark: .largest, place: .before, underAName: false, lines: [
                DrawnLine("Anna Weber", y: 40, size: 18, bold: true), DrawnLine(email, y: 66),
            ] + job, isNameSure: true),
            MarkedHead(mark: .largest, place: .after, underAName: true, lines: [
                DrawnLine("Anna Weber", y: 40, size: 14, bold: true), DrawnLine(email, y: 62),
                DrawnLine("Community Outreach", y: 90, size: 16, bold: true), DrawnLine(built, y: 112),
            ] + job, isNameSure: false),
            MarkedHead(mark: .largest, place: .after, underAName: false, lines: [
                DrawnLine(email, y: 40), DrawnLine("Anna Weber", y: 56, size: 18, bold: true), DrawnLine("Nurse", y: 84),
            ] + job, isNameSure: true),
            MarkedHead(mark: .largest, place: .beside, underAName: true, lines: [
                DrawnLine("Anna Weber", y: 40, size: 16, bold: true), DrawnLine("Leeds, United Kingdom", y: 62),
                DrawnLine(email, x: 400, y: 40), DrawnLine("Community Outreach", x: 400, y: 62, size: 16, bold: true),
                DrawnLine(built, x: 400, y: 84),
            ] + job, isNameSure: true),
            // The experience's heading as large as the name keeps the column of the contacts first
            MarkedHead(mark: .largest, place: .beside, underAName: false, lines: [
                DrawnLine(email, y: 40), DrawnLine("+44 20 7946 0000", y: 62),
                DrawnLine("Anna Weber", x: 400, y: 40, size: 16, bold: true), DrawnLine("Nurse", x: 400, y: 62),
            ] + experience(headingSize: 16), isNameSure: true),
            MarkedHead(mark: .bold, place: .before, underAName: true, lines: [
                DrawnLine("Anna Weber", y: 40), DrawnLine("Community Outreach", y: 56, bold: true), DrawnLine(email, y: 72),
            ] + job, isNameSure: false),
            MarkedHead(mark: .bold, place: .before, underAName: false, lines: [
                DrawnLine("Anna Weber", y: 40, bold: true), DrawnLine(email, y: 56),
            ] + job, isNameSure: true),
            MarkedHead(mark: .bold, place: .after, underAName: true, lines: [
                DrawnLine("Anna Weber", y: 40), DrawnLine(email, y: 56), DrawnLine("Community Outreach", y: 80, bold: true), DrawnLine(built, y: 96),
            ] + job, isNameSure: false),
            MarkedHead(mark: .bold, place: .after, underAName: false, lines: [
                DrawnLine(email, y: 40), DrawnLine("Anna Weber", y: 56, bold: true), DrawnLine("Nurse", y: 72),
            ] + job, isNameSure: true),
            MarkedHead(mark: .bold, place: .beside, underAName: true, lines: [
                DrawnLine("Anna Weber", y: 40), DrawnLine("Leeds, United Kingdom", y: 62),
                DrawnLine(email, x: 400, y: 40), DrawnLine("Community Outreach", x: 400, y: 62, bold: true), DrawnLine(built, x: 400, y: 84),
            ] + job, isNameSure: false),
            MarkedHead(mark: .bold, place: .beside, underAName: false, lines: [
                DrawnLine(email, y: 40), DrawnLine("+44 20 7946 0000", y: 62),
                DrawnLine("Anna Weber", x: 400, y: 40, bold: true), DrawnLine("Nurse", x: 400, y: 62),
            ] + job, isNameSure: true),
        ]
    }()

    @Test("The name of a head with a marked line, by what marks the line, where it stands and whether a name comes before it", arguments: heads)
    func markedHead(head: MarkedHead) async throws {
        let result = try await importing(head.lines)
        if head.place == .beside {
            #expect(result.document.blocks.contains { $0.column == 1 }, "two columns")
        }
        let person = result.cv.person
        #expect(person.name?.value == "Anna Weber")
        #expect(person.name?.check == (head.isNameSure ? nil : .nameByPosition))
        #expect(person.email?.value.value == "person@example.com")
        // The sentence under a marked heading is never the title
        #expect(person.title?.value != "Built a scheduling application")
    }

    // MARK: Text

    @Test("A line after the name and its contacts, plain or in bold, gains no evidence of the name from a title under it", arguments: [
        "\n\nCommunity Outreach", "\n\n**Community Outreach**", "\nCommunity Outreach",
    ])
    func lineAfterTheContacts(line: String) throws {
        let result = try importing(text:
            "Anna Weber\nperson@example.com\(line)\nBuilt a scheduling application\n\n## Experience\n2019 - 2021 Nurse, Northgate Hospital"
        )
        let person = result.cv.person
        #expect(person.name?.value == "Anna Weber", "\(line)")
        #expect(person.name?.check == .nameByPosition, "\(line)")
        #expect(person.title?.value == "Community Outreach", "\(line)")
        #expect(person.title?.check == .titleByPosition, "\(line)")
        #expect(person.location == nil, "\(line)")
        #expect(result.unplaced.map(\.text) == ["Built a scheduling application"], "\(line)")
    }

    @Test("The price of a line after a title or a place in the shape of a name and the contacts: it gains no evidence, and the first line is the name, to be checked, the later one its title")
    func nameAfterAPlaceAndTheContacts() async throws {
        for before in ["Greater Wexby", "Senior Nurse"] {
            let result = try importing(text: "\(before)\nperson@example.com\nAnna Weber\nNurse")
            #expect(result.cv.person.name?.value == before, "\(before)")
            #expect(result.cv.person.name?.check == .nameByPosition, "\(before)")
            #expect(result.cv.person.title?.value == "Anna Weber", "\(before)")
            #expect(result.cv.person.title?.check == .titleByPosition, "\(before)")
        }
        // In the largest type too, on the line of a place and the contacts
        let drawn = try await importing([
            DrawnLine("Greater Wexby | person@example.com", y: 40), DrawnLine("Anna Weber", y: 64, size: 18, bold: true), DrawnLine("Nurse", y: 88),
        ] + Self.experience())
        #expect(drawn.cv.person.name?.value == "Greater Wexby")
        #expect(drawn.cv.person.name?.check == .nameByPosition)
        // Contacts alone, with no name before them, take no evidence away
        let known = try await importing([
            DrawnLine("London | person@example.com", y: 40), DrawnLine("Anna Weber", y: 64, size: 18, bold: true), DrawnLine("Nurse", y: 88),
        ] + Self.experience())
        #expect(known.cv.person.name?.value == "Anna Weber")
        #expect(known.cv.person.name?.check == nil)
    }

    @Test("The price before the contacts: a section's heading in larger type than the name, under it, is read as the name")
    func largerHeadingBeforeTheContacts() async throws {
        let result = try await importing([
            DrawnLine("Anna Weber", y: 40), DrawnLine("Community Outreach", y: 56, size: 16, bold: true),
            DrawnLine("Built a scheduling application", y: 80), DrawnLine("person@example.com", y: 96),
        ] + Self.experience())
        #expect(result.cv.person.name?.value == "Community Outreach")
    }
}
