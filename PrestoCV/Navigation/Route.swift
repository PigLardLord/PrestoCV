import Foundation

// MARK: - App Routes

enum Route: Hashable, Sendable {
    case onboarding
    case cvList
    case cvEditor(cvId: String?)
    case templateSelection
    case aiGeneration
}