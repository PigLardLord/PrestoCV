import Foundation

/// Protocol for CV validation
public protocol CVValidator: Sendable {
    /// Validate a generation request
    /// - Parameter request: Request to validate
    /// - Throws: CVGenerationError if validation fails
    func validateRequest(_ request: CVGenerationRequest) throws

    /// Validate generated CV data
    /// - Parameter cvData: CV data to validate
    /// - Throws: CVGenerationError if validation fails
    func validateCVData(_ cvData: CVData) throws
}

/// Default implementation of CV validator
public struct DefaultCVValidator: CVValidator {
    public init() {}

    public func validateRequest(_ request: CVGenerationRequest) throws {
        // Validate prompt is not empty
        let trimmedPrompt = request.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw CVGenerationError.invalidPrompt
        }

        // Validate prompt has minimum length
        guard trimmedPrompt.count >= 10 else {
            throw CVGenerationError.validationFailed("Please provide a more detailed description (at least 10 characters)")
        }

        // Validate personal info if provided
        if let personalInfo = request.personalInfo {
            try validatePersonalInfo(personalInfo)
        }
    }

    public func validateCVData(_ cvData: CVData) throws {
        // Validate personal info
        try validatePersonalInfo(cvData.personalInfo)

        // Validate that CV has at least some content
        let hasContent = !cvData.experience.isEmpty ||
                        !cvData.education.isEmpty ||
                        !cvData.skills.isEmpty

        guard hasContent else {
            throw CVGenerationError.validationFailed("Generated CV must contain at least one section (experience, education, or skills)")
        }

        // Validate individual sections
        for experience in cvData.experience {
            try validateExperience(experience)
        }

        for education in cvData.education {
            try validateEducation(education)
        }
    }

    // MARK: - Private Validation Helpers

    private func validatePersonalInfo(_ personalInfo: PersonalInfo) throws {
        guard !personalInfo.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CVGenerationError.validationFailed("Name cannot be empty")
        }

        guard !personalInfo.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CVGenerationError.validationFailed("Email cannot be empty")
        }

        // Basic email validation
        guard personalInfo.email.contains("@") && personalInfo.email.contains(".") else {
            throw CVGenerationError.validationFailed("Invalid email format")
        }
    }

    private func validateExperience(_ experience: Experience) throws {
        guard !experience.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CVGenerationError.validationFailed("Experience title cannot be empty")
        }

        guard !experience.company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CVGenerationError.validationFailed("Company name cannot be empty")
        }

        guard !experience.startDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CVGenerationError.validationFailed("Experience start date cannot be empty")
        }
    }

    private func validateEducation(_ education: Education) throws {
        guard !education.degree.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CVGenerationError.validationFailed("Degree cannot be empty")
        }

        guard !education.institution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CVGenerationError.validationFailed("Institution name cannot be empty")
        }
    }
}
