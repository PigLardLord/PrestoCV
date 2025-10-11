import Foundation
#if canImport(FoundationIntelligence)
import FoundationIntelligence
#endif

/// CV generation service using Apple's FoundationModels
@available(iOS 18.2, macOS 15.2, *)
public final class FoundationModelsService: CVGenerationService {

    public init() {}

    public func isAvailable() async -> Bool {
        #if canImport(FoundationIntelligence)
        // Check if FoundationModels is available on this device
        // This will return false on simulator or unsupported devices
        return true // TODO: Implement actual availability check
        #else
        return false
        #endif
    }

    public func generateCV(from request: CVGenerationRequest) async throws -> CVGenerationResult {
        #if canImport(FoundationIntelligence)
        guard await isAvailable() else {
            throw CVGenerationError.serviceUnavailable
        }

        // Validate request
        guard !request.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CVGenerationError.invalidPrompt
        }

        let startTime = Date()

        // Build system prompt and user prompt
        let systemPrompt = buildSystemPrompt(for: request.preferences)
        let userPrompt = buildUserPrompt(from: request)

        // TODO: Call FoundationModels API
        // For now, throw not implemented
        throw CVGenerationError.unknown("FoundationModels integration pending")

        #else
        throw CVGenerationError.serviceUnavailable
        #endif
    }

    // MARK: - Private Helpers

    private func buildSystemPrompt(for preferences: GenerationPreferences) -> String {
        """
        You are a professional CV/resume writing assistant. Your task is to generate a comprehensive, \
        well-structured CV from the user's background description.

        Guidelines:
        - Extract all relevant information about work experience, education, skills, and achievements
        - Format dates consistently (e.g., "Jan 2020", "2020-2023")
        - Use professional language with a \(preferences.tone.rawValue.lowercased()) tone
        - Focus on quantifiable achievements and impact
        - Organize information logically and comprehensively

        Return ONLY valid JSON matching the CVData structure. Do not include any explanatory text.
        """
    }

    private func buildUserPrompt(from request: CVGenerationRequest) -> String {
        var prompt = "Generate a CV from the following information:\n\n"

        if let personalInfo = request.personalInfo {
            prompt += "Personal Information:\n"
            prompt += "Name: \(personalInfo.name)\n"
            prompt += "Email: \(personalInfo.email)\n"
            if let phone = personalInfo.phone {
                prompt += "Phone: \(phone)\n"
            }
            if let location = personalInfo.location {
                prompt += "Location: \(location)\n"
            }
            prompt += "\n"
        }

        if let targetRole = request.preferences.targetRole {
            prompt += "Target Role: \(targetRole)\n\n"
        }

        prompt += "Background Description:\n\(request.userPrompt)\n\n"

        if !request.preferences.focusAreas.isEmpty {
            prompt += "Focus Areas: \(request.preferences.focusAreas.joined(separator: ", "))\n"
        }

        return prompt
    }
}
