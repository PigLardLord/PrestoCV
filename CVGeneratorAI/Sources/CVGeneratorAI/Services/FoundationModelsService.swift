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
        return availability() == .available
    }

    /// Whether the on-device model can run now and, when it cannot, why
    @available(iOS 26, macOS 26, *)
    public func availability() -> AIAvailability {
        #if canImport(FoundationModels)
        return Self.map(SystemLanguageModel.default.availability)
        #else
        return .unavailable(.deviceNotEligible)
        #endif
    }

    #if canImport(FoundationModels)
    /// Translates the framework's availability, keeping any reason a later OS adds as `.unknown`
    nonisolated static func map(_ availability: SystemLanguageModel.Availability) -> AIAvailability {
        switch availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                return .unavailable(.appleIntelligenceNotEnabled)
            case .modelNotReady:
                return .unavailable(.modelNotReady)
            @unknown default:
                return .unavailable(.unknown)
            }
        @unknown default:
            return .unavailable(.unknown)
        }
    }
    #endif

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

        // Create language model session (on-device, 4K token limit)
        let session = LanguageModelSession()

        do {
            // Improved prompt - ensures quality while staying within 4K token limit
            var promptParts: [String] = [
                "Expert CV writer. Generate complete professional CV with:",
                "",
                "MANDATORY sections:",
                "- Summary: 3-4 sentence professional overview (REQUIRED)",
                "- Experience: chronological order, newest first",
                "- Education, Skills, Languages",
                "- Interests: extract hobbies/passions from description",
                "",
                "CRITICAL: Each entry must be UNIQUE. NO duplicate experiences or education.",
                "",
                "Date field format (NOT full range):",
                "- startDate: \"2018\" or \"August 2018\" or \"Aug 2018\"",
                "- endDate: \"2022\" or \"March 2022\" (null if current)",
                "- current: true for ongoing roles, false otherwise",
                "",
                "Style: Concise with metrics, action verbs (Led, Built, Delivered)",
                "Extract company/university names EXACTLY as stated",
                "",
                "Tone: \(request.preferences.tone.rawValue) | Level: \(request.preferences.experienceLevel.rawValue)"
            ]

            if let personalInfo = request.personalInfo {
                promptParts.append("Personal Info: \(personalInfo.name), \(personalInfo.email)")
            }

            if let targetRole = request.preferences.targetRole {
                promptParts.append("Target Role: \(targetRole)")
            }

            promptParts.append("")
            promptParts.append("Background Description:")
            promptParts.append(request.userPrompt)

            let fullPrompt = promptParts.joined(separator: "\n")

            // Generate CV using guided generation
            let stream = session.streamResponse(
                generating: CVData.self,
                includeSchemaInPrompt: false,
                options: GenerationOptions(sampling: .greedy)
            ) {
                fullPrompt
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

                    let experienceWithDuplicates = partialResponse.content.experience?.compactMap { expPartial in
                        convertExperience(expPartial)
                    } ?? []

                    // Deduplicate experience entries (AI sometimes generates duplicates)
                    var seenExperience = Set<String>()
                    let experience = experienceWithDuplicates.filter { exp in
                        let key = "\(exp.title)|\(exp.company)"
                        if seenExperience.contains(key) {
                            #if DEBUG
                            print("⚠️ Skipping duplicate experience: \(exp.title) at \(exp.company)")
                            #endif
                            return false
                        }
                        seenExperience.insert(key)
                        return true
                    }

                    let educationWithDuplicates = partialResponse.content.education?.compactMap { eduPartial in
                        convertEducation(eduPartial)
                    } ?? []

                    // Deduplicate education entries (AI sometimes generates duplicates)
                    var seenEducation = Set<String>()
                    let education = educationWithDuplicates.filter { edu in
                        let key = "\(edu.degree)|\(edu.institution)"
                        if seenEducation.contains(key) {
                            #if DEBUG
                            print("⚠️ Skipping duplicate education: \(edu.degree) at \(edu.institution)")
                            #endif
                            return false
                        }
                        seenEducation.insert(key)
                        return true
                    }

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

        } catch let error as LanguageModelSession.GenerationError {
            // Handle FoundationModels specific errors
            switch error {
            case .exceededContextWindowSize(let context):
                #if DEBUG
                print("⚠️ Context window exceeded: \(context.debugDescription)")
                #endif
                throw CVGenerationError.descriptionTooLong
            default:
                #if DEBUG
                print("🔍 DEBUG: Generation error: \(error)")
                #endif
                throw CVGenerationError.unknown("Failed to generate CV: \(error.localizedDescription)")
            }
        } catch {
            // Handle other errors
            #if DEBUG
            print("🔍 DEBUG: Unexpected error: \(error)")
            #endif
            throw CVGenerationError.unknown("Failed to generate CV: \(error.localizedDescription)")
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

                // Create language model session (on-device, 4K token limit)
                let session = LanguageModelSession()

                do {
                    // Improved prompt - ensures quality while staying within 4K token limit
                    var promptParts: [String] = [
                        "Expert CV writer. Generate complete professional CV with:",
                        "",
                        "MANDATORY sections:",
                        "- Summary: 3-4 sentence professional overview (REQUIRED)",
                        "- Experience: chronological order, newest first",
                        "- Education, Skills, Languages",
                        "- Interests: extract hobbies/passions from description",
                        "",
                        "CRITICAL: Each entry must be UNIQUE. NO duplicate experiences or education.",
                        "",
                        "Date field format (NOT full range):",
                        "- startDate: \"2018\" or \"August 2018\" or \"Aug 2018\"",
                        "- endDate: \"2022\" or \"March 2022\" (null if current)",
                        "- current: true for ongoing roles, false otherwise",
                        "",
                        "Style: Concise with metrics, action verbs (Led, Built, Delivered)",
                        "Extract company/university names EXACTLY as stated",
                        "",
                        "Tone: \(request.preferences.tone.rawValue) | Level: \(request.preferences.experienceLevel.rawValue)"
                    ]

                    if let personalInfo = request.personalInfo {
                        promptParts.append("Personal Info: \(personalInfo.name), \(personalInfo.email)")
                    }

                    if let targetRole = request.preferences.targetRole {
                        promptParts.append("Target Role: \(targetRole)")
                    }

                    promptParts.append("")
                    promptParts.append("Background Description:")
                    promptParts.append(request.userPrompt)

                    let fullPrompt = promptParts.joined(separator: "\n")

                    // Generate CV using guided generation
                    let stream = session.streamResponse(
                        generating: CVData.self,
                        includeSchemaInPrompt: false,
                        options: GenerationOptions(sampling: .greedy)
                    ) {
                        fullPrompt
                    }

                    // Forward partial responses to the continuation
                    // PartiallyGenerated conforms to Sendable, safe to yield
                    for try await partialResponse in stream {
                        continuation.yield(partialResponse.content)
                    }

                    continuation.finish()

                } catch let error as LanguageModelSession.GenerationError {
                    // Handle FoundationModels specific errors
                    switch error {
                    case .exceededContextWindowSize(let context):
                        #if DEBUG
                        print("⚠️ Context window exceeded: \(context.debugDescription)")
                        #endif
                        continuation.finish(throwing: CVGenerationError.descriptionTooLong)
                    default:
                        continuation.finish(throwing: CVGenerationError.unknown("Failed to generate CV: \(error.localizedDescription)"))
                    }
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
