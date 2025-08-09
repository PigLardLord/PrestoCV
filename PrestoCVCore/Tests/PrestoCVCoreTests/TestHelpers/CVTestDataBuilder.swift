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