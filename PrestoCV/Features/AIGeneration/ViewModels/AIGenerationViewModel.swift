import SwiftUI
import PrestoCVCore
import CVGeneratorAI

@MainActor
final class AIGenerationViewModel: ObservableObject {
    @Published var prompt: String = ""
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String = ""
    @Published var generatedCVId: String?

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
            try await cvManagementUseCase.createCV(from: cvModel)

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

    private func mapToCVModel(_ cvData: CVData) -> CVModel {
        CVModel(
            id: cvData.id,
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
                    id: exp.id,
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
                    id: edu.id,
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
                    id: cert.id,
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
