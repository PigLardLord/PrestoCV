import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Validator Tests (TDD)

@Suite("Template Validator")
struct TemplateValidatorTests {

    // MARK: - Required Fields Definition

    @Test("Validator identifies all required CV fields")
    func validatorHasAllRequiredFields() {
        // Given
        let validator = TemplateValidator()

        // When
        let requiredFields = validator.requiredFields

        // Then - Should check for all 8 major CV sections
        #expect(requiredFields.contains(.personalInfo))
        #expect(requiredFields.contains(.workExperience))
        #expect(requiredFields.contains(.education))
        #expect(requiredFields.contains(.skills))
        #expect(requiredFields.contains(.languages))
        #expect(requiredFields.contains(.certifications))
        #expect(requiredFields.contains(.socialLinks))
        #expect(requiredFields.contains(.interests))
    }

    // MARK: - Personal Info Field Validation

    @Test("Validates personal info fields are present in template")
    func validatesPersonalInfoFields() {
        // Given
        let validator = TemplateValidator()
        let templateWithAllFields = """
        <html>
        <body>
            <h1>{{name}}</h1>
            <div>{{email}}</div>
            {{#hasPhone}}<div>{{phone}}</div>{{/hasPhone}}
            {{#hasLocation}}<div>{{location}}</div>{{/hasLocation}}
            {{#hasWebsite}}<div>{{website}}</div>{{/hasWebsite}}
            {{#hasTitle}}<div>{{title}}</div>{{/hasTitle}}
            {{#hasSummary}}<div>{{summary}}</div>{{/hasSummary}}
            {{#hasWorkExperience}}<div>Work</div>{{/hasWorkExperience}}
            {{#hasEducation}}<div>Education</div>{{/hasEducation}}
            {{#hasSkills}}<div>Skills</div>{{/hasSkills}}
            {{#hasLanguages}}<div>Languages</div>{{/hasLanguages}}
            {{#hasCertifications}}<div>Certifications</div>{{/hasCertifications}}
            {{#hasSocialLinks}}<div>Social</div>{{/hasSocialLinks}}
            {{#hasInterests}}<div>Interests</div>{{/hasInterests}}
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: templateWithAllFields)

        // Then
        #expect(result.isValid)
        #expect(result.missingFields.isEmpty)
    }

    @Test("Detects missing name field")
    func detectsMissingNameField() {
        // Given
        let validator = TemplateValidator()
        let templateWithoutName = """
        <html>
        <body>
            <div>{{email}}</div>
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: templateWithoutName)

        // Then
        #expect(!result.isValid)
        #expect(result.missingFields.contains(.name))
    }

    @Test("Detects missing email field")
    func detectsMissingEmailField() {
        // Given
        let validator = TemplateValidator()
        let templateWithoutEmail = """
        <html>
        <body>
            <h1>{{name}}</h1>
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: templateWithoutEmail)

        // Then
        #expect(!result.isValid)
        #expect(result.missingFields.contains(.email))
    }

    // MARK: - Section Validation

    @Test("Validates work experience section is present")
    func validatesWorkExperienceSection() {
        // Given
        let validator = TemplateValidator()
        let templateWithWorkExperience = """
        <html>
        <body>
            <h1>{{name}}</h1>
            <div>{{email}}</div>
            {{#hasWorkExperience}}
            <section>
                {{#workExperience}}
                <div>{{title}} at {{company}}</div>
                <div>{{startDate}} - {{endDate}}</div>
                {{/workExperience}}
            </section>
            {{/hasWorkExperience}}
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: templateWithWorkExperience)

        // Then
        #expect(!result.missingFields.contains(.workExperience))
    }

    @Test("Detects missing education section")
    func detectsMissingEducationSection() {
        // Given
        let validator = TemplateValidator()
        let templateWithoutEducation = """
        <html>
        <body>
            <h1>{{name}}</h1>
            <div>{{email}}</div>
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: templateWithoutEducation)

        // Then
        #expect(!result.isValid)
        #expect(result.missingFields.contains(.education))
    }

    @Test("Detects missing skills section")
    func detectsMissingSkillsSection() {
        // Given
        let validator = TemplateValidator()
        let templateWithoutSkills = """
        <html>
        <body>
            <h1>{{name}}</h1>
            <div>{{email}}</div>
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: templateWithoutSkills)

        // Then
        #expect(!result.isValid)
        #expect(result.missingFields.contains(.skills))
    }

    @Test("Detects missing languages section")
    func detectsMissingLanguagesSection() {
        // Given
        let validator = TemplateValidator()
        let templateWithoutLanguages = """
        <html>
        <body>
            <h1>{{name}}</h1>
            <div>{{email}}</div>
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: templateWithoutLanguages)

        // Then
        #expect(!result.isValid)
        #expect(result.missingFields.contains(.languages))
    }

    @Test("Detects missing certifications section")
    func detectsMissingCertificationsSection() {
        // Given
        let validator = TemplateValidator()
        let templateWithoutCertifications = """
        <html>
        <body>
            <h1>{{name}}</h1>
            <div>{{email}}</div>
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: templateWithoutCertifications)

        // Then
        #expect(!result.isValid)
        #expect(result.missingFields.contains(.certifications))
    }

    @Test("Detects missing social links section")
    func detectsMissingSocialLinksSection() {
        // Given
        let validator = TemplateValidator()
        let templateWithoutSocialLinks = """
        <html>
        <body>
            <h1>{{name}}</h1>
            <div>{{email}}</div>
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: templateWithoutSocialLinks)

        // Then
        #expect(!result.isValid)
        #expect(result.missingFields.contains(.socialLinks))
    }

    @Test("Detects missing interests section")
    func detectsMissingInterestsSection() {
        // Given
        let validator = TemplateValidator()
        let templateWithoutInterests = """
        <html>
        <body>
            <h1>{{name}}</h1>
            <div>{{email}}</div>
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: templateWithoutInterests)

        // Then
        #expect(!result.isValid)
        #expect(result.missingFields.contains(.interests))
    }

    // MARK: - Embedded Templates Validation

    @Test("Modern template contains all required fields")
    func modernTemplateContainsAllFields() {
        // Given
        let validator = TemplateValidator()
        let template = ModernHTMLTemplate.html

        // When
        let result = validator.validate(template: template)

        // Then
        #expect(result.isValid, "Modern template should contain all required fields. Missing: \(result.missingFields)")
        #expect(result.missingFields.isEmpty, "Missing fields: \(result.missingFields.map { $0.rawValue }.joined(separator: ", "))")
    }

    @Test("Professional template contains all required fields")
    func professionalTemplateContainsAllFields() {
        // Given
        let validator = TemplateValidator()
        let template = ProfessionalHTMLTemplate.html

        // When
        let result = validator.validate(template: template)

        // Then
        #expect(result.isValid, "Professional template should contain all required fields. Missing: \(result.missingFields)")
        #expect(result.missingFields.isEmpty, "Missing fields: \(result.missingFields.map { $0.rawValue }.joined(separator: ", "))")
    }

    @Test("Minimal template contains all required fields")
    func minimalTemplateContainsAllFields() {
        // Given
        let validator = TemplateValidator()
        let template = MinimalHTMLTemplate.html

        // When
        let result = validator.validate(template: template)

        // Then
        #expect(result.isValid, "Minimal template should contain all required fields. Missing: \(result.missingFields)")
        #expect(result.missingFields.isEmpty, "Missing fields: \(result.missingFields.map { $0.rawValue }.joined(separator: ", "))")
    }

    // MARK: - Validation Result Details

    @Test("Validation result provides detailed missing fields report")
    func validationResultProvidesDetailedReport() {
        // Given
        let validator = TemplateValidator()
        let incompleteTemplate = """
        <html>
        <body>
            <h1>{{name}}</h1>
        </body>
        </html>
        """

        // When
        let result = validator.validate(template: incompleteTemplate)

        // Then
        #expect(!result.isValid)
        #expect(result.missingFields.count > 0)
        #expect(!result.description.isEmpty)
        #expect(result.description.contains("missing") || result.description.contains("Missing"))
    }

    // MARK: - Package Validation

    @Test("Validates template package with valid content")
    func validatesValidTemplatePackage() throws {
        // Given
        let validator = TemplateValidator()
        let manifest = TemplateManifest(
            id: "test-template",
            name: "Test Template",
            description: "Test",
            author: "Test Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let validHTML = """
        <html><body>
        {{name}} {{email}}
        {{#hasWorkExperience}}Work{{/hasWorkExperience}}
        {{#hasEducation}}Edu{{/hasEducation}}
        {{#hasSkills}}Skills{{/hasSkills}}
        {{#hasLanguages}}Lang{{/hasLanguages}}
        {{#hasCertifications}}Cert{{/hasCertifications}}
        {{#hasSocialLinks}}Social{{/hasSocialLinks}}
        {{#hasInterests}}Int{{/hasInterests}}
        </body></html>
        """

        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body {}",
            htmlContent: validHTML
        )

        // When
        let result = try validator.validatePackage(package)

        // Then
        #expect(result.isValid)
        #expect(result.missingFields.isEmpty)
    }

    @Test("Validates CSS-only package using base template")
    func validatesCSSOnlyPackage() throws {
        // Given
        let validator = TemplateValidator()
        let manifest = TemplateManifest(
            id: "css-only",
            name: "CSS Only Template",
            description: "Test",
            author: "Test Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body { color: blue; }",
            htmlContent: nil // Uses base template
        )

        // When - Should use base template for validation
        let result = try validator.validatePackage(package)

        // Then - Base template has all required fields
        #expect(result.isValid)
        #expect(result.missingFields.isEmpty)
    }

    @Test("Detects missing fields in custom HTML package")
    func detectsMissingFieldsInCustomHTMLPackage() throws {
        // Given
        let validator = TemplateValidator()
        let manifest = TemplateManifest(
            id: "incomplete",
            name: "Incomplete Template",
            description: "Test",
            author: "Test Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )

        let incompleteHTML = """
        <html><body>
        {{name}} {{email}}
        </body></html>
        """

        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body {}",
            htmlContent: incompleteHTML
        )

        // When
        let result = try validator.validatePackage(package)

        // Then
        #expect(!result.isValid)
        #expect(result.missingFields.contains(.workExperience))
        #expect(result.missingFields.contains(.education))
        #expect(result.missingFields.contains(.skills))
    }
}
