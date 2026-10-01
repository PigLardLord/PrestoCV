import Testing
import PrestoCVDomain
import PrestoCVCoreTestSupport

/// A text of `bytes` UTF-8 bytes.
func text(bytes: Int) -> String { String(repeating: "x", count: bytes) }

/// Every section, in the order the CV reports them.
let allSections: [CVSectionKind] = [.experiences, .education, .skills, .languages, .certifications, .profiles, .interests]

/// Sections of `count` entries each for the listed sections, and none for the others.
func entries(in listed: [CVSectionKind], count: Int) -> CVSections {
    let link = FixtureCV.full().sections.profiles[0].link
    var result = CVSections()
    for section in listed {
        switch section {
        case .experiences: result.experiences = (0..<count).map { Experience(role: "r\($0)", company: "c") }
        case .education: result.education = (0..<count).map { Education(degree: "d\($0)", school: "s") }
        case .skills: result.skills = (0..<count).map { Skill(name: "s\($0)") }
        case .languages: result.languages = (0..<count).map { LanguageSkill(language: "l\($0)", proficiency: .b1) }
        case .certifications: result.certifications = (0..<count).map { Certification(name: "c\($0)", issuer: "i") }
        case .profiles: result.profiles = (0..<count).map { ProfileLink(platform: "p\($0)", link: link) }
        case .interests: result.setInterests((0..<count).map { "i\($0)" })
        }
    }
    return result
}

func limitCV(_ details: PersonalDetails = PersonalDetails(fullName: "Ada"), title: String = "", sections: CVSections = CVSections()) -> CV {
    CV(id: FixtureCV.full().id, title: title, personal: details, sections: sections)
}

/// Texts the document does not carry: identifiers and the language tag. Every other text counts toward the total.
private let uncountedTexts: Set<String> = ["design.design", "design.palette", "design.fonts", "language.tag"]

/// The UTF-8 bytes of every text a CV holds, found by Mirror: the title and the value objects' text included.
func countedBytes(_ cv: CV) -> Int {
    texts(of: cv).filter { !uncountedTexts.contains($0.key) }.values.reduce(0) { $0 + $1.utf8.count }
}

/// The fixture, with skills added until its texts total `target` bytes, each skill within the limit for one text.
func limitCV(totalling target: Int) -> CV {
    var result = FixtureCV.full()
    var padded = result.sections
    var remaining = target - countedBytes(result)
    while remaining > 0 {
        let size = min(remaining, CVLimits.maxTextBytes)
        padded.skills.append(Skill(name: text(bytes: size)))
        remaining -= size
    }
    result.setSections(padded)
    return result
}

@Suite("R6 · size limits")
struct CVLimitsTests {
    @Test("the limits are at or below the document validator's: 16,384 bytes a text, 262,144 in all, 200 entries")
    func limitsAreWithinTheDocumentBounds() {
        #expect(CVLimits.maxTextBytes <= 16_384 && CVLimits.maxTotalTextBytes <= 262_144 && CVLimits.maxEntriesPerSection <= 200)
        #expect(CVLimits.maxTextBytes > 0 && CVLimits.maxTotalTextBytes >= CVLimits.maxTextBytes)
    }

    @Test("the names of the fields, sections and blockers can be collected: they are hashable, and an entry's field is nested in the text field")
    func namesAreHashable() {
        let description: CVTextField.ExperienceText = .description
        let blockers: Set<SaveBlocker> = [.missingName, .limit(.tooMuchText), .limit(.tooManyEntries(.skills)),
                                          .limit(.textTooLong(.experience(index: 1, description))), .limit(.textTooLong(.experience(index: 1, .description)))]
        #expect(blockers.count == 4)
        #expect(Set<CVSectionKind>(allSections).count == allSections.count)
        #expect(Set(textFields.map(\.reported)).count == textFields.count)
    }

    @Test("a CV within the limits has no violation, and neither has an empty one")
    func withinLimits() {
        #expect(FixtureCV.full().limitViolation == nil)
        #expect(CV(id: FixtureCV.full().id).limitViolation == nil)
    }

    @Test("a text at the limit is accepted and one byte more is reported with its field; a text is never cut", arguments: textFields)
    func textBoundary(_ field: TextFieldSpec) {
        var draft = TextDraft(FixtureCV.full())
        let atLimit = text(bytes: CVLimits.maxTextBytes)
        draft[keyPath: field.key] = atLimit
        let fits = TextEntry.initialiser.cv(from: draft)
        #expect(fits.limitViolation == nil)
        #expect(texts(of: fits)[field.path] == atLimit)

        draft[keyPath: field.key] = atLimit + "x"
        let over = TextEntry.initialiser.cv(from: draft)
        #expect(over.limitViolation == .textTooLong(field.reported))
        #expect(texts(of: over)[field.path] == atLimit + "x")
    }

    @Test("a title that is renamed past the limit is reported")
    func renamedTitle() {
        var renamed = FixtureCV.full()
        renamed.rename(text(bytes: CVLimits.maxTextBytes + 1))
        #expect(renamed.limitViolation == .textTooLong(.title))
    }

    @Test("a text is measured in UTF-8 bytes, not characters",
          arguments: [("\u{00E9}", 5_000, true), ("\u{00E9}", 5_001, false), ("e\u{0301}", 3_333, true), ("e\u{0301}", 3_334, false), ("🙂", 2_500, true), ("🙂", 2_501, false)])
    func bytesNotCharacters(unit: String, repeats: Int, fits: Bool) {
        let summary = limitCV(PersonalDetails(fullName: "Ada", summary: String(repeating: unit, count: repeats)))
        #expect((summary.limitViolation == nil) == fits)
        #expect(fits || summary.limitViolation == .textTooLong(.summary))
    }

    @Test("a text is measured as it is held, after normalisation")
    func measuredAfterNormalisation() {
        let atLimit = text(bytes: CVLimits.maxTextBytes)
        #expect(limitCV(PersonalDetails(fullName: "Ada", summary: atLimit + "\u{0000}\u{202E}")).limitViolation == nil)
        #expect(limitCV(PersonalDetails(fullName: "Ada", summary: text(bytes: CVLimits.maxTextBytes - 1) + "\r\n")).limitViolation == nil)
        #expect(limitCV(PersonalDetails(fullName: "Ada", location: text(bytes: CVLimits.maxTextBytes - 1) + "\r\n")).limitViolation == nil)
        #expect(limitCV(PersonalDetails(fullName: "Ada", summary: atLimit + "\r\n")).limitViolation == .textTooLong(.summary))
    }

    @Test("every section is known to the limit: a section added to the sections must be added to the table")
    func sectionTableIsComplete() {
        #expect(Mirror(reflecting: CVSections()).children.count == allSections.count)
    }

    @Test("a section of 200 entries is accepted and one more is reported with its section", arguments: allSections)
    func entryBoundary(_ section: CVSectionKind) {
        #expect(limitCV(sections: entries(in: [section], count: CVLimits.maxEntriesPerSection)).limitViolation == nil)
        #expect(limitCV(sections: entries(in: [section], count: CVLimits.maxEntriesPerSection + 1)).limitViolation == .tooManyEntries(section))
    }

    @Test("texts that each fit but together pass the total are reported as too much text; the total is exact")
    func totalBoundary() {
        let atLimit = limitCV(totalling: CVLimits.maxTotalTextBytes)
        #expect(countedBytes(atLimit) == CVLimits.maxTotalTextBytes)
        #expect(atLimit.limitViolation == nil)
        let over = limitCV(totalling: CVLimits.maxTotalTextBytes + 1)
        #expect(countedBytes(over) == CVLimits.maxTotalTextBytes + 1)
        #expect(over.limitViolation == .tooMuchText)
    }

    @Test("with two texts too long, the first in the CV's order is reported",
          arguments: zip(textFields, textFields.dropFirst()).map { OrderedPair(first: $0, second: $1) })
    func firstTextTooLong(_ pair: OrderedPair) {
        var draft = TextDraft(FixtureCV.full())
        draft[keyPath: pair.second.key] = "y" + text(bytes: CVLimits.maxTextBytes)
        draft[keyPath: pair.first.key] = text(bytes: CVLimits.maxTextBytes + 1)
        #expect(TextEntry.initialiser.cv(from: draft).limitViolation == .textTooLong(pair.first.reported))
    }

    @Test("with two sections too long, the first in the CV's order is reported",
          arguments: zip(allSections, allSections.dropFirst()).map { SectionPair(first: $0, second: $1) })
    func firstSectionTooLong(_ pair: SectionPair) {
        let both = limitCV(sections: entries(in: [pair.second, pair.first], count: CVLimits.maxEntriesPerSection + 1))
        #expect(both.limitViolation == .tooManyEntries(pair.first))
    }

    @Test("a text too long comes before too many entries, and too many entries before too much text")
    func reportingOrder() {
        let long = text(bytes: CVLimits.maxTextBytes + 1)
        #expect(limitCV(title: long, sections: entries(in: [.skills], count: 201)).limitViolation == .textTooLong(.title))
        var heavy = entries(in: [.skills], count: 201)
        heavy.skills = heavy.skills.map { Skill(name: $0.name + text(bytes: 1_300)) }
        let manyAndLarge = limitCV(sections: heavy)
        #expect(countedBytes(manyAndLarge) > CVLimits.maxTotalTextBytes)
        #expect(manyAndLarge.limitViolation == .tooManyEntries(.skills))
    }

    @Test("a CV over a limit cannot be saved, the blocker says which, and a missing name comes first")
    func saveBlockerIsTheWholeRule() {
        let long = text(bytes: CVLimits.maxTextBytes + 1)
        let withName = limitCV(PersonalDetails(fullName: "Ada", summary: long))
        #expect(!withName.canBeSaved && withName.saveBlocker == .limit(.textTooLong(.summary)))
        let anonymous = limitCV(PersonalDetails(summary: long), sections: entries(in: [.skills], count: 201))
        #expect(!anonymous.canBeSaved && anonymous.saveBlocker == .missingName)
        #expect(FixtureCV.full().canBeSaved && FixtureCV.full().saveBlocker == nil)
    }

    @Test("every text, section and total violation blocks the save with that violation", arguments: blockedCVs)
    func blockerCarriesTheViolation(_ test: BlockedCV) {
        #expect(test.cv.limitViolation == test.violation)
        #expect(test.cv.saveBlocker == .limit(test.violation) && !test.cv.canBeSaved)
    }
}

struct BlockedCV: CustomTestStringConvertible, Sendable {
    let name: String, cv: CV, violation: CVLimitViolation
    var testDescription: String { name }
}

/// One CV per kind of violation: a text too long, a section with too many entries, and too much text in all.
let blockedCVs: [BlockedCV] = {
    var blocked: [BlockedCV] = []
    var draft = TextDraft(FixtureCV.full())
    draft.personal.summary = text(bytes: CVLimits.maxTextBytes + 1)
    blocked.append(BlockedCV(name: "a text", cv: TextEntry.initialiser.cv(from: draft), violation: .textTooLong(.summary)))
    blocked.append(BlockedCV(name: "a section", cv: limitCV(sections: entries(in: [.profiles], count: CVLimits.maxEntriesPerSection + 1)),
                             violation: .tooManyEntries(.profiles)))
    blocked.append(BlockedCV(name: "the total", cv: limitCV(totalling: CVLimits.maxTotalTextBytes + 1), violation: .tooMuchText))
    return blocked
}()

struct OrderedPair: CustomTestStringConvertible, Sendable {
    let first: TextFieldSpec, second: TextFieldSpec
    var testDescription: String { "\(first.path) before \(second.path)" }
}

struct SectionPair: CustomTestStringConvertible, Sendable {
    let first: CVSectionKind, second: CVSectionKind
    var testDescription: String { "\(first) before \(second)" }
}
