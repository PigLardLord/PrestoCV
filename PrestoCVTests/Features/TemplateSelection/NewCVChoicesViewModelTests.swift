import Testing
import CVGeneratorAI
@testable import PrestoCV
@testable import PrestoCVCore

@MainActor
@Suite("NewCVChoicesViewModel Tests - the AI card follows what the device can run now")
struct NewCVChoicesViewModelTests {

    /// An availability that a test can change between two reads, as turning Apple Intelligence on does.
    private final class Availability {
        var current: AIAvailability
        private(set) var reads = 0

        init(_ current: AIAvailability) { self.current = current }

        func read() -> AIAvailability {
            reads += 1
            return current
        }
    }

    /// The wait between two reads, without the clock: it counts the waits and can do something during one, as the
    /// model finishing its download does.
    @MainActor
    private final class Pauses {
        private(set) var count = 0
        var during: (Int) -> Void = { _ in }

        func pause() async throws {
            try Task.checkCancellation()
            count += 1
            during(count)
        }
    }

    /// A view model of a release that ships AI drafting, so that the tests do not depend on the release switch.
    private func makeViewModel(_ availability: Availability, pauses: Pauses) -> NewCVChoicesViewModel {
        NewCVChoicesViewModel(
            aiAvailability: { availability.read() },
            sampleRepository: MockSampleCVRepository(),
            pause: { try await pauses.pause() },
            isAIShipped: true
        )
    }

    private func makeViewModel(_ availability: Availability) -> NewCVChoicesViewModel {
        makeViewModel(availability, pauses: Pauses())
    }

    @Test("The entry is read from the provider when the view model is made")
    func entryIsReadAtStart() {
        let availability = Availability(.unavailable(.appleIntelligenceNotEnabled))

        let viewModel = makeViewModel(availability)

        #expect(viewModel.aiEntry == .disabled(.turnOnAppleIntelligence))
        #expect(availability.reads == 1)
    }

    @Test("Refreshing reads the availability again, so that turning Apple Intelligence on enables the card")
    func refreshReadsAgain() {
        let availability = Availability(.unavailable(.appleIntelligenceNotEnabled))
        let viewModel = makeViewModel(availability)

        availability.current = .available
        viewModel.refreshAIAvailability()

        #expect(viewModel.aiEntry == .available)
        #expect(availability.reads == 2)
    }

    @Test("A model that finished downloading enables the card on the next refresh")
    func downloadFinishing() {
        let availability = Availability(.unavailable(.modelNotReady))
        let viewModel = makeViewModel(availability)
        #expect(viewModel.aiEntry == .disabled(.modelStillDownloading))

        availability.current = .available
        viewModel.refreshAIAvailability()

        #expect(viewModel.aiEntry == .available)
    }

    @Test("While the model downloads, the card is read again after each pause and turns on by itself when it is ready")
    func followingEnablesTheCardWhenTheDownloadEnds() async {
        let availability = Availability(.unavailable(.modelNotReady))
        let pauses = Pauses()
        pauses.during = { count in
            if count == 3 { availability.current = .available }
        }
        let viewModel = makeViewModel(availability, pauses: pauses)

        await viewModel.followAIAvailability()

        #expect(viewModel.aiEntry == .available)
        #expect(pauses.count == 3, "The reads stop once the card works")
        #expect(availability.reads == 4)
    }

    @Test("Following reads nothing again when the entry cannot change by itself",
          arguments: [AIAvailability.available, .unavailable(.deviceNotEligible), .unavailable(.appleIntelligenceNotEnabled)])
    func followingStopsAtOnceForASettledEntry(start: AIAvailability) async {
        let availability = Availability(start)
        let pauses = Pauses()
        let viewModel = makeViewModel(availability, pauses: pauses)

        await viewModel.followAIAvailability()

        #expect(pauses.count == 0)
        #expect(availability.reads == 1)
    }

    @Test("A model that stops being ready for good, on a device found not eligible, ends the reads and hides the card")
    func followingStopsAtAFinalState() async {
        let availability = Availability(.unavailable(.modelNotReady))
        let pauses = Pauses()
        pauses.during = { _ in availability.current = .unavailable(.deviceNotEligible) }
        let viewModel = makeViewModel(availability, pauses: pauses)

        await viewModel.followAIAvailability()

        #expect(viewModel.aiEntry == .hidden)
        #expect(pauses.count == 1)
    }

    @Test("When the screen goes away its task is cancelled, and the availability is not read again",
          .timeLimit(.minutes(1)))
    func cancellingEndsTheReads() async {
        let availability = Availability(.unavailable(.modelNotReady))
        let pauses = Pauses()
        // The first pause is long: only the cancellation ends it
        let viewModel = NewCVChoicesViewModel(aiAvailability: { availability.read() }, sampleRepository: MockSampleCVRepository(), pause: {
            try await pauses.pause()
            try await Task.sleep(for: .seconds(3600))
        }, isAIShipped: true)

        let screen = Task { await viewModel.followAIAvailability() }
        while pauses.count == 0 { await Task.yield() }
        screen.cancel()
        await screen.value
        availability.current = .available

        #expect(availability.reads == 1, "No read after the cancellation")
        #expect(viewModel.aiEntry == .disabled(.modelStillDownloading))
    }

    @Test("A device that is not eligible has no entry, and still has none after a refresh")
    func notEligibleStaysHidden() {
        let availability = Availability(.unavailable(.deviceNotEligible))
        let viewModel = makeViewModel(availability)

        viewModel.refreshAIAvailability()

        #expect(viewModel.aiEntry == .hidden)
    }

    @Test("A release that does not ship AI drafting has no entry whatever the availability, and does not follow it",
          .timeLimit(.minutes(1)),
          arguments: [
              AIAvailability.available,
              .unavailable(.deviceNotEligible),
              .unavailable(.appleIntelligenceNotEnabled),
              .unavailable(.modelNotReady),
              .unavailable(.unknown),
          ])
    func notShippedHasNoEntry(availability start: AIAvailability) async {
        let availability = Availability(start)
        let pauses = Pauses()
        let viewModel = NewCVChoicesViewModel(
            aiAvailability: { availability.read() },
            sampleRepository: MockSampleCVRepository(),
            pause: { try await pauses.pause() },
            isAIShipped: false
        )

        viewModel.refreshAIAvailability()
        await viewModel.followAIAvailability()

        #expect(viewModel.aiEntry == .hidden)
        #expect(pauses.count == 0, "Nothing to wait for: the entry stays hidden")
    }

    // MARK: - Examples

    private func makeViewModel(sampleRepository: MockSampleCVRepository) -> NewCVChoicesViewModel {
        NewCVChoicesViewModel(aiAvailability: { .available }, sampleRepository: sampleRepository, isAIShipped: true)
    }

    private func makeSample() -> CVModel {
        CVModel(
            name: "Senior Software Engineer - TechFlow Inc. Application",
            personalInfo: PersonalInfo(
                name: "Alex Morgan",
                title: "Senior Software Engineer",
                location: "San Francisco, CA",
                email: "alex.morgan@example.com",
                phone: "+1 (555) 123-4567",
                portfolio: "https://example.com",
                profile: "Senior engineer with 8+ years of experience."
            ),
            relevant_experience: [Experience(title: "Senior Software Engineer", company: "TechFlow Inc.")],
            education: [Education(degree: "BSc Computer Science", school: "State University")],
            skills: [Skill(name: "Swift", level: 5)],
            languages: [Language(name: "English")],
            interests: ["Chess"],
            social: [Social(platform: "GitHub", url: "https://example.com/github")]
        )
    }

    @Test("There are no samples until they are loaded")
    func noSamplesAtStart() {
        #expect(makeViewModel(sampleRepository: MockSampleCVRepository()).samples.isEmpty)
    }

    @Test("loadSamples publishes the samples of the repository")
    func loadSamplesPublishesTheSamples() async {
        let sampleRepository = MockSampleCVRepository()
        sampleRepository.samples = [makeSample(), CVModel(name: "Second")]
        let viewModel = makeViewModel(sampleRepository: sampleRepository)

        await viewModel.loadSamples()

        #expect(viewModel.samples.map(\.name) == ["Senior Software Engineer - TechFlow Inc. Application", "Second"])
    }

    @Test("loadSamples reads the samples once, however often the screen appears")
    func loadSamplesReadsOnce() async {
        let sampleRepository = MockSampleCVRepository()
        sampleRepository.samples = [makeSample()]
        let viewModel = makeViewModel(sampleRepository: sampleRepository)

        await viewModel.loadSamples()
        await viewModel.loadSamples()

        #expect(sampleRepository.getAllSamplesCallCount == 1)
        #expect(viewModel.samples.count == 1)
    }

    @Test("loadSamples leaves no samples when they cannot be loaded, and a later call tries again")
    func loadSamplesFailureLeavesNoSamples() async {
        let sampleRepository = MockSampleCVRepository()
        sampleRepository.getAllSamplesError = AppError.fileSystemError("unreadable")
        let viewModel = makeViewModel(sampleRepository: sampleRepository)

        await viewModel.loadSamples()
        #expect(viewModel.samples.isEmpty)

        sampleRepository.getAllSamplesError = nil
        sampleRepository.samples = [makeSample()]
        await viewModel.loadSamples()
        #expect(viewModel.samples.count == 1)
        #expect(sampleRepository.getAllSamplesCallCount == 2)
    }

    @Test("A blank draft is an empty CV, and each one is a CV of its own")
    func blankDraftIsEmpty() {
        let viewModel = makeViewModel(sampleRepository: MockSampleCVRepository())

        let draft = viewModel.makeBlankDraft()

        #expect(draft == CVModel(id: draft.id), "Nothing is filled in")
        #expect(viewModel.makeBlankDraft().id != draft.id)
    }

    @Test("Each example is listed under the job it is for, with what it says of its person; one without a job as Untitled CV")
    func examplesAreListedUnderTheirJob() async {
        let sampleRepository = MockSampleCVRepository()
        let withoutJob = CVModel(name: "Second", personalInfo: PersonalInfo(profile: "A summary."))
        sampleRepository.samples = [makeSample(), withoutJob]
        let viewModel = makeViewModel(sampleRepository: sampleRepository)

        await viewModel.loadSamples()

        #expect(viewModel.examples == [
            ExampleChoice(sample: viewModel.samples[0], title: "Senior Software Engineer", summary: "Senior engineer with 8+ years of experience."),
            ExampleChoice(sample: withoutJob, title: "cv.untitled".localized, summary: "A summary."),
        ])
    }

    @Test("A draft has a new identity and no name of its own")
    func draftHasNewIdentityAndNoName() {
        let sample = makeSample()
        let draft = makeViewModel(sampleRepository: MockSampleCVRepository()).makeDraft(from: sample)

        #expect(draft.id != sample.id)
        #expect(draft.name.isEmpty, "The list shows an unnamed CV as Untitled CV")
    }

    @Test("A draft leaves the details of the person of the sample blank")
    func draftClearsTheIdentityFields() {
        let draft = makeViewModel(sampleRepository: MockSampleCVRepository()).makeDraft(from: makeSample())

        #expect(draft.personalInfo.name.isEmpty)
        #expect(draft.personalInfo.email.isEmpty)
        #expect(draft.personalInfo.phone.isEmpty)
        #expect(draft.personalInfo.location.isEmpty)
        #expect(draft.personalInfo.portfolio.isEmpty)
        #expect(draft.social.map(\.url) == [""], "The links are cleared")
        #expect(draft.social.map(\.platform) == ["GitHub"], "The platforms stay as a hint")
    }

    @Test("A draft keeps the content of the sample")
    func draftKeepsTheContent() {
        let sample = makeSample()
        let draft = makeViewModel(sampleRepository: MockSampleCVRepository()).makeDraft(from: sample)

        #expect(draft.personalInfo.title == sample.personalInfo.title)
        #expect(draft.personalInfo.profile == sample.personalInfo.profile)
        #expect(draft.relevant_experience == sample.relevant_experience)
        #expect(draft.education == sample.education)
        #expect(draft.skills == sample.skills)
        #expect(draft.languages == sample.languages)
        #expect(draft.interests == sample.interests)
    }

    @Test("Two drafts from the same sample are different CVs")
    func draftsHaveDistinctIds() {
        let sample = makeSample()
        let viewModel = makeViewModel(sampleRepository: MockSampleCVRepository())

        #expect(viewModel.makeDraft(from: sample).id != viewModel.makeDraft(from: sample).id)
    }
}
