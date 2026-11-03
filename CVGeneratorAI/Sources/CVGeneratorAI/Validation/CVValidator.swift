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
        let length = request.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).count

        guard length >= CVGenerationLimits.minimumDescriptionLength else {
            throw CVGenerationError.descriptionTooShort
        }
        guard length <= CVGenerationLimits.maximumDescriptionLength else {
            throw CVGenerationError.descriptionTooLong
        }
    }

    /// A CV is valid when it holds something; a missing name or email is fine, a malformed email is not.
    public func validateCVData(_ cvData: CVData) throws {
        guard hasContent(cvData) else {
            throw CVGenerationError.emptyResult
        }

        if let email = cvData.personalInfo.email.trimmedNonEmpty, !isPlausibleEmail(email) {
            throw CVGenerationError.generationFailed
        }
    }

    // MARK: - Private Validation Helpers

    /// The draft is judged on its facts: the summary is written by the model (ADR 0031), so a draft with nothing but a summary is
    /// no CV of the person.
    private func hasContent(_ cvData: CVData) -> Bool {
        let info = cvData.personalInfo
        let personalFields = [
            info.name, info.email, info.phone, info.location,
            info.website, info.linkedin, info.github, info.title,
        ]

        return personalFields.contains { $0.trimmedNonEmpty != nil }
            || !cvData.experience.isEmpty
            || !cvData.education.isEmpty
            || !cvData.skills.isEmpty
            || !cvData.languages.isEmpty
            || !cvData.certifications.isEmpty
            || !cvData.interests.isEmpty
    }

    private func isPlausibleEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".")
    }
}
