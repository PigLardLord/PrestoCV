import Testing
import PrestoCVApplication
import PrestoCVDomain
@testable import PrestoCVPresentation

@MainActor
@Suite("First run")
struct FirstRunViewModelTests {

    private func samples(_ world: Browsing, _ titles: [String]) {
        let cvs = titles.map { CV(id: world.editing.ids.next(), title: $0, personal: PersonalDetails(fullName: "Example Person")) }
        world.browsing.sampleList.withLock { $0 = cvs }
    }

    @Test("a store with nothing at all is a first run")
    func emptyStoreIsFirstRun() async {
        let world = Browsing()
        let firstRun = world.firstRun()
        #expect(firstRun.state == .loading)

        await firstRun.load()

        #expect(firstRun.state == .firstRun)
    }

    @Test("a store that holds only a file with an issue is not a first run")
    func storeWithIssueOnlyIsNotFirstRun() async {
        let world = Browsing()
        world.browsing.issues.withLock { $0 = [.unreadable(file: "one.json")] }
        let firstRun = world.firstRun()

        await firstRun.load()

        #expect(firstRun.state == .returning)
    }

    @Test("the examples come from samples(), each an example choice, and are read once")
    func samplesBecomeExampleChoices() async {
        let world = Browsing()
        samples(world, ["Nurse", "Electrician"])
        let firstRun = world.firstRun()

        await firstRun.load()
        await firstRun.load()

        let titles = firstRun.choices.compactMap { choice -> String? in
            if case .example(let example) = choice { return example.title }
            return nil
        }
        #expect(titles == ["Nurse", "Electrician"])
        #expect(world.browsing.sampleCalls.withLock { $0 } == 1)
        #expect(firstRun.examplesIssue == nil)
    }

    @Test("an example gives an unsaved draft under a new identity, and nothing is stored")
    func exampleGivesUnsavedDraft() async throws {
        let world = Browsing()
        samples(world, ["Nurse"])
        let firstRun = world.firstRun()
        await firstRun.load()
        let sample = try #require(world.browsing.sampleList.withLock { $0.first })
        let example = try #require(firstRun.choices.first { if case .example = $0 { true } else { false } })

        let destination = firstRun.start(example)

        guard case .draft(let draft) = destination else { Issue.record("expected a draft"); return }
        #expect(draft.cv.id != sample.id)
        #expect(draft.cv.revision == 0)
        #expect(draft.cv.title == "Nurse")
        #expect(try await world.editing.store.list().cvs.isEmpty)
    }

    @Test("blank gives an unsaved draft with a new identity each time")
    func blankGivesUnsavedDraftWithNewId() async throws {
        let world = Browsing()
        let firstRun = world.firstRun()
        await firstRun.load()

        guard case .draft(let one) = firstRun.start(.blank), case .draft(let two) = firstRun.start(.blank) else {
            Issue.record("expected drafts"); return
        }

        #expect(one.cv.id != two.cv.id)
        #expect(one.cv.revision == 0)
        #expect(try await world.editing.store.list().cvs.isEmpty)
    }

    @Test("when the examples cannot be read, blank and import are still offered, with the reason as a code")
    func noSamplesStillOffersBlankAndImport() async {
        let world = Browsing()
        world.browsing.samplesError.withLock { $0 = .unavailable }
        let firstRun = world.firstRun()

        await firstRun.load()

        #expect(firstRun.choices == [.importCV, .blank])
        #expect(firstRun.examplesIssue == .unavailable)
        #expect(firstRun.state == .firstRun)
    }

    @Test("import is a code the screen turns into the import flow: nothing is imported or stored here")
    func importIsAChoiceCodeNotAnAction() async throws {
        let world = Browsing()
        let firstRun = world.firstRun()
        await firstRun.load()

        let destination = firstRun.start(.importCV)

        guard case .importCV = destination else { Issue.record("expected the import"); return }
        #expect(try await world.editing.store.list().cvs.isEmpty)
    }

    @Test("the import leads, then the examples in their order, then blank")
    func importLeadsThenExamplesThenBlank() async throws {
        let world = Browsing()
        samples(world, ["Nurse", "Electrician"])
        let firstRun = world.firstRun()
        await firstRun.load()

        let examples = firstRun.choices.filter { if case .example = $0 { true } else { false } }
        try #require(examples.count == 2)
        #expect(firstRun.choices == [.importCV] + examples + [.blank])
    }

    @Test("without the import offered, the examples come first and blank last, and without examples blank stands alone")
    func noImportWhenNotOffered() async throws {
        let world = Browsing()
        samples(world, ["Nurse", "Electrician"])
        let withExamples = world.firstRun(offersImport: false)
        await withExamples.load()
        let examples = withExamples.choices.filter { if case .example = $0 { true } else { false } }
        try #require(examples.count == 2)

        #expect(withExamples.choices == examples + [.blank])

        let empty = Browsing()
        empty.browsing.samplesError.withLock { $0 = .unavailable }
        let withoutExamples = empty.firstRun(offersImport: false)
        await withoutExamples.load()

        #expect(withoutExamples.choices == [.blank])
    }

    @Test("an example carries its own summary, as its title, to tell two examples apart")
    func exampleChoiceCarriesItsSummary() async {
        let world = Browsing()
        let summaries = ["Cares for patients on a busy ward.", "Wires homes and small offices."]
        let cvs = zip(["Nurse", "Electrician"], summaries).map { title, summary in
            CV(id: world.editing.ids.next(), title: title, personal: PersonalDetails(fullName: "Example Person", summary: summary))
        }
        world.browsing.sampleList.withLock { $0 = cvs }
        let firstRun = world.firstRun()

        await firstRun.load()

        let read = firstRun.choices.compactMap { choice -> String? in
            if case .example(let example) = choice { return example.summary }
            return nil
        }
        #expect(read == summaries)
    }

    @Test("blank is always offered last")
    func blankIsListedLast() async {
        let world = Browsing()
        samples(world, ["Nurse", "Electrician"])
        let firstRun = world.firstRun()
        await firstRun.load()

        #expect(firstRun.choices.last == .blank)
        #expect(firstRun.choices.contains(.importCV))
        #expect(firstRun.choices.count == 4)
    }

    @Test("a cancelled load is no failure")
    func cancelledLoadIsNoFailure() async {
        let world = Browsing()
        world.browsing.onboardingError.withLock { $0 = .unavailable }
        let firstRun = world.firstRun()

        let loading = Task { await firstRun.load() }
        loading.cancel()
        await loading.value

        #expect(firstRun.state != .failed)
    }
}
