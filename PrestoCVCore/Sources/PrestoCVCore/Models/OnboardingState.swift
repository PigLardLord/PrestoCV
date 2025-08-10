import Foundation

// MARK: - Onboarding State

public enum OnboardingState: Equatable, Sendable {
    case loading
    case firstTime
    case returning
    case error(AppError)
}