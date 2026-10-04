import Testing
import Foundation
import PrestoCVDomain
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

private let created = Date(timeIntervalSince1970: 1_700_000_000), updated = Date(timeIntervalSince1970: 1_700_000_900)

/// An application with every field populated, at revision 3: the stored bytes of it are pinned below.
private func stored() -> Application { FixtureApplication.full().stamped(revision: 3, createdAt: created, updatedAt: updated) }

/// The bytes `ApplicationFileV1` writes, pinned (ADR 0019, R12). Changing a byte here is a change of the schema, and it ships
/// with a new version and its migration.
private let golden = #"{"advert":{"company":"Acme S.r.l.","role":"iOS Engineer","text":"We look for an iOS engineer.\nSwiftUI is a plus."},"createdAt":"2023-11-14T22:13:20Z","cv":{"content":{"certifications":[{"description":"Concurrency","issued":{"month":6,"year":2021},"issuer":"Apple","link":"https:\/\/cert.example\/1","name":"Swift Certified"}],"design":{"design":"modern","fonts":"classic","palette":"ocean"},"education":[{"current":false,"degree":"Mathematics","description":"Tutored","end":{"month":7,"year":2015},"school":"Home","start":{"month":9,"year":2012}}],"experiences":[{"company":"Analytical","current":true,"description":"Engines","location":"London","role":"Engineer","start":{"month":3,"year":2019}}],"interests":["Chess","Running"],"language":"it","languages":[{"language":"Italian","proficiency":"native"},{"language":"English","proficiency":"c1"}],"personal":{"email":"ada@example.com","fullName":"Ada Lovelace","location":"Roma","phone":"+39 06 1234567","professionalTitle":"iOS Engineer","summary":"Builds careful software.","website":"https:\/\/ada.example"},"profiles":[{"link":"https:\/\/github.com\/ada","platform":"GitHub"}],"skills":[{"level":5,"name":"Swift"},{"level":3,"name":"Git"}],"title":"iOS roles"},"id":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"},"id":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","letter":{"attachments":["Curriculum vitae"],"closing":"I would be glad to talk.","opening":"I am writing about the iOS Engineer role.","paragraphs":["I ship careful software.","I have led a team of five."],"position":"iOS Engineer","recipient":{"address":["Via Roma 1","00100 Roma"],"company":"Acme S.r.l.","contactName":"Maria Rossi","formOfAddress":"ms","role":"Head of Engineering","surname":"Rossi","title":"Dott.ssa"},"reference":"Ref. 2026-17","subject":"Application for iOS Engineer"},"provenance":{"jobID":"job-0001","letterDefaults":{"note":"Part time","salaryExpectation":"60k","startDate":"May"},"letterOverride":{"note":"Part time","salaryExpectation":"60k","startDate":"May"},"lineSources":[{"answers":[0,1],"experience":0,"line":1,"statements":[{"experience":0,"line":0},{"experience":1,"line":0}]}],"modelAlias":"model-small","promptVersion":"tailor-3","providerAlias":"provider-a","questions":[{"answer":"Used it daily","code":"evidence.missing","scope":{"experience":0,"kind":"experience"},"values":["SwiftUI"]},{"answer":"60k","code":"letter.field","scope":{"field":"salaryExpectation","kind":"letterField"},"values":["salary"]},{"answer":"Two years","code":"evidence.missing","scope":{"kind":"skills"},"values":["Kotlin"]},{"answer":"Five reports","code":"summary.claim","scope":{"kind":"summary"},"values":["leadership"]}],"report":{"argument":"A careful engineer who ships","cut":["Old jobs"],"moved":["Skills up"],"reworded":["Led a team"]},"snapshot":[{"statements":["Led a team of five","Shipped the app"]},{"statements":["Wrote the build scripts"]}],"sourceCV":"99999999-9999-9999-9999-999999999999"},"revision":3,"schemaVersion":1,"updatedAt":"2023-11-14T22:28:20Z"}"#

private func read(_ json: String) throws -> Application { try ApplicationFileV1.read(Data(json.utf8)) }

let applicationMutations: [Mutation] = {
    var all: [Mutation] = []
    all.append(Mutation(name: "revision 0", from: #""revision":3"#, to: #""revision":0"#))
    all.append(Mutation(name: "a newer schema, read as this one", from: #""schemaVersion":1"#, to: #""schemaVersion":2"#))
    all.append(Mutation(name: "an advert text with a margin", from: #""company":"Acme S.r.l.","role""#, to: #""company":" Acme S.r.l.","role""#))
    all.append(Mutation(name: "an empty advert text", from: #""text":"We look for an iOS engineer.\nSwiftUI is a plus.""#, to: #""text":"""#))
    all.append(Mutation(name: "an advert text over its bound", from: #""text":"We look for an iOS engineer.\nSwiftUI is a plus.""#,
                        to: #""text":""# + String(repeating: "x", count: Advert.maxTextBytes + 1) + "\""))
    all.append(Mutation(name: "an empty optional that is not absent", from: #""reference":"Ref. 2026-17""#, to: #""reference":"""#))
    all.append(Mutation(name: "an unknown form of address", from: #""formOfAddress":"ms""#, to: #""formOfAddress":"xx""#))
    all.append(Mutation(name: "a control character in a paragraph", from: "I ship careful software.", to: #"I ship\u0000 careful software."#))
    all.append(Mutation(name: "an empty paragraph", from: #""I ship careful software.""#, to: #""""#))
    all.append(Mutation(name: "an unknown question scope", from: #""scope":{"kind":"skills"}"#, to: #""scope":{"kind":"nothing"}"#))
    all.append(Mutation(name: "a scope with a key that is not its own", from: #""scope":{"kind":"skills"}"#, to: #""scope":{"experience":2,"kind":"skills"}"#))
    all.append(Mutation(name: "an unknown letter field", from: #""field":"salaryExpectation""#, to: #""field":"bonus""#))
    all.append(Mutation(name: "a question about an experience that is not in the snapshot", from: #""scope":{"experience":0,"kind":"experience"}"#,
                        to: #""scope":{"experience":7,"kind":"experience"}"#))
    all.append(Mutation(name: "a statement that is not in the snapshot", from: #"{"experience":1,"line":0}"#, to: #"{"experience":1,"line":5}"#))
    all.append(Mutation(name: "an answer that is not one", from: #""answers":[0,1]"#, to: #""answers":[0,9]"#))
    all.append(Mutation(name: "an empty statement", from: #""Shipped the app""#, to: #""""#))
    all.append(Mutation(name: "an override that the defaults do not say", from: #""letterOverride":{"note":"Part time","salaryExpectation":"60k""#,
                        to: #""letterOverride":{"note":"Part time","salaryExpectation":"70k""#))
    all.append(Mutation(name: "a default with a margin", from: #""letterDefaults":{"note":"Part time""#, to: #""letterDefaults":{"note":" Part time""#))
    all.append(Mutation(name: "a CV without a name", from: #""fullName":"Ada Lovelace""#, to: #""fullName":" ""#))
    all.append(Mutation(name: "a CV email that is not an address", from: #""email":"ada@example.com""#, to: #""email":"not an address""#))
    all.append(Mutation(name: "a CV skill level out of range", from: #"{"level":5,"name":"Swift"}"#, to: #"{"level":9,"name":"Swift"}"#))
    all.append(Mutation(name: "a CV period that ends before it starts", from: #""end":{"month":7,"year":2015}"#, to: #""end":{"month":7,"year":2005}"#))
    all.append(Mutation(name: "no identity for the CV", from: #""id":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB""#, to: #""idx":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB""#))
    return all
}()

@Suite("ADR 0019 · the stored form of an application")
struct ApplicationFileTests {
    @Test("an application with every field is written as exactly these bytes, and reads back as the same application")
    func pinned() throws {
        let application = stored()
        let data = try ApplicationFileV1(application, createdAt: created, updatedAt: updated).encoded()
        #expect(String(decoding: data, as: UTF8.self) == golden)
        #expect(try read(golden) == application)
    }

    @Test("the tailored CV keeps its own CVID through the file, and takes the application's revision and times")
    func cvIdentity() throws {
        let application = try read(golden)
        #expect(application.cv.id == FixtureApplication.cvID && application.id == FixtureApplication.id)
        #expect(application.cv.revision == 3 && application.cv.createdAt == created && application.cv.updatedAt == updated)
    }

    @Test("the CV's content is the one CVFileV1 writes: the same DTO, so the period rule and the size caps exist once")
    func sharedContent() throws {
        let application = stored()
        let alone = CVFileV1(application.cv, createdAt: created, updatedAt: updated).content
        #expect(ApplicationFileV1(application, createdAt: created, updatedAt: updated).cv.content == alone)
    }

    @Test("nothing is stored twice: the CV inside has no revision or times of its own")
    func envelopeOnce() throws {
        let file = try #require(JSONSerialization.jsonObject(with: Data(golden.utf8)) as? [String: Any])
        let cv = try #require(file["cv"] as? [String: Any])
        #expect(Set(cv.keys) == ["id", "content"])
        #expect(file["revision"] != nil && file["createdAt"] != nil && file["updatedAt"] != nil)
    }

    @Test("a minimal application, a skipped question and a letter of nothing but a recipient read back as written")
    func minimal() throws {
        let provenance = try ApplicationProvenance(
            jobID: JobID("j"), sourceCV: FixtureProvenance.sourceCV, snapshot: [], report: ApplicationProvenance.Report(argument: ""),
            questions: [ApplicationProvenance.Question(code: "c", scope: .skills)], letterOverride: .empty, letterDefaults: .empty,
            promptVersion: "p", providerAlias: "a", modelAlias: "m", lineSources: [])
        let cv = CV(id: FixtureApplication.cvID, personal: PersonalDetails(fullName: "A"))
        let application = try Application(id: FixtureApplication.id, cv: cv, letter: CoverLetter(recipient: LetterRecipient()),
                                          advert: Advert(company: "", role: "", text: "t"), provenance: provenance)
            .stamped(revision: 1, createdAt: created, updatedAt: created)
        let data = try ApplicationFileV1(application, createdAt: created, updatedAt: created).encoded()
        #expect(try ApplicationFileV1.read(data) == application)
    }

    @Test("every value that is not in its canonical, valid form is corrupt, never normalised or defaulted", arguments: applicationMutations)
    func corrupt(mutation: Mutation) throws {
        let json = try mutation.apply(to: golden)
        #expect(throws: ApplicationFileV1.Invalid.self) { try read(json) }
    }

    @Test("the job of a stored application is read without reading the rest strictly, so a file that names a job and is otherwise broken still names it")
    func peekJob() throws {
        #expect(try ApplicationFileV1.peekJob(Data(golden.utf8)) == "job-0001")
        let broken = golden.replacingOccurrences(of: #""fullName":"Ada Lovelace""#, with: #""fullName":" ""#)
        #expect(throws: ApplicationFileV1.Invalid.self) { try read(broken) }
        #expect(try ApplicationFileV1.peekJob(Data(broken.utf8)) == "job-0001")
    }

    @Test("a file with no job names none")
    func peekWithoutJob() throws {
        #expect(throws: ApplicationFileV1.Invalid.self) { try ApplicationFileV1.peekJob(Data("{}".utf8)) }
        #expect(throws: ApplicationFileV1.Invalid.self) { try ApplicationFileV1.peekJob(Data(#"{"provenance":{"jobID":7}}"#.utf8)) }
        #expect(throws: ApplicationFileV1.Invalid.self) { try ApplicationFileV1.peekJob(Data("[".utf8)) }
    }

    @Test("{} and a CV file are not applications")
    func notAnApplication() throws {
        #expect(throws: ApplicationFileV1.Invalid.self) { try read("{}") }
        let cvFile = try CVFileV1(FixtureCV.full().stored(revision: 1, at: created), createdAt: created, updatedAt: created).encoded()
        #expect(throws: ApplicationFileV1.Invalid.self) { try ApplicationFileV1.read(cvFile) }
    }
}
