import Testing
import Foundation
import Synchronization
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVWorkflowPorts
import PrestoCVIntegration
import PrestoCVPresentation
import PrestoCVCoreTestSupport
import CVDocumentModel
import CVDesignCatalog
import CVRendering
import CVRenderingTestSupport
import CVDrafting

let id1 = CVID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)

/// Every field populated, so the Mirror-based completeness test sees every leaf.
func fullCV() -> CV {
    var cv = CV(id: id1, title: "iOS – Apple")
    cv.setPerson(fullName: "Ada Lovelace", email: EmailAddress("ada@example.com"))
    cv.addExperience(Experience(role: "Clerk", company: "Old Firm", period: Period(start: PartialDate(year: 2015, month: 1)!, end: .unknown), description: "Ledgers"))
    cv.addExperience(Experience(role: "Analyst", company: "Babbage", period: Period(start: PartialDate(year: 2019, month: 3)!, end: .current), description: "Engines"))
    cv.addSkill(Skill(name: "Swift", level: SkillLevel(5)))
    return cv
}

func stylesheet() throws -> ValidatedStylesheet {
    let data = try JSONSerialization.data(withJSONObject: ["manifest": ["id": "clean", "name": "Clean", "version": "1", "description": "", "markupContract": 1],
                                                           "cssContent": ".cv-name{color:var(--color-primary)}"])
    return try DesignPackageValidator().validate(data).stylesheet
}
let palette = Palette(primary: HexColor("#1F3A5F")!, text: HexColor("#111111")!, background: HexColor("#FFFFFF")!)!

func exporter(_ renderer: any PDFRendering = FakePDFRenderer()) throws -> ExportCVWorkflow {
    ExportCVWorkflow(renderer: renderer, inspector: MinimalPDFInspector(), stylesheet: try stylesheet(), palette: palette)
}

/// Leaves of a value (strings and integers), walked with Mirror.
func leaves(_ value: Any, skipping: Set<String>) -> [String] {
    let m = Mirror(reflecting: value)
    if m.displayStyle == .optional { return m.children.first.map { leaves($0.value, skipping: skipping) } ?? ["<nil>"] }
    switch value {
    case let s as String: return [s]
    case let i as Int: return [String(i)]
    case is Date, is UUID: return []
    default: return m.children.filter { !skipping.contains($0.label ?? "") }.flatMap { leaves($0.value, skipping: skipping) }
    }
}

@Suite("ADR 0007 · mappers in the integration layer")
struct MapperTests {
    @Test("CV → CVDocument: typed periods, unknown end stays unspecified (review H1)")
    func cvToDocument() {
        let doc = CVToDocumentMapper().map(fullCV(), language: "it")
        #expect(doc.person == Person(name: "Ada Lovelace", email: "ada@example.com"))
        #expect(doc.sections.first == .experience([
            ExperienceItem(role: "Analyst", company: "Babbage", period: DocumentPeriod(start: DocumentDate(year: 2019, month: 3), end: .present), description: "Engines"),
            ExperienceItem(role: "Clerk", company: "Old Firm", period: DocumentPeriod(start: DocumentDate(year: 2015, month: 1), end: .unspecified), description: "Ledgers"),
        ]))
    }

    @Test("every populated CV field reaches the document; adding a field without mapping it fails (review M9)")
    func mirrorCompleteness() throws {
        let cv = fullCV()
        let skip: Set<String> = ["id", "revision", "createdAt", "updatedAt", "title"]   // title is private to the user, never printed
        let values = leaves(cv, skipping: skip)
        #expect(!values.contains("<nil>") && !values.contains(""), "the fixture must populate every field")
        let json = String(decoding: try JSONEncoder().encode(CVToDocumentMapper().map(cv, language: "it")), as: UTF8.self)
        for v in values { #expect(json.contains(v), "\(v) is not mapped") }
    }

    @Test("an export of a period that ended on an unknown date never says 'present'")
    func unknownEndExport() async throws {
        final class Capture: PDFRendering { let html = Mutex("")
            func render(html: String, page: PageSetup) async throws -> RenderedPDF { self.html.withLock { $0 = html }; return try await FakePDFRenderer().render(html: html, page: page) } }
        let r = Capture()
        _ = try await exporter(r).export(fullCV(), language: "it")
        let html = r.html.withLock { $0 }
        #expect(html.contains(#"<p class="cv-entry-period">01/2015</p>"#) && html.contains("03/2019 – Oggi") && !html.contains("01/2015 – "))
    }

    @Test("draft → CV: every date shape is kept or reported; invalid email is a gap (review 17)")
    func draftJobs() {
        let draft = CVDraft(fullName: "Ada", email: "not-an-email", jobs: [
            .init(role: "Current", company: "A", startYear: 2022, endYear: nil, isCurrent: true),
            .init(role: "Completed", company: "B", startYear: 2018, endYear: 2021, isCurrent: false),
            .init(role: "EndedUnknown", company: "C", startYear: 2015, endYear: nil, isCurrent: false),
            .init(role: "NoDates", company: "D", startYear: nil, endYear: nil, isCurrent: false),
            .init(role: "EndOnly", company: "E", startYear: nil, endYear: 2014, isCurrent: false),
            .init(role: "Reversed", company: "F", startYear: 2012, endYear: 2010, isCurrent: false),
            .init(role: "CurrentNoStart", company: "G", startYear: nil, endYear: nil, isCurrent: true),
            .init(role: "CurrentWithEnd", company: "H", startYear: 2019, endYear: 2020, isCurrent: true),
        ], skills: [("Swift", .expert), ("Git", nil)])
        let (cv, gaps) = DraftToCVMapper().map(draft, id: id1)
        let byRole = Dictionary(uniqueKeysWithValues: cv.experiences.map { ($0.role, $0.period) })
        #expect(byRole["Current"]! == Period(start: PartialDate(year: 2022)!, end: .current))
        #expect(byRole["Completed"]! == Period(start: PartialDate(year: 2018)!, end: .date(PartialDate(year: 2021)!)))
        #expect(byRole["EndedUnknown"]! == Period(start: PartialDate(year: 2015)!, end: .unknown))
        #expect(byRole["NoDates"]! == nil)
        #expect(Set(gaps.map { "\($0)" }) == Set([DraftGap.invalidEmail("not-an-email"), .period(role: "CurrentWithEnd", .currentWithEndDate),
            .period(role: "CurrentNoStart", .currentWithoutStart), .period(role: "Reversed", .endBeforeStart), .period(role: "EndOnly", .endWithoutStart)].map { "\($0)" }))
        #expect(cv.email == nil && cv.skills.map(\.level?.value) == [5, nil])
    }

    @Test("every saveable CV maps to a renderable document (R6: two validity rules, one implication)", arguments: [
        "Ada", " Ada ", "A", String(repeating: "x", count: 5_000),
    ])
    func saveableIsRenderable(name: String) throws {
        var cv = fullCV(); cv.setPerson(fullName: name, email: nil)
        #expect(cv.canBeSaved)
        try CVDocumentValidator.validate(CVToDocumentMapper().map(cv, language: "it"))
    }

    @Test("an AI draft keeps its identity through save and load (#5)")
    func draftIdentity() async throws {
        let repo = InMemoryCVRepository(), editing = EditCVWorkflow(repository: repo, ids: SequentialIDGenerator())
        let (draftCV, _) = DraftToCVMapper().map(CVDraft(fullName: "Ada", email: nil, jobs: [], skills: []), id: editing.newCV().id)
        let saved = try await editing.save(draftCV)
        #expect(try await editing.load(saved.id).fullName == "Ada")
    }
}

/// Bounded wait that records an issue instead of hanging or passing silently.
@MainActor func waitUntil(_ what: String, _ condition: @MainActor () async -> Bool) async {
    for _ in 0..<10_000 { if await condition() { return }; await Task.yield() }
    Issue.record("timed out waiting for \(what)")
}

@MainActor final class Returned { var value = false }

actor Gate {
    var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async { await withCheckedContinuation { waiters.append($0) } }
    func releaseAll() { waiters.forEach { $0.resume() }; waiters = [] }
    var waiting: Int { waiters.count }
}

final class GatedEditing: CVEditing {
    let inner: EditCVWorkflow, gate = Gate(), calls = Mutex<[Int]>([])
    init(repo: InMemoryCVRepository) { inner = EditCVWorkflow(repository: repo, ids: SequentialIDGenerator()) }
    func newCV() -> CV { inner.newCV() }
    func load(_ id: CVID) async throws(AuthoringError) -> CV { try await inner.load(id) }
    func save(_ cv: CV) async throws(AuthoringError) -> CV {
        calls.withLock { $0.append(cv.revision) }
        await gate.wait()
        return try await inner.save(cv)
    }
}

@Suite("ADR 0010 · UI-free view models, tested on Linux")
@MainActor
struct PresentationTests {
    func vm(_ editing: any CVEditing, renderer: any PDFRendering = FakePDFRenderer()) throws -> EditorViewModel {
        EditorViewModel(editing: editing, exporting: try exporter(renderer))
    }

    @Test("overlapping saves: one create, one update with the latest edits, and both callers wait for it (review 10)")
    func overlappingSaves() async throws {
        let repo = InMemoryCVRepository(), editing = GatedEditing(repo: repo)
        let model = try vm(editing)
        model.fullName = "Ada"
        let first = Task { await model.save() }
        await waitUntil("first save to block") { await editing.gate.waiting > 0 }
        model.fullName = "Ada Lovelace"
        let second = Task { await model.save() }
        for _ in 0..<200 { await Task.yield() }
        await editing.gate.releaseAll()
        await waitUntil("coalesced update to block") { await editing.gate.waiting > 0 }
        await editing.gate.releaseAll()
        await second.value                                                  // returns only after the update landed
        #expect(try await repo.list().cvs.first?.fullName == "Ada Lovelace")
        await first.value
        #expect(editing.calls.withLock { $0 } == [0, 1])
        #expect(model.saveStatus == .saved && model.isSaved)
    }

    @Test("a save requested just as the save loop finishes is stored before its caller returns (review round 3)")
    func saveAtLoopHandoff() async throws {
        for delay in 0..<100 {                                  // sweeps the request across the loop's end
            let repo = InMemoryCVRepository(), editing = GatedEditing(repo: repo)
            let model = try vm(editing)
            model.fullName = "Ada"
            let first = Task { await model.save() }
            await waitUntil("first save to block") { await editing.gate.waiting > 0 }
            await editing.gate.releaseAll()
            for _ in 0..<delay { await Task.yield() }
            model.fullName = "Ada Lovelace \(delay)"
            let returned = Returned()
            let second = Task { await model.save(); returned.value = true }
            await waitUntil("the second caller to return") { await editing.gate.releaseAll(); return returned.value }
            await second.value
            #expect(try await repo.list().cvs.first?.fullName == "Ada Lovelace \(delay)", "request after \(delay) yields")
            await first.value
        }
    }

    @Test("a stale save becomes a conflict; reload takes the stored version; saving then works")
    func conflictAndReload() async throws {
        let repo = InMemoryCVRepository()
        let a = try vm(EditCVWorkflow(repository: repo, ids: SequentialIDGenerator()))
        a.fullName = "Ada"; await a.save()
        let id = try await repo.list().cvs[0].id
        var other = try await repo.load(id); other.setPerson(fullName: "Other window", email: nil)
        _ = try await repo.update(other)
        a.fullName = "Ada L."; await a.save()
        #expect(a.saveStatus == .conflict)
        #expect(try await repo.load(id).fullName == "Other window")
        await a.reload()
        #expect(a.fullName == "Other window" && a.saveStatus == .idle)
        a.fullName = "Ada again"; await a.save()
        let again = try await repo.load(id).fullName
        #expect(a.saveStatus == .saved && again == "Ada again")
    }

    @Test("deleted in another window: save as a copy keeps the edits")
    func deletedElsewhere() async throws {
        let repo = InMemoryCVRepository()
        let a = try vm(EditCVWorkflow(repository: repo, ids: SequentialIDGenerator()))
        a.fullName = "Ada"; await a.save()
        let stored = try await repo.list().cvs[0]
        try await repo.delete(stored.id, revision: stored.revision)
        a.fullName = "Ada L."; await a.save()
        #expect(a.saveStatus == .deletedElsewhere)
        await a.saveAsCopy()
        let names = try await repo.list().cvs.map(\.fullName)
        #expect(a.saveStatus == .saved && names == ["Ada L."])
    }

    @Test("export uses the editor snapshot, statuses are separate and reset (reviews 9, 11)")
    func exportStatuses() async throws {
        struct Short: PDFRendering {
            func render(html: String, page: PageSetup) async throws -> RenderedPDF {
                let r = try await FakePDFRenderer().render(html: html, page: page)
                return RenderedPDF(data: r.data, pageCount: r.pageCount, requiredPages: r.pageCount + 5)
            }
        }
        let repo = InMemoryCVRepository(), editing = EditCVWorkflow(repository: repo, ids: SequentialIDGenerator())
        let truncating = EditorViewModel(editing: editing, exporting: try exporter(Short()))
        truncating.fullName = "Never Saved"
        await truncating.export(language: "it")
        #expect(truncating.exportStatus == .truncated(pages: 1, required: 6))
        let none = try await repo.list().cvs.isEmpty
        #expect(truncating.saveStatus == .idle && none)

        let model = try vm(editing)
        model.fullName = "Never Saved"
        await model.export(language: "it")
        #expect(model.exportStatus == .done(pages: 1))
        await model.export(language: "de")
        #expect(model.exportStatus == .unsupportedLanguage)
    }

    @Test("an export whose PDF lacks a field is reported, not delivered")
    func incompleteExport() async throws {
        struct Dropping: PDFRendering {
            func render(html: String, page: PageSetup) async throws -> RenderedPDF {
                try await FakePDFRenderer().render(html: html.replacingOccurrences(of: "Ada", with: ""), page: page)
            }
        }
        let model = try vm(EditCVWorkflow(repository: InMemoryCVRepository(), ids: SequentialIDGenerator()), renderer: Dropping())
        model.fullName = "Ada"
        await model.export(language: "it")
        #expect(model.exportStatus == .incomplete)
    }

    @Test("an export that loses a date is reported (occurrence-aware completeness)")
    func exportLosesDates() async throws {
        struct NoDates: PDFRendering {
            func render(html: String, page: PageSetup) async throws -> RenderedPDF {
                try await FakePDFRenderer().render(html: html.replacingOccurrences(of: "03/2019 – Oggi", with: ""), page: page)
            }
        }
        let editing = EditCVWorkflow(repository: InMemoryCVRepository(), ids: SequentialIDGenerator())
        do { _ = try await exporter(NoDates()).export(fullCV(), language: "it"); Issue.record("export succeeded") }
        catch let failure as ExportFailure { #expect(failure == .incomplete(missing: 1)) }
        _ = editing
    }

    @Test("a cancelled export is not reported as a failure (review 9)")
    func cancelledExport() async throws {
        struct Cancelled: PDFRendering { func render(html: String, page: PageSetup) async throws -> RenderedPDF { throw CancellationError() } }
        let model = try vm(EditCVWorkflow(repository: InMemoryCVRepository(), ids: SequentialIDGenerator()), renderer: Cancelled())
        model.fullName = "Ada"
        await model.export(language: "it")
        #expect(model.exportStatus == .idle)
    }

    @Test("an empty CV yields a status, not a stored record")
    func emptyName() async throws {
        let repo = InMemoryCVRepository()
        let model = try vm(EditCVWorkflow(repository: repo, ids: SequentialIDGenerator()))
        await model.save()
        let empty = try await repo.list().cvs.isEmpty
        #expect(model.saveStatus == .needsName && empty)
    }
}
