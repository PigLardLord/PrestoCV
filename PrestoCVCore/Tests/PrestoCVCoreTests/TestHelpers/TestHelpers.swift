import Testing
import Foundation
@testable import PrestoCVCore

public struct TestHelpers {
    /// Creates a test container with automatic cleanup
    public static func withTestContainer<T>(
        _ operation: (TestDependencyContainer) async throws -> T
    ) async rethrows -> T {
        let container = TestDependencyContainer()
        defer { container.reset() }
        return try await operation(container)
    }
    
    /// Creates a CV management use case with container cleanup
    public static func withCVManagementUseCase<T>(
        _ operation: (CVManagementUseCaseProtocol) async throws -> T
    ) async rethrows -> T {
        return try await withTestContainer { container in
            let useCase = try container.makeCVManagementUseCase()
            return try await operation(useCase)
        }
    }
    
    /// Creates both onboarding and CV management use cases with container cleanup
    public static func withUseCases<T>(
        _ operation: (OnboardingUseCaseProtocol, CVManagementUseCaseProtocol) async throws -> T
    ) async rethrows -> T {
        return try await withTestContainer { container in
            let onboardingUseCase = try container.makeOnboardingUseCase()
            let cvManagementUseCase = try container.makeCVManagementUseCase()
            return try await operation(onboardingUseCase, cvManagementUseCase)
        }
    }
}