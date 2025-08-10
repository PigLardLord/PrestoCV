import Foundation
@testable import PrestoCVCore

/// A builder for creating test CVModel instances with default values and fluent configuration
public struct CVTestDataBuilder {
    private var name: String = "Test CV"
    private var title: String = ""
    private var location: String = ""
    private var email: String = ""
    private var phone: String = ""
    private var portfolio: String = ""
    private var profile: String = ""
    private var relevant_experience: [Experience] = []
    private var education: [Education] = []
    private var skills: [Skill] = []
    private var languages: [Language] = []
    private var certifications: [Certification] = []
    private var interests: [String] = []
    private var social: [Social] = []
    
    public init() {}
    
    public func withName(_ name: String) -> CVTestDataBuilder {
        var builder = self
        builder.name = name
        return builder
    }
    
    public func withTitle(_ title: String) -> CVTestDataBuilder {
        var builder = self
        builder.title = title
        return builder
    }
    
    public func withLocation(_ location: String) -> CVTestDataBuilder {
        var builder = self
        builder.location = location
        return builder
    }
    
    public func withEmail(_ email: String) -> CVTestDataBuilder {
        var builder = self
        builder.email = email
        return builder
    }
    
    public func withPhone(_ phone: String) -> CVTestDataBuilder {
        var builder = self
        builder.phone = phone
        return builder
    }
    
    public func withPortfolio(_ portfolio: String) -> CVTestDataBuilder {
        var builder = self
        builder.portfolio = portfolio
        return builder
    }
    
    public func withProfile(_ profile: String) -> CVTestDataBuilder {
        var builder = self
        builder.profile = profile
        return builder
    }
    
    public func withSkills(_ skills: [Skill]) -> CVTestDataBuilder {
        var builder = self
        builder.skills = skills
        return builder
    }
    
    public func withExperience(_ experience: [Experience]) -> CVTestDataBuilder {
        var builder = self
        builder.relevant_experience = experience
        return builder
    }
    
    public func withEducation(_ education: [Education]) -> CVTestDataBuilder {
        var builder = self
        builder.education = education
        return builder
    }
    
    public func withLanguages(_ languages: [Language]) -> CVTestDataBuilder {
        var builder = self
        builder.languages = languages
        return builder
    }
    
    public func withCertifications(_ certifications: [Certification]) -> CVTestDataBuilder {
        var builder = self
        builder.certifications = certifications
        return builder
    }
    
    public func withInterests(_ interests: [String]) -> CVTestDataBuilder {
        var builder = self
        builder.interests = interests
        return builder
    }
    
    public func withSocial(_ social: [Social]) -> CVTestDataBuilder {
        var builder = self
        builder.social = social
        return builder
    }
    
    // MARK: - Predefined builders for common test scenarios
    
    public static func minimalCV() -> CVTestDataBuilder {
        return CVTestDataBuilder()
            .withName("John Doe")
            .withEmail("john@example.com")
    }
    
    public static func completeCV() -> CVTestDataBuilder {
        return CVTestDataBuilder()
            .withName("Jane Smith")
            .withTitle("Senior iOS Developer")
            .withLocation("San Francisco, CA")
            .withEmail("jane.smith@example.com")
            .withPhone("+1-555-123-4567")
            .withPortfolio("https://janesmith.dev")
            .withProfile("Experienced iOS developer with 5+ years of experience")
            .withSkills([
                Skill(name: "Swift", level: 5),
                Skill(name: "SwiftUI", level: 4),
                Skill(name: "UIKit", level: 5)
            ])
            .withExperience([
                Experience(
                    title: "Senior iOS Developer",
                    company: "Tech Corp",
                    location: "San Francisco, CA",
                    period: "2020-Present",
                    description: "Lead iOS development team"
                )
            ])
            .withEducation([
                Education(
                    degree: "B.S. Computer Science",
                    school: "University of California",
                    period: "2015-2019",
                    description: "Focus on mobile development"
                )
            ])
            .withLanguages([
                Language(name: "English", level: "Native"),
                Language(name: "Spanish", level: "Conversational")
            ])
            .withCertifications([
                Certification(
                    name: "iOS Developer Certification",
                    issuer: "Apple",
                    year: 2020,
                    url: "https://apple.com/certification",
                    description: "Official iOS development certification"
                )
            ])
            .withInterests(["iOS Development", "Open Source", "Photography"])
            .withSocial([
                Social(platform: "GitHub", url: "https://github.com/janesmith"),
                Social(platform: "LinkedIn", url: "https://linkedin.com/in/janesmith")
            ])
    }
    
    public static func invalidCV() -> CVTestDataBuilder {
        return CVTestDataBuilder()
            .withName("")  // Invalid: empty name
            .withEmail("invalid-email")  // Invalid email format
    }
    
    public func build() -> CVModel {
        return CVModel(
            name: name,
            title: title,
            location: location,
            email: email,
            phone: phone,
            portfolio: portfolio,
            profile: profile,
            relevant_experience: relevant_experience,
            education: education,
            skills: skills,
            languages: languages,
            certifications: certifications,
            interests: interests,
            social: social
        )
    }
    
    public func build(id: UUID) -> CVModel {
        return CVModel(
            id: id,
            name: name,
            title: title,
            location: location,
            email: email,
            phone: phone,
            portfolio: portfolio,
            profile: profile,
            relevant_experience: relevant_experience,
            education: education,
            skills: skills,
            languages: languages,
            certifications: certifications,
            interests: interests,
            social: social
        )
    }
}