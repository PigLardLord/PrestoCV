import Testing
import Foundation
import PrestoCVDomain
import PrestoCVCoreTestSupport

/// What enters a CV: the title, the personal details and the sections, as an editor or a mapper hands them over.
struct TextDraft {
    var title: String, personal: PersonalDetails, sections: CVSections
    let design: DesignChoice?, language: DocumentLanguage?

    init(_ cv: CV) { title = cv.title; personal = cv.personal; sections = cv.sections; design = cv.design; language = cv.language }

    var firstInterest: String {
        get { sections.interests.first ?? "" }
        set { sections.setInterests([newValue] + sections.interests.dropFirst()) }
    }
    var secondInterest: String {
        get { sections.interests.dropFirst().first ?? "" }
        set { sections.setInterests([sections.interests.first ?? ""] + [newValue]) }
    }
}

/// A text of a CV: where Mirror finds it, its kind, how a limit reports it, and how to put a text into a draft.
struct TextFieldSpec: CustomTestStringConvertible, Sendable {
    let path: String, multiLine: Bool
    /// How the CV reports this field when its text is too long.
    let reported: CVTextField
    let key: WritableKeyPath<TextDraft, String> & Sendable
    var testDescription: String { path }
    /// Carries a bidirectional override, a NUL, a CR LF, a tab and a tag character, and the path, so no two fields hold the same text.
    var hostile: String { "\u{202E}\(path)\u{0000}\r\ny\tz\u{E0041}" }
    /// What the field's kind makes of `hostile`.
    var expected: String { multiLine ? "\(path)\ny z" : "\(path) y z" }
}

let textFields: [TextFieldSpec] = {
    var fields: [TextFieldSpec] = []
    func single(_ path: String, _ reported: CVTextField, _ key: WritableKeyPath<TextDraft, String> & Sendable) {
        fields.append(TextFieldSpec(path: path, multiLine: false, reported: reported, key: key))
    }
    func multi(_ path: String, _ reported: CVTextField, _ key: WritableKeyPath<TextDraft, String> & Sendable) {
        fields.append(TextFieldSpec(path: path, multiLine: true, reported: reported, key: key))
    }
    single("title", .title, \.title)
    single("personal.fullName", .fullName, \.personal.fullName)
    single("personal.professionalTitle", .professionalTitle, \.personal.professionalTitle)
    single("personal.location", .location, \.personal.location)
    multi("personal.summary", .summary, \.personal.summary)
    single("sections.experiences[0].role", .experience(index: 0, .role), \.sections.experiences[0].role)
    single("sections.experiences[0].company", .experience(index: 0, .company), \.sections.experiences[0].company)
    single("sections.experiences[0].location", .experience(index: 0, .location), \.sections.experiences[0].location)
    multi("sections.experiences[0].description", .experience(index: 0, .description), \.sections.experiences[0].description)
    single("sections.education[0].degree", .education(index: 0, .degree), \.sections.education[0].degree)
    single("sections.education[0].school", .education(index: 0, .school), \.sections.education[0].school)
    multi("sections.education[0].description", .education(index: 0, .description), \.sections.education[0].description)
    single("sections.skills[0].name", .skill(index: 0), \.sections.skills[0].name)
    single("sections.skills[1].name", .skill(index: 1), \.sections.skills[1].name)
    single("sections.languages[0].language", .language(index: 0), \.sections.languages[0].language)
    single("sections.languages[1].language", .language(index: 1), \.sections.languages[1].language)
    single("sections.certifications[0].name", .certification(index: 0, .name), \.sections.certifications[0].name)
    single("sections.certifications[0].issuer", .certification(index: 0, .issuer), \.sections.certifications[0].issuer)
    multi("sections.certifications[0].description", .certification(index: 0, .description), \.sections.certifications[0].description)
    single("sections.profiles[0].platform", .profile(index: 0), \.sections.profiles[0].platform)
    single("sections.interests[0]", .interest(index: 0), \.firstInterest)
    single("sections.interests[1]", .interest(index: 1), \.secondInterest)
    return fields
}()

/// Texts that are validated value objects, or identifiers: the rule does not touch them.
let validatedTexts: Set<String> = [
    "personal.email.value", "personal.phone.value", "personal.website.value", "sections.certifications[0].link.value",
    "sections.profiles[0].link.value", "design.design", "design.palette", "design.fonts", "language.tag",
]

/// Every string a value holds, by the path Mirror finds it at: `sections.experiences[0].role`.
func texts(of value: Any, path: String = "") -> [String: String] {
    if let text = value as? String { return [path: text] }
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional { return mirror.children.first.map { texts(of: $0.value, path: path) } ?? [:] }
    var found: [String: String] = [:]
    for (index, child) in mirror.children.enumerated() {
        let name = child.label.map { path.isEmpty ? $0 : path + "." + $0 } ?? path + "[\(index)]"
        found.merge(texts(of: child.value, path: name)) { first, _ in first }
    }
    return found
}

/// The ways text enters a CV, and the fields each one governs. A new method on `CV` that sets text must go through
/// `TextRule` and be added here, or the coverage test cannot see it.
enum TextEntry: String, CaseIterable, Sendable, CustomTestStringConvertible {
    case initialiser, storedInitialiser, rename, setPersonalDetails, setSections
    var testDescription: String { rawValue }

    func covers(_ field: TextFieldSpec) -> Bool {
        switch self {
        case .initialiser, .storedInitialiser: true
        case .rename: field.path == "title"
        case .setPersonalDetails: field.path.hasPrefix("personal.")
        case .setSections: field.path.hasPrefix("sections.")
        }
    }

    func cv(from draft: TextDraft) -> CV {
        let base = FixtureCV.full()
        switch self {
        case .initialiser:
            return CV(id: base.id, title: draft.title, personal: draft.personal, sections: draft.sections, design: draft.design, language: draft.language)
        case .storedInitialiser:
            return CV(id: base.id, revision: 4, createdAt: Date(timeIntervalSince1970: 1_700_000_000), updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
                      title: draft.title, personal: draft.personal, sections: draft.sections, design: draft.design, language: draft.language)
        case .rename:
            var cv = base; cv.rename(draft.title); return cv
        case .setPersonalDetails:
            var cv = base; cv.setPersonalDetails(draft.personal); return cv
        case .setSections:
            var cv = base; cv.setSections(draft.sections); return cv
        }
    }
}

struct TextEntryCase: CustomTestStringConvertible, Sendable {
    let entry: TextEntry, field: TextFieldSpec
    var testDescription: String { "\(entry): \(field.path)" }
}

private let entryCases: [TextEntryCase] = TextEntry.allCases.flatMap { entry in textFields.filter(entry.covers).map { TextEntryCase(entry: entry, field: $0) } }

@Suite("CV text enters normalised")
struct CVTextTests {
    @Test("the table of text fields lists every string a CV holds, so a field added later must be classified")
    func tableListsEveryText() {
        let found = Set(texts(of: FixtureCV.full()).keys)
        #expect(found == Set(textFields.map(\.path)).union(validatedTexts), "unlisted: \(found.subtracting(Set(textFields.map(\.path)).union(validatedTexts)).sorted())")
    }

    @Test("each text is normalised by its kind where it enters, and nothing else changes", arguments: entryCases)
    func normalisedOnEntry(_ test: TextEntryCase) {
        let fixture = FixtureCV.full()
        var draft = TextDraft(fixture)
        draft[keyPath: test.field.key] = test.field.hostile
        var expected = texts(of: fixture)
        expected[test.field.path] = test.field.expected
        #expect(texts(of: test.entry.cv(from: draft)) == expected)
    }

    @Test("every text at once, and a second pass through the setters changes nothing", arguments: TextEntry.allCases)
    func everyTextAtOnce(_ entry: TextEntry) {
        let fixture = FixtureCV.full()
        var draft = TextDraft(fixture)
        var expected = texts(of: fixture)
        for field in textFields where entry.covers(field) {
            draft[keyPath: field.key] = field.hostile
            expected[field.path] = field.expected
        }
        let cv = entry.cv(from: draft)
        #expect(texts(of: cv) == expected)
        var again = cv
        again.rename(cv.title); again.setPersonalDetails(cv.personal); again.setSections(cv.sections)
        #expect(again == cv)
    }

    @Test("a text that arrives clean is kept exactly")
    func cleanTextIsKept() {
        var cv = FixtureCV.full()
        cv.setPersonalDetails(cv.personal); cv.setSections(cv.sections); cv.rename(cv.title)
        #expect(cv == FixtureCV.full())
    }

    @Test("interests that differ only by a tab or a line break are one interest, and hidden characters leave nothing")
    func interestsAfterNormalisation() {
        let sections = CVSections(interests: ["a\tb", "a b", "A\nB", "chess", "\u{0001}", "\u{202E}", "ru\u{0000}nning"])
        #expect(sections.interests.count == 7)
        var cv = CV(id: FixtureCV.full().id, sections: sections)
        #expect(cv.sections.interests == ["a b", "chess", "running"])
        cv.setSections(CVSections(interests: ["x\ty", "X Y"]))
        #expect(cv.sections.interests == ["x y"])
    }

    @Test("a name made only of hidden characters is no name")
    func hiddenNameIsEmpty() {
        #expect(!CV(id: FixtureCV.full().id, personal: PersonalDetails(fullName: "\u{0001}\u{202E}\t")).canBeSaved)
        #expect(CV(id: FixtureCV.full().id, personal: PersonalDetails(fullName: "\u{202E}Ada")).personal.fullName == "Ada")
    }
}
