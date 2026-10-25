import Testing
import SwiftUI
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Test Doubles for OnboardingViewModel and NewCVChoicesViewModel

@MainActor
final class MockOnboardingUseCase: OnboardingUseCaseProtocol {
    var checkOnboardingRequiredResult: OnboardingState = .firstTime
    
    private(set) var checkOnboardingRequiredCalled = false
    
    func checkOnboardingRequired() async -> OnboardingState {
        checkOnboardingRequiredCalled = true
        return checkOnboardingRequiredResult
    }
    
    func createFirstCV(from template: CVModel) async throws -> CVModel {
        template
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
    
    private func makeViewModel(onboardingUseCase: MockOnboardingUseCase? = nil) -> OnboardingViewModel {
        OnboardingViewModel(onboardingUseCase: onboardingUseCase ?? MockOnboardingUseCase())
    }
    
    @Test("ViewModel initializes with loading state")
    func viewModelInitializesWithLoadingState() {
        let viewModel = makeViewModel()
        
        #expect(viewModel.onboardingState == .loading)
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
}

// MARK: - Gate proof (throwaway)

@Suite("Gate proof")
struct GateProofTests {
    @Test("a deliberately failing test, to see the Mac mini check end in failure")
    func failsOnPurpose() {
        #expect(1 + 1 == 3)
    }
}
