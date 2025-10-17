import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Feature flags for controlling availability of features
enum FeatureFlags {

    /// AI-powered CV generation using Foundation Models
    /// - Requires: iOS 26+, macOS 26+, and Apple Intelligence-capable device
    /// - Returns: true if AI generation is available on this device
    static var isAIGenerationAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            return true
        }
        #endif
        return false
    }

    /// Check if AI generation is actually functional (device + OS + Apple Intelligence)
    /// - Returns: true if AI can be used now
    @MainActor
    static func checkAIGenerationCapability() async -> Bool {
        guard isAIGenerationAvailable else {
            return false
        }

        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif

        return false
    }
}
