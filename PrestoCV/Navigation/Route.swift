import Foundation

// MARK: - App Routes

enum Route: Hashable, Sendable {
    case onboarding
    case cvList
    case cvEditor(EditorRequest)
    case templateSelection
    case aiGeneration
}