import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// CV generation service using Apple's FoundationModels
/// Requires iOS 26+ / macOS 26+ and Apple Intelligence-capable device
@available(iOS 26, macOS 26, *)
public final class FoundationModelsService: CVGenerationService {

    public init() {}

    @available(iOS 26, macOS 26, *)
    public func isAvailable() async -> Bool {
        #if canImport(FoundationModels)
        // Check if Apple Intelligence and the language model are available
        return SystemLanguageModel.default.isAvailable
        #else
        return false
        #endif
    }

    @available(iOS 26, macOS 26, *)
    public func generateCV(from request: CVGenerationRequest) async throws -> CVGenerationResult {
        #if canImport(FoundationModels)
        guard await isAvailable() else {
            throw CVGenerationError.serviceUnavailable
        }

        // Validate request
        guard !request.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CVGenerationError.invalidPrompt
        }

        let startTime = Date()

        // Create language model session
        let session = LanguageModelSession()

        // Build comprehensive prompt
        let prompt = buildPrompt(from: request)

        #if DEBUG
        print("🔍 DEBUG: Prompt length: \(prompt.count)")
        print("🔍 DEBUG: Prompt preview: \(String(prompt.prefix(300)))")
        #endif

        do {
            // Generate CV using structured output
            // Note: We'll get JSON back which we can decode to CVData
            let response = try await session.respond(to: prompt)

            // Debug: Log response for troubleshooting
            #if DEBUG
            print("🔍 DEBUG: Response content length: \(response.content.count)")
            print("🔍 DEBUG: Response preview: \(String(response.content.prefix(200)))")
            #endif

            // Parse the JSON response into our CVData model
            let cvData = try parseResponse(response.content, request: request, startTime: startTime)

            // Calculate confidence based on response quality
            let confidence = calculateConfidence(cvData: cvData)

            let processingTime = Date().timeIntervalSince(startTime)

            return CVGenerationResult(
                cvData: cvData,
                confidence: confidence,
                suggestions: generateSuggestions(cvData: cvData),
                metadata: ResultMetadata(
                    generatedAt: Date(),
                    processingTime: processingTime,
                    modelVersion: "foundation-models-1.0"
                )
            )

        } catch {
            // Handle FoundationModels specific errors
            #if DEBUG
            print("🔍 DEBUG: Error type: \(type(of: error))")
            print("🔍 DEBUG: Error: \(error)")
            #endif
            throw CVGenerationError.unknown("Failed to generate CV: \(error.localizedDescription) - Type: \(type(of: error))")
        }

        #else
        throw CVGenerationError.serviceUnavailable
        #endif
    }

    // MARK: - Private Helpers

    private func buildPrompt(from request: CVGenerationRequest) -> String {
        var prompt = """
        You are an expert CV writer creating PRODUCTION-QUALITY professional CVs. Your output must match senior-level professional standards.

        CRITICAL QUALITY REQUIREMENTS:
        - Write CONCISE, IMPACTFUL descriptions using bullet points (•) for achievements
        - Lead with QUANTIFIABLE RESULTS and CONCRETE OUTCOMES (numbers, metrics, impact)
        - Use STRONG ACTION VERBS (Led, Built, Implemented, Delivered, Optimized, Designed)
        - Focus on BUSINESS VALUE and REAL IMPACT, not generic responsibilities
        - Keep descriptions SHORT and POWERFUL - avoid fluff or generic statements
        - Professional summary: 3-4 sentences max, highlighting expertise and proven track record

        EXTRACTION RULES (CRITICAL):
        - Extract ALL company names, university names, and locations EXACTLY as mentioned
        - Use ONLY information provided - NEVER invent or assume details
        - Companies: exact name (e.g., "Acme Mobile Solutions", "Initech")
        - Universities: exact institution name (e.g., "Università degli Studi di Esempio")
        - Locations: cities/countries as mentioned (e.g., "Genoa, Italy", "Berlin, Germany")
        - Dates: consistent format (e.g., "March 2019 – Present", "2015")
        - Calculate experience duration (e.g., "6+ years", "3 years")

        SKILLS & TECHNOLOGIES:
        - Infer relevant technical skills from job roles and industry context
        - Group skills by category (e.g., "Languages", "Frameworks", "Tools", "Architecture")
        - Only include skills that make sense for the profession mentioned
        - Be specific with technology names (e.g., "Swift", "SwiftUI", "Git", not just "programming")

        LANGUAGE INFERENCE:
        - If prompt is in English, add English with proficiency C2 or Fluent
        - If user mentions native language, mark as Native
        - Add other languages only if explicitly mentioned

        PROFESSIONAL TONE:
        - \(request.preferences.tone.rawValue) style
        - Focus on achievements, not just duties
        - Emphasize leadership, collaboration, and technical excellence where applicable

        """

        // Add personal information if provided
        if let personalInfo = request.personalInfo {
            prompt += "\nPersonal Information:\n"
            prompt += "- Name: \(personalInfo.name)\n"
            prompt += "- Email: \(personalInfo.email)\n"
            if let phone = personalInfo.phone {
                prompt += "- Phone: \(phone)\n"
            }
            if let location = personalInfo.location {
                prompt += "- Location: \(location)\n"
            }
            if let title = personalInfo.title {
                prompt += "- Current/Desired Title: \(title)\n"
            }
        }

        // Add target role
        if let targetRole = request.preferences.targetRole {
            prompt += "\nTarget Role: \(targetRole)\n"
        }

        // Add experience level context
        prompt += "\nExperience Level: \(request.preferences.experienceLevel.rawValue)\n"

        // Add focus areas if any
        if !request.preferences.focusAreas.isEmpty {
            prompt += "\nFocus Areas: \(request.preferences.focusAreas.joined(separator: ", "))\n"
        }

        // Add the user's background description
        prompt += """

        Background Description:
        \(request.userPrompt)

        QUALITY EXAMPLES (adapt style to user's profession):

        Tech/Engineering:
        - "Lead iOS development for a retail banking app. • Built and maintain 2 production apps • Mentor 3 junior engineers"

        Healthcare:
        - "Emergency Medicine Physician managing high-acuity cases in 400-bed trauma center. • Treated 2,000+ patients annually with 98% patient satisfaction rate • Led implementation of new triage protocol reducing wait times by 35% • Mentored 15 medical residents in emergency procedures"

        UX/Design:
        - "Lead UX Designer for fintech platform serving 500K+ users. • Redesigned checkout flow increasing conversion rate by 40% • Conducted 50+ user research sessions informing product roadmap • Established design system adopted across 8 product teams reducing development time by 25%"

        HR/Management:
        - "HR Manager overseeing talent acquisition and retention for 200+ employee tech company. • Reduced time-to-hire by 45% through streamlined recruitment process • Implemented employee development program improving retention rate from 75% to 92% • Led diversity initiative increasing underrepresented hires by 60%"

        Business/Sales:
        - "Regional Sales Director managing $5M revenue territory across EMEA. • Exceeded quota by 150% for 3 consecutive years • Built and led team of 12 sales representatives • Secured 20+ enterprise contracts with Fortune 500 companies worth $2M+ annually"

        Generate a CV with the following structure in JSON format:
        {
          "personalInfo": {
            "name": "string",
            "email": "string",
            "phone": "string (optional)",
            "location": "string (optional)",
            "website": "string (optional)",
            "linkedin": "string (optional)",
            "github": "string (optional)",
            "title": "string (optional)"
          },
          "summary": "string - professional summary paragraph",
          "experience": [
            {
              "title": "job title",
              "company": "EXACT company name from description",
              "location": "city, country if mentioned",
              "startDate": "year or month year",
              "endDate": "year or 'Present' for current",
              "current": boolean,
              "description": "role description",
              "achievements": ["achievement 1", "achievement 2"],
              "technologies": ["tech1", "tech2"]
            }
          ],
          "education": [
            {
              "degree": "degree type and field",
              "institution": "EXACT university name from description",
              "location": "city, country if mentioned",
              "startDate": "year",
              "endDate": "year",
              "gpa": "if mentioned",
              "description": "additional details",
              "achievements": ["honor/award"]
            }
          ],
          "skills": [
            {
              "name": "skill name",
              "level": "Expert|Advanced|Intermediate|Beginner",
              "category": "Programming Languages|Frameworks|Tools|etc",
              "yearsOfExperience": number
            }
          ],
          "languages": [
            {
              "name": "language name",
              "proficiency": "Native|C2|C1|B2|B1|A2|A1 (MUST use exactly these values)"
            }
          ],
          "certifications": [
            {
              "name": "certification name",
              "issuer": "issuing organization",
              "date": "year",
              "expiryDate": "year (optional)",
              "credentialId": "id (optional)",
              "url": "url (optional)"
            }
          ],
          "projects": [
            {
              "name": "project name",
              "description": "project description",
              "role": "your role",
              "startDate": "year (optional)",
              "endDate": "year (optional)",
              "technologies": ["tech1", "tech2"],
              "url": "url (optional)",
              "achievements": ["achievement"]
            }
          ],
          "interests": ["interest1", "interest2"]
        }

        Return ONLY the JSON object, no additional text or explanation.
        """

        return prompt
    }

    private func parseResponse(_ content: String, request: CVGenerationRequest, startTime: Date) throws -> CVData {
        // Clean up the response - remove markdown code blocks if present
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)

        #if DEBUG
        print("🔍 DEBUG: Parsing response, original length: \(jsonString.count)")
        #endif

        // Remove markdown JSON code blocks
        if jsonString.hasPrefix("```json") {
            jsonString = jsonString.replacingOccurrences(of: "```json", with: "")
            jsonString = jsonString.replacingOccurrences(of: "```", with: "")
            jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if jsonString.hasPrefix("```") {
            jsonString = jsonString.replacingOccurrences(of: "```", with: "")
            jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            #if DEBUG
            print("🔍 DEBUG: Failed to convert string to data")
            #endif
            throw CVGenerationError.invalidResponse
        }

        // Decode the JSON into a temporary structure
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let response = try decoder.decode(AIGeneratedCV.self, from: jsonData)
            let personalInfo = request.personalInfo ?? response.personalInfo

            return CVData(
                id: UUID(),
                personalInfo: personalInfo,
                summary: response.summary,
                experience: response.experience,
                education: response.education,
                skills: response.skills,
                languages: response.languages,
                certifications: response.certifications,
                projects: response.projects,
                interests: response.interests,
                metadata: CVMetadata(
                    generatedAt: Date(),
                    generatedBy: "FoundationModels",
                    version: "1.0"
                )
            )
        } catch {
            #if DEBUG
            print("🔍 DEBUG: JSON decode failed: \(error)")
            print("🔍 DEBUG: JSON string (first 500 chars): \(String(jsonString.prefix(500)))")
            #endif
            throw CVGenerationError.invalidResponse
        }
    }

    private func calculateConfidence(cvData: CVData) -> Double {
        var confidence = 0.7

        // Increase confidence based on completeness
        if !cvData.experience.isEmpty { confidence += 0.05 }
        if !cvData.education.isEmpty { confidence += 0.05 }
        if !cvData.skills.isEmpty { confidence += 0.05 }
        if cvData.summary != nil && cvData.summary!.count > 100 { confidence += 0.05 }
        if !cvData.certifications.isEmpty { confidence += 0.025 }
        if !cvData.projects.isEmpty { confidence += 0.025 }

        return min(confidence, 0.95)
    }

    private func generateSuggestions(cvData: CVData) -> [String] {
        var suggestions: [String] = []

        if cvData.certifications.isEmpty {
            suggestions.append("Consider adding relevant certifications to strengthen your profile")
        }
        if cvData.projects.isEmpty {
            suggestions.append("Include notable projects or contributions to demonstrate your skills")
        }
        if cvData.summary == nil || cvData.summary!.count < 100 {
            suggestions.append("Expand your professional summary with more details about your expertise")
        }
        if cvData.experience.allSatisfy({ $0.achievements.isEmpty }) {
            suggestions.append("Add quantifiable achievements to your work experience")
        }

        return suggestions
    }
}

// MARK: - AI Response Structure

private struct AIGeneratedCV: Codable {
    let personalInfo: PersonalInfo
    let summary: String?
    let experience: [Experience]
    let education: [Education]
    let skills: [Skill]
    let languages: [Language]
    let certifications: [Certification]
    let projects: [Project]
    let interests: [String]
}
