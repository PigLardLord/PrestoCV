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

    /// The examples the entries hold, nil when they hold none.
    private func examples(_ firstRun: FirstRunViewModel) -> [ExampleChoice]? {
        for entry in firstRun.entries { if case .examples(let examples) = entry { return examples } }
        return nil
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

        #expect(examples(firstRun)?.map(\.title) == ["Nurse", "Electrician"])
        #expect(world.browsing.sampleCalls.withLock { $0 } == 1)
        #expect(firstRun.entries == [.importCV, .examples(examples(firstRun) ?? []), .blank])
    }

    @Test("an example gives an unsaved draft under a new identity, and nothing is stored")
    func exampleGivesUnsavedDraft() async throws {
        let world = Browsing()
        samples(world, ["Nurse"])
        let firstRun = world.firstRun()
        await firstRun.load()
        let sample = try #require(world.browsing.sampleList.withLock { $0.first })
        let example = try #require(examples(firstRun)?.first)

        let destination = firstRun.start(.example(example))

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

        #expect(firstRun.entries == [.importCV, .examplesIssue(.unavailable), .blank])
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

    @Test("the import leads, then the examples as one entry in their order, then blank")
    func importLeadsThenExamplesThenBlank() async throws {
        let world = Browsing()
        samples(world, ["Nurse", "Electrician"])
        let firstRun = world.firstRun()
        await firstRun.load()

        let examples = try #require(examples(firstRun))
        #expect(examples.map(\.title) == ["Nurse", "Electrician"])
        #expect(firstRun.entries == [.importCV, .examples(examples), .blank])
    }

    @Test("without the import offered, the examples come first and blank last")
    func noImportWhenNotOffered() async throws {
        let world = Browsing()
        samples(world, ["Nurse", "Electrician"])
        let firstRun = world.firstRun(offersImport: false)
        await firstRun.load()

        let examples = try #require(examples(firstRun))
        #expect(firstRun.entries == [.examples(examples), .blank])
    }

    @Test("without the import and without examples, blank stands alone beside the reason")
    func noImportNoExamples() async {
        let world = Browsing()
        world.browsing.samplesError.withLock { $0 = .unavailable }
        let firstRun = world.firstRun(offersImport: false)
        await firstRun.load()

        #expect(firstRun.entries == [.examplesIssue(.unavailable), .blank])
    }

    @Test("examples that failed to read say so where their entry would be")
    func failedExamplesShowTheirIssue() async {
        let world = Browsing()
        world.browsing.samplesError.withLock { $0 = .tooLarge }
        let firstRun = world.firstRun()
        await firstRun.load()

        #expect(firstRun.entries == [.importCV, .examplesIssue(.failed), .blank])
    }

    @Test("an empty read of the examples leaves no entry and no issue")
    func emptyExamplesLeaveNoEntry() async {
        let world = Browsing()
        let firstRun = world.firstRun()
        await firstRun.load()

        #expect(firstRun.entries == [.importCV, .blank])
        #expect(world.firstRun(offersImport: false).entries == [.blank])
    }

    @Test("a failed read followed by a successful one replaces the issue by the examples entry")
    func laterReadReplacesTheIssue() async throws {
        let world = Browsing()
        samples(world, ["Nurse"])
        world.browsing.samplesError.withLock { $0 = .unavailable }
        let firstRun = world.firstRun()
        await firstRun.load()
        #expect(firstRun.entries == [.importCV, .examplesIssue(.unavailable), .blank])

        world.browsing.samplesError.withLock { $0 = nil }
        await firstRun.load()

        let examples = try #require(examples(firstRun))
        #expect(examples.map(\.title) == ["Nurse"])
        #expect(firstRun.entries == [.importCV, .examples(examples), .blank])
    }

    @Test("every entry has its own identity")
    func entriesHaveDistinctIds() async {
        let world = Browsing()
        samples(world, ["Nurse"])
        let firstRun = world.firstRun()
        await firstRun.load()

        #expect(Set(firstRun.entries.map(\.id)).count == firstRun.entries.count)
        #expect(StartEntry.examplesIssue(.failed).id != StartEntry.examples([]).id)
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

        #expect(examples(firstRun)?.map(\.summary) == summaries)
    }

    @Test("blank is always the last entry")
    func blankIsListedLast() async {
        let world = Browsing()
        samples(world, ["Nurse", "Electrician"])
        let firstRun = world.firstRun()
        await firstRun.load()

        #expect(firstRun.entries.last == .blank)
        #expect(firstRun.entries.count == 3)
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
