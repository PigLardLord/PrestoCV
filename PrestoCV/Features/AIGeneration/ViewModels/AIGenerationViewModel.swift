import SwiftUI
import PrestoCVCore
import CVGeneratorAI

@MainActor
final class AIGenerationViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String = ""
    @Published var generatedCVId: String?

    #if canImport(FoundationModels)
    @Published var partialCVData: CVGeneratorAI.CVData.PartiallyGenerated?
    #endif

    private let cvGenerationUseCase: CVGeneratorUseCase
    private let cvManagementUseCase: CVManagementUseCaseProtocol

    init(
        cvGenerationUseCase: CVGeneratorUseCase,
        cvManagementUseCase: CVManagementUseCaseProtocol
    ) {
        self.cvGenerationUseCase = cvGenerationUseCase
        self.cvManagementUseCase = cvManagementUseCase
    }

    func generateCV() async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please provide a description of your professional background"
            return
        }

        isGenerating = true
        errorMessage = ""

        do {
            let request = CVGenerationRequest(
                userPrompt: prompt,
                personalInfo: nil,
                preferences: GenerationPreferences()
            )

            let result = try await cvGenerationUseCase.generateCV(from: request)

            let cvModel = mapToCVModel(result.cvData)
            _ = try await cvManagementUseCase.createCV(from: cvModel)

            generatedCVId = cvModel.id.uuidString

        } catch let error as CVGenerationError {
            errorMessage = error.errorDescription ?? "Failed to generate CV"
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    func clearError() {
        errorMessage = ""
    }

    #if canImport(FoundationModels)
    @available(iOS 26, macOS 26, *)
    func generateCVWithStreaming() async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please provide a description of your professional background"
            return
        }

        isGenerating = true
        errorMessage = ""
        partialCVData = nil

        do {
            let request = CVGenerationRequest(
                userPrompt: prompt,
                personalInfo: nil,
                preferences: GenerationPreferences()
            )

            let stream = try cvGenerationUseCase.generateCVStream(from: request)

            // Consume stream and update UI in real-time
            for try await partial in stream {
                partialCVData = partial
            }

            // Once stream completes, convert final partial to complete CVData
            if let finalPartial = partialCVData,
               let completeCVData = try? convertPartialToCVData(finalPartial) {

                let cvModel = mapToCVModel(completeCVData)
                _ = try await cvManagementUseCase.createCV(from: cvModel)

                generatedCVId = cvModel.id.uuidString
            } else {
                throw CVGenerationError.invalidResponse
            }

        } catch let error as CVGenerationError {
            errorMessage = error.errorDescription ?? "Failed to generate CV"
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }

        isGenerating = false
        partialCVData = nil
    }

    @available(iOS 26, macOS 26, *)
    private func convertPartialToCVData(_ partial: CVGeneratorAI.CVData.PartiallyGenerated) throws -> CVData {
        guard let personalInfo = partial.personalInfo,
              let name = personalInfo.name,
              let email = personalInfo.email else {
            throw CVGenerationError.invalidResponse
        }

        return CVData(
            personalInfo: PersonalInfo(
                name: name,
                email: email,
                phone: personalInfo.phone,
                location: personalInfo.location,
                website: personalInfo.website,
                linkedin: personalInfo.linkedin,
                github: personalInfo.github,
                title: personalInfo.title
            ),
            summary: partial.summary,
            experience: convertExperienceArray(partial.experience),
            education: convertEducationArray(partial.education),
            skills: convertSkillArray(partial.skills),
            languages: convertLanguageArray(partial.languages),
            certifications: convertCertificationArray(partial.certifications),
            projects: convertProjectArray(partial.projects),
            interests: partial.interests?.compactMap { $0 } ?? []
        )
    }

    private func convertExperienceArray(_ partial: [CVGeneratorAI.Experience.PartiallyGenerated]?) -> [CVGeneratorAI.Experience] {
        partial?.compactMap { exp in
            guard let title = exp.title, let company = exp.company, let startDate = exp.startDate else { return nil }
            return CVGeneratorAI.Experience(
                title: title,
                company: company,
                location: exp.location,
                startDate: startDate,
                endDate: exp.endDate,
                current: exp.current ?? false,
                description: exp.description ?? "",
                achievements: exp.achievements?.compactMap { $0 } ?? [],
                technologies: exp.technologies?.compactMap { $0 } ?? []
            )
        } ?? []
    }

    private func convertEducationArray(_ partial: [CVGeneratorAI.Education.PartiallyGenerated]?) -> [CVGeneratorAI.Education] {
        partial?.compactMap { edu in
            guard let degree = edu.degree, let institution = edu.institution else { return nil }
            return CVGeneratorAI.Education(
                degree: degree,
                institution: institution,
                location: edu.location,
                startDate: edu.startDate ?? "",
                endDate: edu.endDate,
                gpa: edu.gpa,
                description: edu.description,
                achievements: edu.achievements?.compactMap { $0 } ?? []
            )
        } ?? []
    }

    private func convertSkillArray(_ partial: [CVGeneratorAI.Skill.PartiallyGenerated]?) -> [CVGeneratorAI.Skill] {
        partial?.compactMap { skill in
            guard let name = skill.name, let level = skill.level else { return nil }
            return CVGeneratorAI.Skill(
                name: name,
                level: level,
                category: skill.category,
                yearsOfExperience: skill.yearsOfExperience
            )
        } ?? []
    }

    private func convertLanguageArray(_ partial: [CVGeneratorAI.Language.PartiallyGenerated]?) -> [CVGeneratorAI.Language] {
        partial?.compactMap { lang in
            guard let name = lang.name, let proficiency = lang.proficiency else { return nil }
            return CVGeneratorAI.Language(name: name, proficiency: proficiency)
        } ?? []
    }

    private func convertCertificationArray(_ partial: [CVGeneratorAI.Certification.PartiallyGenerated]?) -> [CVGeneratorAI.Certification] {
        partial?.compactMap { cert in
            guard let name = cert.name, let issuer = cert.issuer, let date = cert.date else { return nil }
            return CVGeneratorAI.Certification(
                name: name,
                issuer: issuer,
                date: date,
                expiryDate: cert.expiryDate,
                credentialId: cert.credentialId,
                url: cert.url
            )
        } ?? []
    }

    private func convertProjectArray(_ partial: [CVGeneratorAI.Project.PartiallyGenerated]?) -> [CVGeneratorAI.Project] {
        partial?.compactMap { proj in
            guard let name = proj.name, let description = proj.description else { return nil }
            return CVGeneratorAI.Project(
                name: name,
                description: description,
                role: proj.role,
                startDate: proj.startDate,
                endDate: proj.endDate,
                technologies: proj.technologies?.compactMap { $0 } ?? [],
                url: proj.url,
                achievements: proj.achievements?.compactMap { $0 } ?? []
            )
        } ?? []
    }
    #endif

    private func mapToCVModel(_ cvData: CVData) -> CVModel {
        CVModel(
            id: UUID(), // Generate new UUID for the CV
            name: "\(cvData.personalInfo.name)'s CV",
            personalInfo: PrestoCVCore.PersonalInfo(
                name: cvData.personalInfo.name,
                title: cvData.personalInfo.title ?? "",
                location: cvData.personalInfo.location ?? "",
                email: cvData.personalInfo.email,
                phone: cvData.personalInfo.phone ?? "",
                portfolio: cvData.personalInfo.website ?? "",
                profile: cvData.summary ?? ""
            ),
            relevant_experience: cvData.experience.map { exp in
                Experience(
                    id: UUID(), // Generate new UUID for each experience
                    title: exp.title,
                    company: exp.company,
                    location: exp.location ?? "",
                    period: formatPeriod(startDate: exp.startDate, endDate: exp.endDate, isCurrent: exp.current),
                    description: formatExperienceDescription(
                        description: exp.description,
                        achievements: exp.achievements,
                        technologies: exp.technologies
                    )
                )
            },
            education: cvData.education.map { edu in
                Education(
                    id: UUID(), // Generate new UUID for each education
                    degree: edu.degree,
                    school: edu.institution,
                    period: formatEducationPeriod(startDate: edu.startDate, endDate: edu.endDate),
                    description: formatEducationDescription(
                        description: edu.description,
                        gpa: edu.gpa,
                        achievements: edu.achievements
                    )
                )
            },
            skills: cvData.skills.map { skill in
                Skill(
                    name: skill.name,
                    level: mapSkillLevel(skill.level)
                )
            },
            languages: cvData.languages.map { lang in
                Language(
                    name: lang.name,
                    level: mapLanguageProficiency(lang.proficiency)
                )
            },
            certifications: cvData.certifications.map { cert in
                Certification(
                    id: UUID(), // Generate new UUID for each certification
                    name: cert.name,
                    issuer: cert.issuer,
                    year: extractYear(from: cert.date),
                    url: cert.url ?? "",
                    description: cert.credentialId ?? ""
                )
            },
            interests: cvData.interests,
            social: [] // No social links from AI generation yet
        )
    }

    // MARK: - Helper Methods

    private func formatPeriod(startDate: String, endDate: String?, isCurrent: Bool) -> String {
        if isCurrent {
            return "\(startDate) – Present"
        } else if let endDate = endDate {
            return "\(startDate) – \(endDate)"
        } else {
            return startDate
        }
    }

    private func formatEducationPeriod(startDate: String?, endDate: String?) -> String {
        if let start = startDate, let end = endDate {
            return "\(start) – \(end)"
        } else if let start = startDate {
            return start
        } else if let end = endDate {
            return end
        } else {
            return ""
        }
    }

    private func formatExperienceDescription(description: String, achievements: [String], technologies: [String]) -> String {
        var parts: [String] = []

        if !description.isEmpty {
            parts.append(description)
        }

        if !achievements.isEmpty {
            parts.append("\n\nKey Achievements:")
            parts.append(achievements.map { "• \($0)" }.joined(separator: "\n"))
        }

        if !technologies.isEmpty {
            parts.append("\n\nTechnologies: \(technologies.joined(separator: ", "))")
        }

        return parts.joined(separator: "\n")
    }

    private func formatEducationDescription(description: String?, gpa: String?, achievements: [String]) -> String {
        var parts: [String] = []

        if let desc = description, !desc.isEmpty {
            parts.append(desc)
        }

        if let gpa = gpa, !gpa.isEmpty {
            parts.append("GPA: \(gpa)")
        }

        if !achievements.isEmpty {
            parts.append("\n" + achievements.map { "• \($0)" }.joined(separator: "\n"))
        }

        return parts.joined(separator: "\n")
    }

    private func extractYear(from dateString: String) -> Int {
        // Try to extract year from various date formats
        let components = dateString.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for component in components {
            if let year = Int(component), year >= 1900, year <= 2100 {
                return year
            }
        }
        return 0
    }

    private func mapSkillLevel(_ level: CVGeneratorAI.SkillLevel) -> Int {
        switch level {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert: return 4
        }
    }

    private func mapLanguageProficiency(_ proficiency: CVGeneratorAI.LanguageProficiency) -> LanguageProficiencyLevel {
        switch proficiency {
        case .native: return .native
        case .c2: return .c2
        case .c1: return .c1
        case .b2: return .b2
        case .b1: return .b1
        case .a2: return .a2
        case .a1: return .a1
        }
    }
}
