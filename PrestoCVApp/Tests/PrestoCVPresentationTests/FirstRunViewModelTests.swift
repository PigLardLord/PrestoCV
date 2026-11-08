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
        let example = try #require(firstRun.choices.first)

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
