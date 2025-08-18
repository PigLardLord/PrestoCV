import Foundation

// MARK: - Dependency Container Protocol

/// Protocol for dependency injection container that provides configured instances
public protocol DependencyContainerProtocol {
    /// Creates a configured OnboardingUseCase instance with all required dependencies
    /// - Returns: OnboardingUseCaseProtocol implementation
    /// - Throws: AppError if dependency creation fails
    func makeOnboardingUseCase() throws -> OnboardingUseCaseProtocol
    
    /// Creates a configured CVManagementUseCase instance with all required dependencies  
    /// - Returns: CVManagementUseCaseProtocol implementation
    /// - Throws: AppError if dependency creation fails
    func makeCVManagementUseCase() throws -> CVManagementUseCaseProtocol
    
    /// Creates a configured SampleCVRepository instance with all required dependencies
    /// - Returns: SampleCVRepositoryProtocol implementation  
    /// - Throws: AppError if dependency creation fails
    func makeSampleCVRepository() throws -> SampleCVRepositoryProtocol
    
    /// Creates a configured TemplateCategoryService instance
    /// - Returns: TemplateCategoryServiceProtocol implementation
    /// - Throws: AppError if dependency creation fails
    func makeTemplateCategoryService() throws -> TemplateCategoryServiceProtocol
}