import Testing
import Foundation
import PrestoCVDomain
import PrestoCVCoreTestSupport

private func expect(_ error: ApplicationError, _ body: () throws -> Void) {
    do { try body(); Issue.record("expected \(error)") } catch let e as ApplicationError { #expect(e == error) } catch { Issue.record("\(error)") }
}

private let at = Date(timeIntervalSince1970: 1_700_000_000)

@Suite("ADR 0019 · application")
struct ApplicationTests {
    @Test("the fixture populates every field, so a completeness test over it sees every leaf")
    func fixtureIsComplete() {
        let leaves = FieldLeaves.of(FixtureApplication.full(), skipping: ["revision", "createdAt", "updatedAt"])
        #expect(!leaves.contains(FieldLeaves.missing) && !leaves.contains(FieldLeaves.empty) && !leaves.contains(""))
    }

    @Test("a new application is never saved, and its CV keeps the identity it was given")
    func created() {
        let application = FixtureApplication.full()
        #expect(application.revision == 0 && application.createdAt == nil && application.updatedAt == nil)
        #expect(application.id == FixtureApplication.id && application.cv.id == FixtureApplication.cvID)
        #expect(application.cv.revision == 0 && application.cv.createdAt == nil && application.cv.sections == FixtureCV.full().sections)
    }

    @Test("the CV of a stored application has the application's revision and times, and only the application's")
    func storedCarriesOneRevision() {
        let stored = FixtureApplication.full().stored(revision: 4, at: at)
        #expect(stored.revision == 4 && stored.createdAt == at && stored.updatedAt == at)
        #expect(stored.cv.revision == 4 && stored.cv.createdAt == at && stored.cv.updatedAt == at && stored.cv.id == FixtureApplication.cvID)
        let later = stored.stamped(revision: 5, createdAt: at, updatedAt: at.addingTimeInterval(60))
        #expect(later.revision == 5 && later.cv.revision == 5 && later.createdAt == at && later.cv.createdAt == at && later.cv.updatedAt == at.addingTimeInterval(60))
        #expect(stored.stored(revision: 6, at: at.addingTimeInterval(9)).createdAt == at)
    }

    @Test("a CV that cannot be saved cannot be the tailored CV")
    func cvMustBeSaveable() throws {
        let empty = CV(id: FixtureApplication.cvID)
        expect(.cvCannotBeSaved) {
            _ = try Application(id: FixtureApplication.id, cv: empty, letter: FixtureLetter.full(), advert: Advert(company: "", role: "", text: "Advert"),
                                provenance: FixtureProvenance.full())
        }
    }

    @Test("editing the CV keeps its identity and the application's revision, and ignores the revision and times the editor holds")
    func setCV() throws {
        var application = FixtureApplication.full().stored(revision: 3, at: at)
        var edited = FixtureApplication.full().cv
        edited.rename("Tailored for Acme")
        var sections = edited.sections
        sections.skills.append(Skill(name: "Combine"))
        edited.setSections(sections)
        try application.setCV(edited)
        #expect(application.cv.title == "Tailored for Acme" && application.cv.sections.skills.last?.name == "Combine")
        #expect(application.cv.id == FixtureApplication.cvID && application.cv.revision == 3 && application.revision == 3 && application.cv.updatedAt == at)
    }

    @Test("no change replaces the CV's identity, and the edited CV must be saveable")
    func setCVRefusals() throws {
        var application = FixtureApplication.full()
        let before = application
        expect(.cvIdentityChanged) { try application.setCV(FixtureCV.full(id: CVID(UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!))) }
        var blank = application.cv
        blank.setPersonalDetails(PersonalDetails(fullName: " "))
        expect(.cvCannotBeSaved) { try application.setCV(blank) }
        #expect(application == before)
    }

    @Test("editing the letter replaces it and leaves the CV, the advert, the provenance and the revision alone")
    func setLetter() throws {
        var application = FixtureApplication.full().stored(revision: 2, at: at)
        let before = application
        let edited = try CoverLetter(recipient: LetterRecipient(company: "Other"), paragraphs: ["Short."])
        application.setLetter(edited)
        #expect(application.letter == edited && application.cv == before.cv && application.advert == before.advert)
        #expect(application.provenance == before.provenance && application.revision == 2)
    }

    @Test("the advert's company and role are wide enough for the letter's recipient, which the workflow may fill them from: 10,000 bytes")
    func advertBoundsHoldTailoringsBounds() throws {
        #expect(Advert.maxLineBytes == 10_000)
        let line = String(repeating: "a", count: 10_000)
        let advert = try Advert(company: line, role: line, text: "t")
        #expect(advert.company == line && advert.role == line)
        let recipient = try LetterRecipient(company: line, role: line)
        #expect(try Advert(company: recipient.company ?? "", role: recipient.role ?? "", text: "t") == advert)
    }

    @Test("the advert may leave the company and the role empty, and the text says something, within its bound")
    func advert() throws {
        let nameless = try Advert(company: " ", role: "", text: " Text \n")
        #expect(nameless.company.isEmpty && nameless.role.isEmpty && nameless.text == "Text")
        #expect(try Advert(company: "a", role: "b", text: "Line one\nline two").text == "Line one\nline two")
        expect(.empty(.advertText)) { _ = try Advert(company: "a", role: "b", text: " \n ") }
        expect(.tooLong(.advertCompany)) { _ = try Advert(company: String(repeating: "a", count: Advert.maxLineBytes + 1), role: "", text: "t") }
        expect(.tooLong(.advertRole)) { _ = try Advert(company: "", role: String(repeating: "a", count: Advert.maxLineBytes + 1), text: "t") }
        _ = try Advert(company: "", role: "", text: String(repeating: "a", count: Advert.maxTextBytes))
        expect(.tooLong(.advertText)) { _ = try Advert(company: "", role: "", text: String(repeating: "a", count: Advert.maxTextBytes + 1)) }
        expect(.forbiddenCharacters(.advertText)) { _ = try Advert(company: "", role: "", text: "a\u{0000}b") }
        expect(.forbiddenCharacters(.advertCompany)) { _ = try Advert(company: "a\nb", role: "", text: "t") }
    }
}
