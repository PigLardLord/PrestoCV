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
    var getDefaultSampleResult: Result<CVModel, Error> = .success(CVModel(name: "Default Template"))
    
    private(set) var getDefaultSampleCalled = false
    
    func getDefaultSample() async throws -> CVModel {
        getDefaultSampleCalled = true
        switch getDefaultSampleResult {
        case .success(let template):
            return template
        case .failure(let error):
            throw error
        }
    }
    
    func getAllSamples() async throws -> [CVModel] {
        return [try await getDefaultSample()]
    }
    
    func getSample(by name: String) async throws -> CVModel? {
        if name == "default" {
            return try await getDefaultSample()
        }
        return nil
    }
}

// MARK: - OnboardingViewModel Tests

@MainActor
@Suite("OnboardingViewModel Tests")
struct OnboardingViewModelTests {
    
    @Test("ViewModel initializes with loading state")
    func viewModelInitializesWithLoadingState() {
        let mockOnboardingUseCase = MockOnboardingUseCase()
        let mockSampleRepository = MockSampleCVRepository()
        
        let viewModel = OnboardingViewModel(
            onboardingUseCase: mockOnboardingUseCase,
            sampleRepository: mockSampleRepository
        )
        
        #expect(viewModel.onboardingState == .loading)
        #expect(viewModel.isCreatingCV == false)
        #expect(viewModel.errorMessage.isEmpty)
    }
    
    @Test("checkOnboardingStatus updates state to firstTime")
    func checkOnboardingStatusUpdatesStateToFirstTime() async {
        let mockOnboardingUseCase = MockOnboardingUseCase()
        let mockSampleRepository = MockSampleCVRepository()
        mockOnboardingUseCase.checkOnboardingRequiredResult = .firstTime
        
        let viewModel = OnboardingViewModel(
            onboardingUseCase: mockOnboardingUseCase,
            sampleRepository: mockSampleRepository
        )
        
        await viewModel.checkOnboardingStatus()
        
        #expect(viewModel.onboardingState == .firstTime)
        #expect(mockOnboardingUseCase.checkOnboardingRequiredCalled)
    }
    
    @Test("checkOnboardingStatus updates state to returning")
    func checkOnboardingStatusUpdatesStateToReturning() async {
        let mockOnboardingUseCase = MockOnboardingUseCase()
        let mockSampleRepository = MockSampleCVRepository()
        mockOnboardingUseCase.checkOnboardingRequiredResult = .returning
        
        let viewModel = OnboardingViewModel(
            onboardingUseCase: mockOnboardingUseCase,
            sampleRepository: mockSampleRepository
        )
        
        await viewModel.checkOnboardingStatus()
        
        #expect(viewModel.onboardingState == .returning)
        #expect(mockOnboardingUseCase.checkOnboardingRequiredCalled)
    }
    
    @Test("createFirstCV succeeds and updates state")
    func createFirstCVSucceedsAndUpdatesState() async {
        let mockOnboardingUseCase = MockOnboardingUseCase()
        let mockSampleRepository = MockSampleCVRepository()
        
        let viewModel = OnboardingViewModel(
            onboardingUseCase: mockOnboardingUseCase,
            sampleRepository: mockSampleRepository
        )
        viewModel.onboardingState = .firstTime
        
        await viewModel.createFirstCV()
        
        #expect(viewModel.onboardingState == .returning)
        #expect(viewModel.isCreatingCV == false)
        #expect(viewModel.errorMessage.isEmpty)
        #expect(mockSampleRepository.getDefaultSampleCalled)
        #expect(mockOnboardingUseCase.createFirstCVCalled)
    }
    
    @Test("createFirstCV handles template error")
    func createFirstCVHandlesTemplateError() async {
        let mockOnboardingUseCase = MockOnboardingUseCase()
        let mockSampleRepository = MockSampleCVRepository()
        mockSampleRepository.getDefaultSampleResult = .failure(AppError.notFound("Template"))
        
        let viewModel = OnboardingViewModel(
            onboardingUseCase: mockOnboardingUseCase,
            sampleRepository: mockSampleRepository
        )
        viewModel.onboardingState = .firstTime
        
        await viewModel.createFirstCV()
        
        #expect(viewModel.onboardingState == .firstTime) // Should remain unchanged
        #expect(viewModel.isCreatingCV == false)
        #expect(!viewModel.errorMessage.isEmpty)
        #expect(mockSampleRepository.getDefaultSampleCalled)
        #expect(!mockOnboardingUseCase.createFirstCVCalled)
    }
    
    @Test("createFirstCV handles use case error")
    func createFirstCVHandlesUseCaseError() async {
        let mockOnboardingUseCase = MockOnboardingUseCase()
        let mockSampleRepository = MockSampleCVRepository()
        mockOnboardingUseCase.createFirstCVResult = .failure(AppError.fileSystemError("Test error"))
        
        let viewModel = OnboardingViewModel(
            onboardingUseCase: mockOnboardingUseCase,
            sampleRepository: mockSampleRepository
        )
        viewModel.onboardingState = .firstTime
        
        await viewModel.createFirstCV()
        
        #expect(viewModel.onboardingState == .firstTime) // Should remain unchanged
        #expect(viewModel.isCreatingCV == false)
        #expect(!viewModel.errorMessage.isEmpty)
        #expect(mockSampleRepository.getDefaultSampleCalled)
        #expect(mockOnboardingUseCase.createFirstCVCalled)
    }
    
    @Test("createFirstCV does nothing when not in firstTime state")
    func createFirstCVDoesNothingWhenNotInFirstTimeState() async {
        let mockOnboardingUseCase = MockOnboardingUseCase()
        let mockSampleRepository = MockSampleCVRepository()
        
        let viewModel = OnboardingViewModel(
            onboardingUseCase: mockOnboardingUseCase,
            sampleRepository: mockSampleRepository
        )
        viewModel.onboardingState = .returning
        
        await viewModel.createFirstCV()
        
        #expect(viewModel.onboardingState == .returning)
        #expect(!mockSampleRepository.getDefaultSampleCalled)
        #expect(!mockOnboardingUseCase.createFirstCVCalled)
    }
}