#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Core CV data model for AI generation
///
/// It holds only what the on-device model can fill from a short description. The lists have no length guide:
/// a limit is taken as a number to reach, and the model then fills every list with entries it made up.
@Generable
public struct CVData: Codable, Equatable, Sendable {
    @Guide(description: "Personal and contact information")
    public let personalInfo: PersonalInfo

    @Guide(description: "At most three sentences restating the description, with no numbers the person did not give; null if the description says too little")
    public let summary: String?

    @Guide(description: "Work experience in reverse chronological order (most recent first); empty if none was mentioned")
    public let experience: [Experience]

    @Guide(description: "Education; empty if none was mentioned")
    public let education: [Education]

    @Guide(description: "Skills the person named; empty if none was mentioned")
    public let skills: [Skill]

    @Guide(description: "Languages the person named; empty if none was mentioned")
    public let languages: [Language]

    @Guide(description: "Certifications the person named; empty if none was mentioned")
    public let certifications: [Certification]

    @Guide(description: "Hobbies and interests the person named; empty if none was mentioned")
    public let interests: [String]

    public init(
        personalInfo: PersonalInfo = PersonalInfo(),
        summary: String? = nil,
        experience: [Experience] = [],
        education: [Education] = [],
        skills: [Skill] = [],
        languages: [Language] = [],
        certifications: [Certification] = [],
        interests: [String] = []
    ) {
        self.personalInfo = personalInfo
        self.summary = summary
        self.experience = experience
        self.education = education
        self.skills = skills
        self.languages = languages
        self.certifications = certifications
        self.interests = interests
    }
}
#endif
