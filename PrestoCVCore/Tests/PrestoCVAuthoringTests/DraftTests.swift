import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

// MARK: Rows of the anchor table

private let engineer = Experience(role: "Engineer", company: "Analytical")
private let tutor = Experience(role: "Tutor", company: "Home")
private let lead = Experience(role: "Lead", company: "Next")                          // typed by the person, never imported
private let seniorEngineer = Experience(role: "Senior Engineer", company: "Analytical")  // `engineer` with its role edited
private let acmeEngineer = Experience(role: "Engineer", company: "Acme")             // the two rows below share a company
private let acmeTutor = Experience(role: "Tutor", company: "Acme")
private let seniorAcmeTutor = Experience(role: "Senior Tutor", company: "Acme")
private let seniorAcmeEngineer = Experience(role: "Senior Engineer", company: "Acme")
private let analyst = Experience(role: "Analyst", company: "Analytical")              // a new row at `engineer`'s company

private func role(_ index: Int) -> ValuePlace { .entry(.experienceRole, index: index) }
private func company(_ index: Int) -> ValuePlace { .entry(.experienceCompany, index: index) }

/// A CV whose experiences are `rows`, with `marks` set as imported.
private func imported(_ rows: [Experience], marks: [ValuePlace]) throws -> CV {
    var cv = CV(id: id1, personal: PersonalDetails(fullName: "Ada"), sections: CVSections(experiences: rows))
    try cv.setDraft(DraftBlock(origins: Dictionary(uniqueKeysWithValues: marks.map { ($0, .imported) }), notPlaced: []))
    return cv
}

/// One row of the anchor table: the experiences before and after one edit of the editor, and the marks that must be left.
struct AnchorCase: Sendable, CustomTestStringConvertible {
    let name: String
    let before: [Experience], marks: [ValuePlace]
    let after: [Experience], left: [ValuePlace]
    var testDescription: String { name }
}

/// `engineer` has its role and company marked; `tutor` only its role (the person typed its company).
let anchorTable: [AnchorCase] = [
    AnchorCase(name: "nothing changes", before: [engineer, tutor], marks: [role(0), company(0), role(1)],
               after: [engineer, tutor], left: [role(0), company(0), role(1)]),
    AnchorCase(name: "a value edited in place loses its mark; its row keeps the others", before: [engineer, tutor], marks: [role(0), company(0), role(1)],
               after: [seniorEngineer, tutor], left: [company(0), role(1)]),
    AnchorCase(name: "the first row deleted: the second keeps its marks at its new place", before: [engineer, tutor], marks: [role(0), company(0), role(1)],
               after: [tutor], left: [role(0)]),
    AnchorCase(name: "two rows swapped: each mark follows its row", before: [engineer, tutor], marks: [role(0), company(0), role(1)],
               after: [tutor, engineer], left: [role(0), role(1), company(1)]),
    AnchorCase(name: "a row inserted first: the others follow, the new row has no mark", before: [engineer, tutor], marks: [role(0), company(0), role(1)],
               after: [lead, engineer, tutor], left: [role(1), company(1), role(2)]),
    AnchorCase(name: "the last row replaced by a new one: the new row takes no mark of the old", before: [engineer, tutor], marks: [role(0), company(0), role(1)],
               after: [engineer, lead], left: [role(0), company(0)]),
    AnchorCase(name: "two equal rows unchanged keep every mark", before: [engineer, engineer], marks: [role(0), company(0), role(1)],
               after: [engineer, engineer], left: [role(0), company(0), role(1)]),
    AnchorCase(name: "two equal rows, one deleted: the one left keeps only the marks both had", before: [engineer, engineer], marks: [role(0), company(0), role(1)],
               after: [engineer], left: [role(0)]),
    AnchorCase(name: "two equal rows, one edited: the edited value loses its mark", before: [engineer, engineer], marks: [role(0), company(0), role(1), company(1)],
               after: [seniorEngineer, engineer], left: [company(0), role(1), company(1)]),
    AnchorCase(name: "a row copied: neither copy can be told from the other, so both lose their marks", before: [engineer], marks: [role(0), company(0)],
               after: [engineer, engineer], left: []),
    AnchorCase(name: "two rows swapped and both edited: neither new row can be told from the other's old row, so no mark moves", before: [acmeEngineer, acmeTutor], marks: [company(0)],
               after: [seniorAcmeTutor, seniorAcmeEngineer], left: []),
    AnchorCase(name: "a new row put first and the last deleted: the new row takes no mark of the row that moved on", before: [engineer, tutor], marks: [role(0), company(0), role(1)],
               after: [analyst, engineer], left: [role(1), company(1)]),
]

@Suite("ADR 0009 · the draft block of a CV")
struct DraftTests {
    // MARK: Re-anchoring

    @Test("each mark follows its row through an edit of the entries, and never points at another row", arguments: anchorTable)
    func anchors(row: AnchorCase) throws {
        var cv = try imported(row.before, marks: row.marks)
        var sections = cv.sections
        sections.experiences = row.after
        cv.setSections(sections)
        let left = cv.draft?.origins ?? [:]
        #expect(left == Dictionary(uniqueKeysWithValues: row.left.map { ($0, .imported) }), "\(row.name): \(left.keys.sorted { "\($0)" < "\($1)" })")
    }

    @Test("an edit of one section leaves the marks of the others and of the person where they were")
    func otherSectionsUntouched() {
        var cv = FixtureCV.full()
        let before = cv.draft
        var sections = cv.sections
        sections.experiences.insert(lead, at: 0)
        cv.setSections(sections)
        let moved = Set(EntryField.allCases.filter { "\($0)".hasPrefix("experience") }.map { ValuePlace.entry($0, index: 0) })
        let expected = (before?.origins ?? [:]).reduce(into: [ValuePlace: ValueOrigin]()) { result, mark in
            guard moved.contains(mark.key), case .entry(let field, let index) = mark.key else { result[mark.key] = mark.value; return }
            result[.entry(field, index: index + 1)] = mark.value
        }
        #expect(cv.draft?.origins == expected)
        #expect(cv.draft?.notPlaced == before?.notPlaced)
    }

    @Test("an interest deleted takes its mark with it; the next interest keeps its own at its new place")
    func interests() throws {
        var cv = CV(id: id1, personal: PersonalDetails(fullName: "Ada"), sections: CVSections(interests: ["Chess", "Running"]))
        try cv.setDraft(DraftBlock(origins: [.entry(.interest, index: 1): .imported], notPlaced: []))
        var sections = cv.sections
        sections.setInterests(["Running"])
        cv.setSections(sections)
        #expect(cv.draft?.origins == [.entry(.interest, index: 0): .imported])
    }

    @Test("when the last mark goes and nothing is left unplaced, the CV has no draft any more")
    func lastMarkGone() throws {
        var cv = try imported([engineer], marks: [role(0)])
        cv.setSections(CVSections())
        #expect(cv.draft == nil)
    }

    // MARK: Edited values

    @Test("an edited personal detail is no longer marked as imported; the details left as they were keep their marks")
    func editedPersonalDetail() {
        var cv = FixtureCV.full()
        var details = cv.personal
        details.fullName = "Ada King"
        details.email = nil
        cv.setPersonalDetails(details)
        #expect(cv.draft?.origins[.personal(.fullName)] == nil && cv.draft?.origins[.personal(.email)] == nil)
        #expect(cv.draft?.origins[.personal(.professionalTitle)] == .imported && cv.draft?.origins[.personal(.summary)] == .imported)
        #expect(cv.draft?.origins.count == FixtureCV.full().draft.map { $0.origins.count - 2 })
    }

    @Test("the same details set again keep every mark")
    func sameDetails() {
        var cv = FixtureCV.full()
        cv.setPersonalDetails(cv.personal)
        cv.setSections(cv.sections)
        #expect(cv.draft == FixtureCV.full().draft)
    }

    @Test("an edited entry value is no longer marked as imported; its other values and the other rows keep theirs")
    func editedEntryValue() {
        var cv = FixtureCV.full()
        var sections = cv.sections
        sections.skills[1].name = "Mercurial"
        cv.setSections(sections)
        #expect(cv.draft?.origins[.entry(.skillName, index: 1)] == nil)
        #expect(cv.draft?.origins[.entry(.skillName, index: 0)] == .imported)
    }

    // MARK: Carry

    @Test("holding the content of an editor's copy keeps this CV's draft, re-anchored to the new content")
    func holdingKeepsTheDraft() {
        let stored = FixtureCV.full()
        var details = stored.personal
        details.summary = "Builds careful software, and tests it."
        let edited = CV(id: stored.id, title: stored.title, personal: details, sections: stored.sections)
        let held = stored.holding(contentOf: edited)
        var expected = stored.draft?.origins ?? [:]
        expected[.personal(.summary)] = nil
        #expect(held.draft?.origins == expected)
        #expect(held.draft?.notPlaced == stored.draft?.notPlaced)
    }

    @Test("holding the content of an editor's copy with two rows swapped and both edited moves no mark to another row")
    func holdingSwappedAndEdited() throws {
        let stored = try imported([acmeEngineer, acmeTutor], marks: [company(0)])
        var sections = stored.sections
        sections.experiences = [seniorAcmeTutor, seniorAcmeEngineer]
        let edited = CV(id: stored.id, title: stored.title, personal: stored.personal, sections: sections)
        #expect(stored.holding(contentOf: edited).draft == nil)
    }

    @Test("a duplicate keeps the draft with the content")
    func duplicateKeepsTheDraft() {
        let cv = FixtureCV.full()
        let copy = cv.duplicated(as: CVID(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!), title: "Copy")
        #expect(copy.draft == cv.draft && copy.draft != nil)
    }

    // MARK: Invariants

    @Test("a mark must point inside the CV's sections; otherwise the draft is refused and the CV keeps the one it had",
          arguments: [ValuePlace.entry(.experienceRole, index: 1), .entry(.experienceRole, index: -1), .entry(.skillName, index: 0)])
    func placeOutsideTheSections(place: ValuePlace) {
        var cv = CV(id: id1, personal: PersonalDetails(fullName: "Ada"), sections: CVSections(experiences: [engineer]))
        #expect(throws: DraftError.placeOutsideSections) { try cv.setDraft(DraftBlock(origins: [place: .imported], notPlaced: [])) }
        #expect(cv.draft == nil)
    }

    @Test("an empty block is no draft at all")
    func emptyBlock() throws {
        var cv = FixtureCV.full()
        try cv.setDraft(DraftBlock(origins: [:], notPlaced: []))
        #expect(cv.draft == nil)
    }

    @Test("the draft is not content: a CV with a draft and nothing else cannot be saved")
    func notContent() throws {
        var cv = CV(id: id1)
        try cv.setDraft(DraftBlock(origins: [.personal(.fullName): .imported], notPlaced: [NotPlacedText(text: "Hobbies: chess", heading: nil)].compactMap { $0 }))
        #expect(cv.draft != nil)
        #expect(cv.saveCheck() == .notEnoughContent && !cv.canBeSaved)
    }

    // MARK: Not-placed text

    @Test("a not-placed text follows the text rule of a multi-line field, its heading that of a single-line one")
    func notPlacedTextRule() {
        let text = NotPlacedText(text: "One\r\ntwo\u{0}", heading: "Other\nnotes")
        #expect(text?.text == "One\ntwo" && text?.heading == "Other notes")
    }

    @Test("a not-placed text of white space only is nothing to keep; a blank heading is no heading")
    func blankNotPlacedText() {
        #expect(NotPlacedText(text: " \n\t ", heading: "Other") == nil)
        #expect(NotPlacedText(text: "Chess", heading: "  ")?.heading == nil)
        #expect(NotPlacedText(text: "Chess", heading: nil)?.heading == nil)
    }

    // MARK: Sizes

    @Test("the not-placed texts count in the size limits: one too long, too many, or too much together makes the CV too large",
          arguments: [
            [String(repeating: "a", count: CVLimits.maxTextCharacters + 1)],
            [String(repeating: "é", count: CVLimits.maxTextBytes / 2 + 1)],
            (0...CVLimits.maxEntriesPerSection).map { "Line \($0)" },
            Array(repeating: String(repeating: "a", count: CVLimits.maxTextCharacters), count: CVLimits.maxTotalTextBytes / CVLimits.maxTextCharacters + 1),
          ])
    func notPlacedSizes(texts: [String]) throws {
        var cv = named("Ada")
        try cv.setDraft(DraftBlock(origins: [:], notPlaced: texts.compactMap { NotPlacedText(text: $0, heading: nil) }))
        #expect(cv.saveCheck() == .cvTooLarge)
    }

    @Test("a heading over the text limit makes the CV too large")
    func longHeading() throws {
        var cv = named("Ada")
        let heading = String(repeating: "a", count: CVLimits.maxTextCharacters + 1)
        try cv.setDraft(DraftBlock(origins: [:], notPlaced: [NotPlacedText(text: "Chess", heading: heading)].compactMap { $0 }))
        #expect(cv.saveCheck() == .cvTooLarge)
    }

    @Test("a draft within the limits leaves the CV savable")
    func withinLimits() throws {
        var cv = named("Ada")
        let texts = (0..<CVLimits.maxEntriesPerSection).compactMap { NotPlacedText(text: "Line \($0)", heading: "Other") }
        try cv.setDraft(DraftBlock(origins: [.personal(.fullName): .imported], notPlaced: texts))
        #expect(cv.saveCheck() == .ok)
    }

    @Test("SaveCV refuses a CV whose draft is too large, and writes nothing")
    func saveRefusesALargeDraft() async throws {
        var cv = named("Ada")
        try cv.setDraft(DraftBlock(origins: [:], notPlaced: [NotPlacedText(text: String(repeating: "a", count: 10_001), heading: nil)].compactMap { $0 }))
        let repository = InMemoryCVRepository()
        await #expect(throws: AuthoringError.cvTooLarge) { _ = try await SaveCV(repository: repository)(cv) }
        #expect(try await repository.list().cvs.isEmpty)
    }
}
