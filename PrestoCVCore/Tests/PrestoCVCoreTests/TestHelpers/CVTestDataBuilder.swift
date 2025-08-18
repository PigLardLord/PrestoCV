import Foundation
@testable import PrestoCVCore

/// A builder for creating test CVModel instances with default values and fluent configuration
public struct CVTestDataBuilder {
    private var name: String = "Test CV"
    private var personalInfo: PersonalInfo = PersonalInfo()
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
    
    public func withPersonalInfo(_ personalInfo: PersonalInfo) -> CVTestDataBuilder {
        var builder = self
        builder.personalInfo = personalInfo
        return builder
    }
    
    public func withTitle(_ title: String) -> CVTestDataBuilder {
        var builder = self
        builder.personalInfo.title = title
        return builder
    }
    
    public func withLocation(_ location: String) -> CVTestDataBuilder {
        var builder = self
        builder.personalInfo.location = location
        return builder
    }
    
    public func withEmail(_ email: String) -> CVTestDataBuilder {
        var builder = self
        builder.personalInfo.email = email
        return builder
    }
    
    public func withPhone(_ phone: String) -> CVTestDataBuilder {
        var builder = self
        builder.personalInfo.phone = phone
        return builder
    }
    
    public func withPortfolio(_ portfolio: String) -> CVTestDataBuilder {
        var builder = self
        builder.personalInfo.portfolio = portfolio
        return builder
    }
    
    public func withProfile(_ profile: String) -> CVTestDataBuilder {
        var builder = self
        builder.personalInfo.profile = profile
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
        var builder = CVTestDataBuilder()
        builder.personalInfo.name = "John Doe"
        builder.personalInfo.email = "john@example.com"
        return builder
    }
    
    public static func completeCV() -> CVTestDataBuilder {
        var builder = CVTestDataBuilder()
        builder.name = "Jane Smith"
        builder.personalInfo = PersonalInfo(
            name: "Jane Smith",
            title: "Senior iOS Developer",
            location: "San Francisco, CA",
            email: "jane.smith@example.com",
            phone: "+1-555-123-4567",
            portfolio: "https://janesmith.dev",
            profile: "Experienced iOS developer with 5+ years of experience"
        )
        builder.skills = [
            Skill(name: "Swift", level: 5),
            Skill(name: "SwiftUI", level: 4),
            Skill(name: "UIKit", level: 5)
        ]
        builder.relevant_experience = [
            Experience(
                title: "Senior iOS Developer",
                company: "Tech Corp",
                location: "San Francisco, CA",
                period: "2020-Present",
                description: "Lead iOS development team"
            )
        ]
        builder.education = [
            Education(
                degree: "B.S. Computer Science",
                school: "University of California",
                period: "2015-2019",
                description: "Focus on mobile development"
            )
        ]
        builder.languages = [
            Language(name: "English", level: .native),
            Language(name: "Spanish", level: .b2)
        ]
        builder.certifications = [
            Certification(
                name: "iOS Developer Certification",
                issuer: "Apple",
                year: 2020,
                url: "https://apple.com/certification",
                description: "Official iOS development certification"
            )
        ]
        builder.interests = ["iOS Development", "Open Source", "Photography"]
        builder.social = [
            Social(platform: "GitHub", url: "https://github.com/janesmith"),
            Social(platform: "LinkedIn", url: "https://linkedin.com/in/janesmith")
        ]
        return builder
    }
    
    public static func invalidCV() -> CVTestDataBuilder {
        var builder = CVTestDataBuilder()
        builder.name = ""  // Invalid: empty name
        builder.personalInfo.email = "invalid-email"  // Invalid email format
        return builder
    }
    
    public func build() -> CVModel {
        return CVModel(
            name: name,
            personalInfo: personalInfo,
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
            personalInfo: personalInfo,
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