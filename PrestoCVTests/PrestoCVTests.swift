import Testing
import SwiftUI
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Test Doubles for OnboardingViewModel

@MainActor
final class MockOnboardingUseCase: OnboardingUseCaseProtocol {
    var checkOnboardingRequiredResult: OnboardingState = .firstTime
    var createFirstCVResult: Result<CVModel, Error> = .success(CVModel(name: "Mock CV"))
    
    private(set) var checkOnboardingRequiredCalled = false
    private(set) var createFirstCVCalled = false
    
    func checkOnboardingRequired() async -> OnboardingState {
        checkOnboardingRequiredCalled = true
        return checkOnboardingRequiredResult
    }
    
    func createFirstCV(from template: CVModel) async throws -> CVModel {
        createFirstCVCalled = true
        switch createFirstCVResult {
        case .success(let cv):
            return cv
        case .failure(let error):
            throw error
        }
    }
}

@MainActor
final class MockSampleCVRepository: SampleCVRepositoryProtocol {
    var samples: [CVModel] = []
    var getAllSamplesError: Error?
    
    private(set) var getAllSamplesCallCount = 0
    
    func getDefaultSample() async throws -> CVModel {
        CVModel(name: "Default Template")
    }
    
    func getAllSamples() async throws -> [CVModel] {
        getAllSamplesCallCount += 1
        if let getAllSamplesError {
            throw getAllSamplesError
        }
        return samples
    }
    
    func getSample(by name: String) async throws -> CVModel? {
        nil
    }
}

// MARK: - OnboardingViewModel Tests

@MainActor
@Suite("OnboardingViewModel Tests")
struct OnboardingViewModelTests {
    
    private func makeViewModel(
        onboardingUseCase: MockOnboardingUseCase? = nil,
        sampleRepository: MockSampleCVRepository? = nil
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            onboardingUseCase: onboardingUseCase ?? MockOnboardingUseCase(),
            sampleRepository: sampleRepository ?? MockSampleCVRepository()
        )
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
    
    @Test("ViewModel initializes with loading state and no samples")
    func viewModelInitializesWithLoadingState() {
        let viewModel = makeViewModel()
        
        #expect(viewModel.onboardingState == .loading)
        #expect(viewModel.samples.isEmpty)
    }
    
    @Test("checkOnboardingStatus updates state to firstTime")
    func checkOnboardingStatusUpdatesStateToFirstTime() async {
        let mockOnboardingUseCase = MockOnboardingUseCase()
        mockOnboardingUseCase.checkOnboardingRequiredResult = .firstTime
        let viewModel = makeViewModel(onboardingUseCase: mockOnboardingUseCase)
        
        await viewModel.checkOnboardingStatus()
        
        #expect(viewModel.onboardingState == .firstTime)
        #expect(mockOnboardingUseCase.checkOnboardingRequiredCalled)
    }
    
    @Test("checkOnboardingStatus updates state to returning")
    func checkOnboardingStatusUpdatesStateToReturning() async {
        let mockOnboardingUseCase = MockOnboardingUseCase()
        mockOnboardingUseCase.checkOnboardingRequiredResult = .returning
        let viewModel = makeViewModel(onboardingUseCase: mockOnboardingUseCase)
        
        await viewModel.checkOnboardingStatus()
        
        #expect(viewModel.onboardingState == .returning)
        #expect(mockOnboardingUseCase.checkOnboardingRequiredCalled)
    }
    
    // MARK: - Samples
    
    @Test("loadSamples publishes the samples of the repository")
    func loadSamplesPublishesTheSamples() async {
        let sampleRepository = MockSampleCVRepository()
        sampleRepository.samples = [makeSample(), CVModel(name: "Second")]
        let viewModel = makeViewModel(sampleRepository: sampleRepository)
        
        await viewModel.loadSamples()
        
        #expect(viewModel.samples.map(\.name) == ["Senior Software Engineer - TechFlow Inc. Application", "Second"])
    }
    
    @Test("loadSamples reads the samples once, however often the first-run view appears")
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
    
    // MARK: - Drafts
    
    @Test("A draft has a new identity and no name of its own")
    func draftHasNewIdentityAndNoName() {
        let sample = makeSample()
        let draft = makeViewModel().makeDraft(from: sample)
        
        #expect(draft.id != sample.id)
        #expect(draft.name.isEmpty, "The list shows an unnamed CV as Untitled CV")
    }
    
    @Test("A draft leaves the details of the person of the sample blank")
    func draftClearsTheIdentityFields() {
        let draft = makeViewModel().makeDraft(from: makeSample())
        
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
        let draft = makeViewModel().makeDraft(from: sample)
        
        #expect(draft.personalInfo.title == sample.personalInfo.title)
        #expect(draft.personalInfo.profile == sample.personalInfo.profile)
        #expect(draft.relevant_experience == sample.relevant_experience)
        #expect(draft.education == sample.education)
        #expect(draft.skills == sample.skills)
        #expect(draft.languages == sample.languages)
        #expect(draft.interests == sample.interests)
    }
    
    @Test("Making a draft stores nothing")
    func draftIsNotPersisted() {
        let onboardingUseCase = MockOnboardingUseCase()
        let viewModel = makeViewModel(onboardingUseCase: onboardingUseCase)
        
        _ = viewModel.makeDraft(from: makeSample())
        
        #expect(!onboardingUseCase.createFirstCVCalled, "Nothing is stored until the user saves the CV in the editor")
    }
    
    @Test("Two drafts from the same sample are different CVs")
    func draftsHaveDistinctIds() {
        let sample = makeSample()
        let viewModel = makeViewModel()
        
        #expect(viewModel.makeDraft(from: sample).id != viewModel.makeDraft(from: sample).id)
    }
}
