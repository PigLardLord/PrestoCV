import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// CV generation service using Apple's FoundationModels
/// Requires iOS 26+ / macOS 26+ and Apple Intelligence-capable device
@available(iOS 26, macOS 26, *)
@MainActor
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

        // Create language model session with system instructions
        let session = LanguageModelSession(
            instructions: Instructions {
                "You are an expert CV writer creating PRODUCTION-QUALITY professional CVs matching senior-level standards."

                """
                CRITICAL REQUIREMENTS:
                - CONCISE, IMPACTFUL descriptions with quantifiable results
                - STRONG ACTION VERBS (Led, Built, Implemented, Delivered)
                - Extract company/university names EXACTLY as mentioned
                - Professional summary: 3-4 sentences max
                - Infer relevant technical skills from context
                """

                """
                LANGUAGE INFERENCE:
                - If prompt is in English, add English with C2 proficiency
                - Mark native language as Native
                """
            }
        )

        do {
            // Generate CV using guided generation
            let stream = session.streamResponse(
                generating: CVData.self,
                includeSchemaInPrompt: false,
                options: GenerationOptions(sampling: .greedy)
            ) {
                "PROFESSIONAL TONE: \(request.preferences.tone.rawValue) style"
                "Experience Level: \(request.preferences.experienceLevel.rawValue)"

                if let personalInfo = request.personalInfo {
                    "Personal Info: \(personalInfo.name), \(personalInfo.email)"
                }

                if let targetRole = request.preferences.targetRole {
                    "Target Role: \(targetRole)"
                }

                "Background Description:"
                request.userPrompt
            }

            // Collect final result - the last item in stream is the complete generation
            var finalCVData: CVData?
            for try await partialResponse in stream {
                // Try to construct complete CVData from partial if all required fields are present
                if let personalInfoPartial = partialResponse.content.personalInfo,
                   let name = personalInfoPartial.name,
                   let email = personalInfoPartial.email {

                    let personalInfo = PersonalInfo(
                        name: name,
                        email: email,
                        phone: personalInfoPartial.phone,
                        location: personalInfoPartial.location,
                        website: personalInfoPartial.website,
                        linkedin: personalInfoPartial.linkedin,
                        github: personalInfoPartial.github,
                        title: personalInfoPartial.title
                    )

                    let experience = partialResponse.content.experience?.compactMap { expPartial in
                        convertExperience(expPartial)
                    } ?? []

                    let education = partialResponse.content.education?.compactMap { eduPartial in
                        convertEducation(eduPartial)
                    } ?? []

                    let skills = partialResponse.content.skills?.compactMap { skillPartial in
                        convertSkill(skillPartial)
                    } ?? []

                    let languages = partialResponse.content.languages?.compactMap { langPartial in
                        convertLanguage(langPartial)
                    } ?? []

                    let certifications = partialResponse.content.certifications?.compactMap { certPartial in
                        convertCertification(certPartial)
                    } ?? []

                    let projects = partialResponse.content.projects?.compactMap { projPartial in
                        convertProject(projPartial)
                    } ?? []

                    let interests = partialResponse.content.interests?.compactMap { $0 } ?? []

                    finalCVData = CVData(
                        personalInfo: personalInfo,
                        summary: partialResponse.content.summary,
                        experience: experience,
                        education: education,
                        skills: skills,
                        languages: languages,
                        certifications: certifications,
                        projects: projects,
                        interests: interests
                    )
                }
            }

            guard let completeCVData = finalCVData else {
                throw CVGenerationError.invalidResponse
            }

            // Calculate confidence based on response quality
            let confidence = calculateConfidence(cvData: completeCVData)

            let processingTime = Date().timeIntervalSince(startTime)

            return CVGenerationResult(
                cvData: completeCVData,
                confidence: confidence,
                suggestions: generateSuggestions(cvData: completeCVData),
                metadata: ResultMetadata(
                    generatedAt: Date(),
                    processingTime: processingTime,
                    modelVersion: "foundation-models-2.0"
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

    @available(iOS 26, macOS 26, *)
    nonisolated public func generateCVStream(from request: CVGenerationRequest) -> AsyncThrowingStream<CVData.PartiallyGenerated, Error> {
        #if canImport(FoundationModels)
        return AsyncThrowingStream { continuation in
            Task { @MainActor [weak self] in
                guard let self else {
                    continuation.finish(throwing: CVGenerationError.serviceUnavailable)
                    return
                }

                // Validate request - all within @MainActor context to avoid data races
                guard !request.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuation.finish(throwing: CVGenerationError.invalidPrompt)
                    return
                }

                guard await self.isAvailable() else {
                    continuation.finish(throwing: CVGenerationError.serviceUnavailable)
                    return
                }

                // Create language model session with system instructions
                let session = LanguageModelSession(
                    instructions: Instructions {
                        "You are an expert CV writer creating PRODUCTION-QUALITY professional CVs matching senior-level standards."

                        """
                        CRITICAL REQUIREMENTS:
                        - CONCISE, IMPACTFUL descriptions with quantifiable results
                        - STRONG ACTION VERBS (Led, Built, Implemented, Delivered)
                        - Extract company/university names EXACTLY as mentioned
                        - Professional summary: 3-4 sentences max
                        - Infer relevant technical skills from context
                        """

                        """
                        LANGUAGE INFERENCE:
                        - If prompt is in English, add English with C2 proficiency
                        - Mark native language as Native
                        """
                    }
                )

                do {
                    // Generate CV using guided generation
                    let stream = session.streamResponse(
                        generating: CVData.self,
                        includeSchemaInPrompt: false,
                        options: GenerationOptions(sampling: .greedy)
                    ) {
                        "PROFESSIONAL TONE: \(request.preferences.tone.rawValue) style"
                        "Experience Level: \(request.preferences.experienceLevel.rawValue)"

                        if let personalInfo = request.personalInfo {
                            "Personal Info: \(personalInfo.name), \(personalInfo.email)"
                        }

                        if let targetRole = request.preferences.targetRole {
                            "Target Role: \(targetRole)"
                        }

                        "Background Description:"
                        request.userPrompt
                    }

                    // Forward partial responses to the continuation
                    // PartiallyGenerated conforms to Sendable, safe to yield
                    for try await partialResponse in stream {
                        continuation.yield(partialResponse.content)
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: CVGenerationError.unknown("Failed to generate CV: \(error.localizedDescription)"))
                }
            }
        }
        #else
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: CVGenerationError.serviceUnavailable)
        }
        #endif
    }

    // MARK: - Private Helpers

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

    // MARK: - PartiallyGenerated Converters

    private func convertExperience(_ partial: Experience.PartiallyGenerated) -> Experience? {
        guard let title = partial.title,
              let company = partial.company,
              let startDate = partial.startDate else {
            return nil
        }
        return Experience(
            title: title,
            company: company,
            location: partial.location,
            startDate: startDate,
            endDate: partial.endDate,
            current: partial.current ?? false,
            description: partial.description ?? "",
            achievements: partial.achievements?.compactMap { $0 } ?? [],
            technologies: partial.technologies?.compactMap { $0 } ?? []
        )
    }

    private func convertEducation(_ partial: Education.PartiallyGenerated) -> Education? {
        guard let degree = partial.degree,
              let institution = partial.institution else {
            return nil
        }
        return Education(
            degree: degree,
            institution: institution,
            location: partial.location,
            startDate: partial.startDate ?? "",
            endDate: partial.endDate,
            gpa: partial.gpa,
            description: partial.description,
            achievements: partial.achievements?.compactMap { $0 } ?? []
        )
    }

    private func convertSkill(_ partial: Skill.PartiallyGenerated) -> Skill? {
        guard let name = partial.name,
              let level = partial.level else {
            return nil
        }
        return Skill(
            name: name,
            level: level,
            category: partial.category,
            yearsOfExperience: partial.yearsOfExperience
        )
    }

    private func convertLanguage(_ partial: Language.PartiallyGenerated) -> Language? {
        guard let name = partial.name,
              let proficiency = partial.proficiency else {
            return nil
        }
        return Language(
            name: name,
            proficiency: proficiency
        )
    }

    private func convertCertification(_ partial: Certification.PartiallyGenerated) -> Certification? {
        guard let name = partial.name,
              let issuer = partial.issuer,
              let date = partial.date else {
            return nil
        }
        return Certification(
            name: name,
            issuer: issuer,
            date: date,
            expiryDate: partial.expiryDate,
            credentialId: partial.credentialId,
            url: partial.url
        )
    }

    private func convertProject(_ partial: Project.PartiallyGenerated) -> Project? {
        guard let name = partial.name,
              let description = partial.description else {
            return nil
        }
        return Project(
            name: name,
            description: description,
            role: partial.role,
            startDate: partial.startDate,
            endDate: partial.endDate,
            technologies: partial.technologies?.compactMap { $0 } ?? [],
            url: partial.url,
            achievements: partial.achievements?.compactMap { $0 } ?? []
        )
    }
}
