import Foundation

/// Represents a CV field that should be present in templates
public enum CVField: String, CaseIterable {
    // Personal Info Fields
    case name = "{{name}}"
    case email = "{{email}}"
    case phone = "{{#hasPhone}}"
    case location = "{{#hasLocation}}"
    case website = "{{#hasWebsite}}"
    case title = "{{#hasTitle}}"
    case summary = "{{#hasSummary}}"

    // Section Fields
    case workExperience = "{{#hasWorkExperience}}"
    case education = "{{#hasEducation}}"
    case skills = "{{#hasSkills}}"
    case languages = "{{#hasLanguages}}"
    case certifications = "{{#hasCertifications}}"
    case socialLinks = "{{#hasSocialLinks}}"
    case interests = "{{#hasInterests}}"

    // Grouped fields for validation
    case personalInfo // Meta field representing all personal info
}

/// Result of template validation
public struct ValidationResult {
    public let isValid: Bool
    public let missingFields: [CVField]
    public let description: String

    public init(isValid: Bool, missingFields: [CVField]) {
        self.isValid = isValid
        self.missingFields = missingFields

        if missingFields.isEmpty {
            self.description = "Template is valid - all required fields are present"
        } else {
            let fieldNames = missingFields.map { $0.rawValue }.joined(separator: ", ")
            self.description = "Template is missing required fields: \(fieldNames)"
        }
    }
}

/// Validates that CV templates contain all required fields
public struct TemplateValidator {

    /// All fields that must be present in a valid template
    public let requiredFields: [CVField] = [
        .personalInfo,
        .workExperience,
        .education,
        .skills,
        .languages,
        .certifications,
        .socialLinks,
        .interests
    ]

    /// Personal info subfields that compose the personalInfo meta field
    private let personalInfoFields: [CVField] = [
        .name,
        .email
        // Phone, location, website, title, and summary are optional with conditionals
    ]

    public init() {}

    /// Validates that a template contains all required CV fields
    /// - Parameter template: The HTML template string to validate
    /// - Returns: ValidationResult indicating whether the template is valid and which fields are missing
    public func validate(template: String) -> ValidationResult {
        var missing: [CVField] = []

        // Check each required field
        for field in requiredFields {
            if field == .personalInfo {
                // Check personal info subfields
                for subfield in personalInfoFields {
                    if !template.contains(subfield.rawValue) {
                        missing.append(subfield)
                    }
                }
            } else {
                // Check section fields
                if !template.contains(field.rawValue) {
                    missing.append(field)
                }
            }
        }

        let isValid = missing.isEmpty
        return ValidationResult(isValid: isValid, missingFields: missing)
    }
}
