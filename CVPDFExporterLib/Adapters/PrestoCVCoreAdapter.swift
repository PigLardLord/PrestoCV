import Foundation

// MARK: - PrestoCVCore Adapter

/// Adapter to convert PrestoCVCore data to CVDocument format
/// Sprint 0: Basic implementation with sample data
public struct PrestoCVCoreAdapter: Sendable {

    public init() {}

    /// Convert PrestoCVCore profile to CVDocument
    /// Sprint 0: Returns hardcoded sample data
    public func convertToCV(from profile: Any?) -> CVDocument {
        // Sprint 0: Return sample CV data for testing
        // Will be replaced with actual PrestoCVCore conversion in future sprints

        let personalInfo = PersonalInfo(
            name: "John Doe",
            email: "john.doe@example.com",
            phone: "+1 (555) 123-4567",
            location: "San Francisco, CA",
            website: "https://linkedin.com/in/johndoe",
            summary: "Experienced Software Engineer with 8+ years developing scalable iOS applications and leading cross-functional teams. Expertise in Swift, SwiftUI, and system architecture. Passionate about creating intuitive user experiences and maintaining high code quality standards."
        )

        let workExperience = CVSection(
            id: "work",
            type: .work,
            title: "Work Experience",
            items: [
                CVItem(
                    title: "Senior iOS Developer",
                    subtitle: "Tech Corp",
                    description: "Leading the iOS development team in building and maintaining flagship mobile applications serving 2M+ users.",
                    startDate: "Jan 2020",
                    endDate: "Present",
                    location: "San Francisco, CA",
                    tags: ["Swift", "SwiftUI", "Team Lead"]
                ),
                CVItem(
                    title: "iOS Developer",
                    subtitle: "StartupXYZ",
                    description: "Developed consumer-facing iOS applications from concept to App Store deployment.",
                    startDate: "Jun 2017",
                    endDate: "Dec 2019",
                    location: "San Francisco, CA",
                    tags: ["UIKit", "REST APIs", "Core Data"]
                ),
                CVItem(
                    title: "Junior Developer",
                    subtitle: "Digital Agency",
                    description: "Developed and maintained multiple client iOS applications across various industries.",
                    startDate: "Jul 2015",
                    endDate: "May 2017",
                    location: "New York, NY",
                    tags: ["Objective-C", "iOS", "Mobile"]
                )
            ],
            order: 1
        )

        let education = CVSection(
            id: "education",
            type: .education,
            title: "Education",
            items: [
                CVItem(
                    title: "Bachelor of Science in Computer Science",
                    subtitle: "University of California, Berkeley",
                    description: "GPA: 3.8/4.0 - Magna Cum Laude",
                    startDate: "2011",
                    endDate: "2015"
                )
            ],
            order: 2
        )

        let skills = CVSection(
            id: "skills",
            type: .skills,
            title: "Technical Skills",
            items: [
                CVItem(
                    title: "Languages & Frameworks",
                    tags: ["Swift", "SwiftUI", "UIKit", "Objective-C", "Combine"]
                ),
                CVItem(
                    title: "Tools & Platforms",
                    tags: ["Xcode", "Git", "CI/CD", "TestFlight", "Firebase"]
                ),
                CVItem(
                    title: "Architecture & Design",
                    tags: ["MVVM", "Clean Architecture", "TDD", "REST APIs"]
                ),
                CVItem(
                    title: "Soft Skills",
                    tags: ["Team Leadership", "Mentoring", "Agile/Scrum", "Code Review"]
                )
            ],
            order: 3
        )

        return CVDocument(
            personalInfo: personalInfo,
            sections: [workExperience, education, skills],
            metadata: DocumentMetadata()
        )
    }
}