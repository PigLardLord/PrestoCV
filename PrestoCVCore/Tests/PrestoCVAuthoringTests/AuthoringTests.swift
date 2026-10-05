import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

let id1 = CVID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
func named(_ name: String, id: CVID = id1) -> CV { CV(id: id, personal: PersonalDetails(fullName: name)) }

/// Addresses at and just past each length limit: the local part in bytes ("é" is two), a label in characters.
let emailLengthCases: [(String, Bool)] = {
    let domain = "@example.com"
    let local64 = String(repeating: "a", count: 64), local65 = String(repeating: "a", count: 65)
    let accented32 = String(repeating: "é", count: 32), accented33 = String(repeating: "é", count: 33)
    let label63 = "a" + String(repeating: "\u{0301}", count: 61) + "b", label64 = "a" + String(repeating: "\u{0301}", count: 62) + "b"
    return [(local64 + domain, true), (local65 + domain, false), (accented32 + domain, true), (accented33 + domain, false),
            ("ada@example." + label63, true), ("ada@example." + label64, false)]
}()

@Suite("RichDomain")
struct DomainTests {
    @Test("invalid values cannot exist; validators reject trailing newlines")
    func invariants() {
        #expect(SkillLevel(0) == nil && SkillLevel(6) == nil && SkillLevel(3) != nil)
        #expect(EmailAddress("a@b.") == nil && EmailAddress("ada@example.com") != nil)
        #expect(EmailAddress("ada@example.com\n")?.value == "ada@example.com")     // normalised, never stored with a newline
        #expect(!named("\n").canBeSaved && named("Ada").canBeSaved)
    }

    @Test("mixed precision is ordered by year when months are unknown")
    func mixedPrecision() throws {
        #expect(try Period.make(start: (2020, 5), end: (2020, nil), current: false) != nil)
        #expect(try Period.make(start: (2020, nil), end: (2020, 3), current: false) != nil)
        #expect(throws: PeriodError.endBeforeStart) { _ = try Period.make(start: (2020, 5), end: (2020, 3), current: false) }
    }

    @Test("one rule for every period shape", arguments: [
        (nil, nil, true, PeriodError.currentWithoutStart), (nil, (2020, nil), false, .endWithoutStart),
        ((2020, nil), (2021, nil), true, .currentWithEndDate), ((2020, 13), nil, false, .invalidDate), ((2020, nil), (9999, nil), false, .invalidDate),
    ] as [((Int, Int?)?, (Int, Int?)?, Bool, PeriodError)])
    func periodErrors(start: (Int, Int?)?, end: (Int, Int?)?, current: Bool, error: PeriodError) {
        #expect(throws: error) { _ = try Period.make(start: start.map { (year: $0.0, month: $0.1) }, end: end.map { (year: $0.0, month: $0.1) }, current: current) }
    }

    @Test("start without end and not current stays 'ended, date unknown'; no dates is no period")
    func unknownEnd() throws {
        #expect(try Period.make(start: (2019, nil), end: nil, current: false)?.end == .unknown)
        #expect(try Period.make(start: nil, end: nil, current: false) == nil)
    }

    @Test("the scheme is matched ignoring case, and keeps the case it was written in", arguments: ["HTTPS://example.org:443/x", "Http://example.org"])
    func schemeCase(raw: String) { #expect(WebLink(raw)?.value == raw) }

    @Test("default ports are accepted", arguments: ["https://example.org:443/x", "http://example.org:80"])
    func defaultPorts(raw: String) { #expect(WebLink(raw) != nil) }

    @Test("malformed addresses are rejected (final gate)",
          arguments: ["ada@example..com", "ada.@example.com", ".ada@example.com", "ada..b@example.com", "ada@example.com/path",
                      "ada@-example.com", "ada@example-.com", "ada@example.c", "ada@example.123", "ada@@example.com", "@example.com"])
    func malformedEmail(raw: String) { #expect(EmailAddress(raw) == nil) }

    @Test("a local part is at most 64 bytes and a domain label at most 63 characters, marks included", arguments: emailLengthCases)
    func emailLengths(raw: String, accepted: Bool) { #expect((EmailAddress(raw) != nil) == accepted) }

    @Test("every accepted link rebuilds itself from its value and stays within the limit (final gate)",
          arguments: ["https://ada.example", "http://example.org/path?q=1", "https://example.com/a b",
                      "https://example.com/" + String(repeating: "x", count: 2_000)])
    func linkRoundTrip(raw: String) {
        if let link = WebLink(raw) { #expect(WebLink(link.value) == link && link.value.utf8.count <= 2048) }
    }

    @Test("percent encoding cannot push a link past the limit (final gate)")
    func linkEncodedLength() { #expect(WebLink("https://example.com/" + String(repeating: "{", count: 1_000)) == nil) }

    @Test("international addresses are accepted, combining marks included; hidden characters and leading marks are not",
          arguments: [("josé@example.com", true), ("ada@bücher.example", true), ("किरण@example.com", true), ("jose\u{0301}@example.com", true),
                      ("ada@हिन्दी.भारत", true), ("\u{0301}ada@example.com", false), ("ada@\u{0301}example.com", false),
                      ("ada@example.e\u{0301}", false), ("ada@example.e\u{0301}\u{0302}", false), ("ada\u{0000}@example.com", false),
                      ("ada\u{200B}@example.com", false), ("ada@exa\u{202E}mple.com", false), ("ada@example\u{00A0}.com", false)])
    func emailCharacters(raw: String, accepted: Bool) { #expect((EmailAddress(raw) != nil) == accepted) }

    @Test("phone numbers keep the separators people write, and need at least three digits",
          arguments: ["+39 06 1234567", "(555) 123-4567", "06.123.4567", "112"])
    func phoneAccepted(raw: String) { #expect(PhoneNumber(raw)?.value == raw) }

    @Test("a phone number with letters, too few digits or an injected line is rejected",
          arguments: ["call me", "12", "+39 06\n1234", "123 ext. 4", "+", String(repeating: "1", count: 33)])
    func phoneRejected(raw: String) { #expect(PhoneNumber(raw) == nil) }

    @Test("links are http or https with a host, no credentials, stored as parsed",
          arguments: [("https://ada.example", "https://ada.example"), ("  http://example.org/path?q=1 ", "http://example.org/path?q=1")])
    func linksAccepted(raw: String, stored: String) { #expect(WebLink(raw)?.value == stored) }

    @Test("links that could mislead or execute are rejected",
          arguments: ["javascript:alert(1)", "mailto:ada@example.com", "https://example.org:8443/", "http://example.org:8080", "http://example.org:443", "//evil.example", "https://user:pw@example.org", "https://аpple.com",
                      "https://example.org/\u{202E}x", "https:\\\\example.org", "ftp://example.org", "https://" + String(repeating: "a", count: 2050)])
    func linksRejected(raw: String) { #expect(WebLink(raw) == nil) }

    @Test("document languages are BCP 47 tags in canonical case",
          arguments: [("it", "it"), ("PT-br", "pt-BR"), ("zh-hant-tw", "zh-Hant-TW"), ("es-419", "es-419")])
    func languageTags(raw: String, tag: String) { #expect(DocumentLanguage(raw)?.tag == tag) }

    @Test("malformed language tags are rejected, a script only before a region", arguments: ["", "i", "italian", "it-", "it-XX-extra-more", "it_IT", "e1", "it-1234", "it-IT-Latn", "it-Latn-Latn"])
    func badLanguageTags(raw: String) { #expect(DocumentLanguage(raw) == nil) }

    @Test("a design choice holds catalog identifiers only")
    func designChoice() {
        #expect(DesignChoice(design: "modern", palette: "ocean", fonts: "classic") != nil)
        #expect(DesignChoice(design: "../evil") == nil && DesignChoice(design: "modern", palette: "Ocean") == nil)
        #expect(DesignChoice(design: "modern\n") == nil && DesignChoice(design: "") == nil)
    }

    @Test("an array literal of interests is normalised as the initialiser normalises its list")
    func interestsLiteral() {
        let literal: Interests = [" Chess ", "", "chess", "Running", "  "]
        #expect(literal == Interests([" Chess ", "", "chess", "Running", "  "]))
        #expect(literal.values == ["Chess", "Running"])
    }

    @Test("an empty array literal is no interests")
    func emptyInterestsLiteral() {
        #expect(([] as Interests).values.isEmpty)
    }

    @Test("a new CV starts without details")
    func newCVStartsWithoutDetails() {
        #expect(CV(id: id1).personal == PersonalDetails())
    }

    @Test("a new CV starts without sections")
    func newCVStartsWithoutSections() {
        #expect(CV(id: id1).sections == CVSections())
    }

    @Test("each interest is trimmed of spaces, tabs and newlines")
    func interestsAreTrimmed() {
        #expect(Interests(["  Chess\n", "\tRunning "]).values == ["Chess", "Running"])
    }

    @Test("an empty interest is dropped, and so is one that is only white space")
    func emptyInterestsAreDropped() {
        #expect(Interests(["", "Chess", "  ", "\n", "Running"]).values == ["Chess", "Running"])
    }

    @Test("of two interests equal ignoring case the first stays, wherever the second is")
    func duplicatesIgnoringCaseKeepTheFirst() {
        #expect(Interests(["chess", "Running", "CHESS", "Chess"]).values == ["chess", "Running"])
        #expect(Interests(["Écoute", "écoute"]).values == ["Écoute"])
    }

    @Test("an interest that is equal to another only after trimming is a duplicate")
    func duplicatesAfterTrimming() {
        #expect(Interests(["Chess", " chess\n"]).values == ["Chess"])
    }

    @Test("interests keep the order they were given in")
    func interestsKeepTheirOrder() {
        #expect(Interests(["b", "a", "c", "A"]).values == ["b", "a", "c"])
    }

    @Test("normalising a normalised list changes nothing")
    func interestsAreStable() {
        let interests = Interests([" Chess ", "", "chess", "Running", "  "])
        #expect(Interests(interests.values) == interests)
    }

    @Test("sections start with no interests")
    func sectionsStartWithNoInterests() {
        #expect(CVSections().interests.values.isEmpty)
    }

    @Test("sections hold the interests they are given")
    func sectionsHoldInterests() {
        #expect(CVSections(interests: Interests(["Chess", "chess", "Running"])).interests.values == ["Chess", "Running"])
    }

    @Test("a listing orders the CVs by last change, and a CV that was never stored comes last")
    func mostRecentlyChangedFirst() {
        let ids = SequentialIDGenerator()
        let older = named("Older", id: ids.next()).stored(revision: 1, at: Date(timeIntervalSince1970: 100))
        let newer = named("Newer", id: ids.next()).stored(revision: 1, at: Date(timeIntervalSince1970: 200))
        let unsaved = named("Unsaved", id: ids.next())
        #expect([unsaved, older, newer].mostRecentlyChangedFirst().map(\.personal.fullName) == ["Newer", "Older", "Unsaved"])
    }

    @Test("the full fixture populates every field, so a completeness test over it sees every leaf")
    func fixtureCoversEveryField() {
        let values = FieldLeaves.of(FixtureCV.full(), skipping: ["revision", "createdAt", "updatedAt"])
        #expect(!values.contains(FieldLeaves.missing) && !values.contains(FieldLeaves.empty) && !values.contains(""))
        #expect(FieldLeaves.of(CV(id: id1)).contains(FieldLeaves.missing))   // the walk does see an unset field
    }

    @Test("entries keep the order the editor sets; duplication keeps content and design, not identity or history")
    func orderAndDuplication() {
        var cv = FixtureCV.full()
        var sections = cv.sections
        sections.experiences = [Experience(role: "Lead", company: "Next")] + sections.experiences
        cv.setSections(sections)
        #expect(cv.sections.experiences.map(\.role) == ["Lead", "Engineer"])
        let copy = cv.duplicated(as: CVID(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!), title: "Copy")
        #expect(copy.id != cv.id && copy.revision == 0 && copy.createdAt == nil && copy.title == "Copy")
        #expect(copy.personal == cv.personal && copy.sections == cv.sections && copy.design == cv.design && copy.language == cv.language)
    }
}

@Suite("LSP · repository contract")
struct ContractTests {
    @Test("in-memory adapter passes") func inMemory() async throws { try await CVRepositoryContract.verify(InMemoryCVRepository()) }
}

@Suite("use cases")
struct UseCaseTests {
    @Test("save creates once, then updates; errors are translated (#4, #5)")
    func saveCreatesThenUpdates() async throws {
        let r = InMemoryCVRepository()
        var cv = NewCV(ids: SequentialIDGenerator())()
        cv.setPersonalDetails(PersonalDetails(fullName: "Ada"))
        cv = try await SaveCV(repository: r)(cv)
        cv.rename("iOS – Apple")
        let saved = try await SaveCV(repository: r)(cv)
        let listed = try await r.list().cvs
        #expect(saved.revision == 2 && listed == [saved])
        await #expect(throws: AuthoringError.conflict(storedRevision: 2)) { _ = try await SaveCV(repository: r)(cv) }
        try await r.delete(saved.id, revision: 2)
        await #expect(throws: AuthoringError.deletedElsewhere) { _ = try await SaveCV(repository: r)(saved) }
    }

    @Test("an empty CV is not persisted")
    func emptyRejected() async {
        await #expect(throws: AuthoringError.notEnoughContent) { _ = try await SaveCV(repository: InMemoryCVRepository())(CV(id: id1)) }
    }

    @Test("every field survives a save and a load")
    func fullRoundTrip() async throws {
        let r = InMemoryCVRepository()
        let saved = try await SaveCV(repository: r)(FixtureCV.full())
        let loaded = try await LoadCV(repository: r)(saved.id)
        #expect(loaded == saved && loaded.personal == FixtureCV.full().personal && loaded.sections == FixtureCV.full().sections)
        #expect(loaded.design == FixtureCV.full().design && loaded.language == FixtureCV.full().language)
    }

    @Test("loading a CV deleted elsewhere says so")
    func loadDeleted() async throws {
        let r = InMemoryCVRepository()
        let saved = try await SaveCV(repository: r)(named("Ada"))
        try await DeleteCV(repository: r)(saved)
        await #expect(throws: AuthoringError.deletedElsewhere) { _ = try await LoadCV(repository: r)(saved.id) }
    }

    @Test("rename is a conditional update")
    func rename() async throws {
        let r = InMemoryCVRepository()
        let saved = try await SaveCV(repository: r)(named("Ada"))
        let renamed = try await RenameCV(repository: r)(saved, to: "Backend roles")
        #expect(renamed.title == "Backend roles" && renamed.revision == 2)
        await #expect(throws: AuthoringError.conflict(storedRevision: 2)) { _ = try await RenameCV(repository: r)(saved, to: "Stale") }
    }

    @Test("duplicate stores a copy under a new identity with the given title")
    func duplicate() async throws {
        let r = InMemoryCVRepository()
        let saved = try await SaveCV(repository: r)(FixtureCV.full())
        let copy = try await DuplicateCV(repository: r, ids: SequentialIDGenerator())(saved, title: "iOS roles (copy)")
        #expect(copy.id != saved.id && copy.revision == 1 && copy.title == "iOS roles (copy)" && copy.sections == saved.sections)
        #expect(try await r.list().cvs.count == 2)
    }

    @Test("delete needs the revision the caller saw; a missing CV is 'deleted elsewhere'")
    func delete() async throws {
        let r = InMemoryCVRepository()
        let v1 = try await SaveCV(repository: r)(named("Ada"))
        var edit = v1; edit.rename("Newer"); _ = try await SaveCV(repository: r)(edit)
        await #expect(throws: AuthoringError.conflict(storedRevision: 2)) { try await DeleteCV(repository: r)(v1) }
        let current = try await LoadCV(repository: r)(v1.id)
        try await DeleteCV(repository: r)(current)
        await #expect(throws: AuthoringError.deletedElsewhere) { try await DeleteCV(repository: r)(current) }
    }

    @Test("starting from a sample gives an unsaved CV with a fresh identity and nothing is stored")
    func startFromSample() async throws {
        let r = InMemoryCVRepository()
        let use = StartFromSample(samples: InMemorySampleCVSource([FixtureCV.full()]), ids: SequentialIDGenerator())
        let samples = try await use.available()
        let started = use(try #require(samples.first))
        #expect(started.id != FixtureCV.full().id && started.revision == 0 && started.sections == FixtureCV.full().sections)
        #expect(try await r.list().cvs.isEmpty)
    }

    @Test("onboarding: first run only when the store holds nothing at all")
    func onboarding() async throws {
        let r = InMemoryCVRepository()
        #expect(try await DetermineOnboarding(repository: r)() == .firstRun)
        _ = try await SaveCV(repository: r)(named("Ada"))
        #expect(try await DetermineOnboarding(repository: r)() == .returning)
    }
}
