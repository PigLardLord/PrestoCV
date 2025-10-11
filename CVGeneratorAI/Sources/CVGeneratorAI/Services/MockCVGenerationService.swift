import Foundation

/// Mock implementation of CVGenerationService for testing and development
/// Generates realistic CV data based on user input
public final class MockCVGenerationService: CVGenerationService {
    private let shouldSucceed: Bool
    private let mockDelay: TimeInterval

    public init(shouldSucceed: Bool = true, mockDelay: TimeInterval = 0.5) {
        self.shouldSucceed = shouldSucceed
        self.mockDelay = mockDelay
    }

    public func isAvailable() async -> Bool {
        return true
    }

    public func generateCV(from request: CVGenerationRequest) async throws -> CVGenerationResult {
        // Simulate processing time
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))

        guard shouldSucceed else {
            throw CVGenerationError.unknown("Mock service configured to fail")
        }

        guard !request.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CVGenerationError.invalidPrompt
        }

        let startTime = Date()

        // Parse user input
        let parser = PromptParser(text: request.userPrompt)

        // Use provided personal info or generate defaults
        let personalInfo = request.personalInfo ?? PersonalInfo(
            name: "John Doe",
            email: "john.doe@example.com",
            phone: "+1 (555) 123-4567",
            location: "San Francisco, CA",
            title: request.preferences.targetRole ?? "Professional"
        )

        // Generate summary based on prompt and tone
        let summary = generateSummary(
            parser: parser,
            targetRole: request.preferences.targetRole,
            experienceLevel: request.preferences.experienceLevel,
            tone: request.preferences.tone
        )

        // Generate experience entries
        let experience = generateExperience(
            parser: parser,
            experienceLevel: request.preferences.experienceLevel,
            targetRole: request.preferences.targetRole
        )

        // Generate education
        let education = generateEducation(parser: parser, experienceLevel: request.preferences.experienceLevel)

        // Generate skills
        let skills = generateSkills(parser: parser, targetRole: request.preferences.targetRole)

        // Generate languages
        let languages = generateLanguages(parser: parser)

        // Generate certifications
        let certifications = generateCertifications(parser: parser, targetRole: request.preferences.targetRole)

        // Generate projects
        let projects = generateProjects(parser: parser, experienceLevel: request.preferences.experienceLevel)

        // Generate interests
        let interests = generateInterests(parser: parser)

        let cvData = CVData(
            personalInfo: personalInfo,
            summary: summary,
            experience: experience,
            education: education,
            skills: skills,
            languages: languages,
            certifications: certifications,
            projects: projects,
            interests: interests
        )

        let processingTime = Date().timeIntervalSince(startTime)
        let confidence = calculateConfidence(parser: parser)

        return CVGenerationResult(
            cvData: cvData,
            confidence: confidence,
            suggestions: generateSuggestions(cvData: cvData),
            metadata: ResultMetadata(
                generatedAt: Date(),
                processingTime: processingTime,
                modelVersion: "mock-1.0"
            )
        )
    }

    // MARK: - Generation Helpers

    private func generateSummary(
        parser: PromptParser,
        targetRole: String?,
        experienceLevel: ExperienceLevel,
        tone: Tone
    ) -> String {
        let role = targetRole ?? "professional"
        let years = experienceLevelToYears(experienceLevel)

        let adjective: String
        switch tone {
        case .professional: adjective = "results-driven"
        case .creative: adjective = "innovative and creative"
        case .technical: adjective = "technically proficient"
        case .academic: adjective = "research-oriented"
        }

        let keywords = parser.extractKeywords().prefix(5).joined(separator: ", ")
        let technologiesStr = parser.technologies.isEmpty ? "modern technologies" : parser.technologies.prefix(3).joined(separator: ", ")

        return """
        \(adjective.capitalized) \(role) with \(years) of experience in developing high-quality solutions. \
        Proven expertise in \(keywords.isEmpty ? "software development" : keywords) and \(technologiesStr). \
        Strong track record of delivering impactful results and collaborating with cross-functional teams \
        to achieve business objectives.
        """
    }

    private func generateExperience(
        parser: PromptParser,
        experienceLevel: ExperienceLevel,
        targetRole: String?
    ) -> [Experience] {
        let count = experienceLevelToJobCount(experienceLevel)
        var experiences: [Experience] = []

        let role = targetRole ?? "Professional"
        let technologies = parser.technologies.isEmpty ? ["Technology A", "Technology B"] : Array(parser.technologies.prefix(5))

        for i in 0..<count {
            let isCurrent = i == 0
            let seniority = i == 0 ? "Senior " : i == 1 ? "" : "Junior "
            let yearsAgo = i * 3

            let startYear = Calendar.current.component(.year, from: Date()) - yearsAgo - 3
            let endYear = isCurrent ? nil : startYear + 3

            experiences.append(Experience(
                title: "\(seniority)\(role)",
                company: generateCompanyName(index: i),
                location: generateLocation(index: i),
                startDate: String(startYear),
                endDate: endYear.map { String($0) },
                current: isCurrent,
                description: "Led development and implementation of innovative solutions that improved efficiency and user satisfaction. Collaborated with cross-functional teams to deliver high-quality products on schedule.",
                achievements: [
                    "Increased system performance by \(30 + i * 10)%",
                    "Reduced deployment time by \(20 + i * 15)%",
                    "Mentored \(2 + i) team members",
                    "Implemented automated testing reducing bugs by \(25 + i * 10)%"
                ],
                technologies: technologies
            ))
        }

        return experiences
    }

    private func generateEducation(parser: PromptParser, experienceLevel: ExperienceLevel) -> [Education] {
        var education: [Education] = []

        // Add degree based on experience level
        let hasMasters = experienceLevel == .senior || experienceLevel == .executive
        let currentYear = Calendar.current.component(.year, from: Date())

        if hasMasters {
            education.append(Education(
                degree: "Master of Science in Computer Science",
                institution: "Tech University",
                location: "Boston, MA",
                startDate: String(currentYear - 8),
                endDate: String(currentYear - 6),
                gpa: "3.9/4.0",
                description: "Specialized in Software Engineering and Artificial Intelligence",
                achievements: ["Dean's List", "Graduate Research Assistant", "Published 2 papers"]
            ))
        }

        education.append(Education(
            degree: "Bachelor of Science in Computer Science",
            institution: "State University",
            location: "San Francisco, CA",
            startDate: String(currentYear - 12),
            endDate: String(currentYear - 8),
            gpa: hasMasters ? "3.7/4.0" : "3.8/4.0",
            description: "Focus on Software Development and System Design",
            achievements: ["Dean's List", "CS Department Scholarship", "Senior Capstone Project Award"]
        ))

        return education
    }

    private func generateSkills(parser: PromptParser, targetRole: String?) -> [Skill] {
        var skills: [Skill] = []

        // Add parsed technologies as skills
        for tech in parser.technologies.prefix(8) {
            skills.append(Skill(
                name: tech,
                level: .expert,
                category: categorizeSkill(tech),
                yearsOfExperience: Int.random(in: 3...7)
            ))
        }

        // Add common skills if none found
        if skills.isEmpty {
            let defaultSkills = [
                ("Swift", "Programming Languages", 5),
                ("iOS Development", "Mobile", 5),
                ("SwiftUI", "Frameworks", 3),
                ("UIKit", "Frameworks", 5),
                ("Git", "Tools", 6),
                ("REST APIs", "Architecture", 4),
                ("Core Data", "Data", 4),
                ("Testing (XCTest)", "QA", 4)
            ]

            for (name, category, years) in defaultSkills {
                skills.append(Skill(
                    name: name,
                    level: years >= 5 ? .expert : .advanced,
                    category: category,
                    yearsOfExperience: years
                ))
            }
        }

        return skills
    }

    private func generateLanguages(parser: PromptParser) -> [Language] {
        var languages = [Language(name: "English", proficiency: .native)]

        if parser.text.contains("spanish") || parser.text.contains("español") {
            languages.append(Language(name: "Spanish", proficiency: .b2))
        }
        if parser.text.contains("french") || parser.text.contains("français") {
            languages.append(Language(name: "French", proficiency: .b1))
        }
        if parser.text.contains("german") || parser.text.contains("deutsch") {
            languages.append(Language(name: "German", proficiency: .b2))
        }
        if parser.text.contains("chinese") || parser.text.contains("mandarin") {
            languages.append(Language(name: "Mandarin Chinese", proficiency: .a2))
        }

        return languages
    }

    private func generateCertifications(parser: PromptParser, targetRole: String?) -> [Certification] {
        var certifications: [Certification] = []

        let currentYear = Calendar.current.component(.year, from: Date())

        if parser.text.contains("ios") || parser.text.contains("swift") || targetRole?.lowercased().contains("ios") == true {
            certifications.append(Certification(
                name: "iOS App Development with Swift",
                issuer: "Apple",
                date: String(currentYear - 1),
                url: "https://developer.apple.com"
            ))
        }

        if parser.text.contains("aws") || parser.text.contains("cloud") {
            certifications.append(Certification(
                name: "AWS Certified Solutions Architect",
                issuer: "Amazon Web Services",
                date: String(currentYear - 2),
                credentialId: "AWS-\(String(format: "%08d", Int.random(in: 10000000...99999999)))"
            ))
        }

        certifications.append(Certification(
            name: "Professional Scrum Master (PSM I)",
            issuer: "Scrum.org",
            date: String(currentYear - 1)
        ))

        return certifications
    }

    private func generateProjects(parser: PromptParser, experienceLevel: ExperienceLevel) -> [Project] {
        guard experienceLevel != .entry else { return [] }

        let technologies = parser.technologies.isEmpty ? ["Swift", "SwiftUI"] : Array(parser.technologies.prefix(4))

        return [
            Project(
                name: "Open Source Contribution",
                description: "Active contributor to popular open-source frameworks and libraries, focusing on performance improvements and new features.",
                role: "Core Contributor",
                startDate: "2022",
                technologies: technologies,
                url: "https://github.com/example",
                achievements: [
                    "Contributed 50+ pull requests",
                    "Resolved 30+ issues",
                    "Improved test coverage by 25%"
                ]
            ),
            Project(
                name: "Personal Portfolio Website",
                description: "Developed and maintain a professional portfolio website showcasing projects and technical skills.",
                role: "Designer & Developer",
                startDate: "2021",
                technologies: ["HTML", "CSS", "JavaScript"],
                achievements: [
                    "10,000+ monthly visitors",
                    "Featured in design community"
                ]
            )
        ]
    }

    private func generateInterests(parser: PromptParser) -> [String] {
        return ["Technology Trends", "Open Source", "Mentoring", "Continuous Learning", "Team Collaboration"]
    }

    private func generateSuggestions(cvData: CVData) -> [String] {
        var suggestions: [String] = []

        if cvData.certifications.isEmpty {
            suggestions.append("Consider adding professional certifications to strengthen your profile")
        }
        if cvData.projects.isEmpty {
            suggestions.append("Include personal or open-source projects to demonstrate initiative")
        }
        if cvData.summary == nil || cvData.summary!.count < 100 {
            suggestions.append("Expand your professional summary to highlight key achievements")
        }
        if cvData.experience.allSatisfy({ $0.achievements.isEmpty }) {
            suggestions.append("Add quantifiable achievements to your experience entries")
        }

        return suggestions
    }

    private func calculateConfidence(parser: PromptParser) -> Double {
        var confidence = 0.7

        if !parser.technologies.isEmpty {
            confidence += 0.1
        }
        if parser.text.count > 200 {
            confidence += 0.1
        }
        if parser.extractKeywords().count > 5 {
            confidence += 0.05
        }

        return min(confidence, 0.95)
    }

    // MARK: - Helper Functions

    private func experienceLevelToYears(_ level: ExperienceLevel) -> String {
        switch level {
        case .entry: return "1-2 years"
        case .intermediate: return "3-5 years"
        case .senior: return "7+ years"
        case .executive: return "10+ years"
        }
    }

    private func experienceLevelToJobCount(_ level: ExperienceLevel) -> Int {
        switch level {
        case .entry: return 1
        case .intermediate: return 2
        case .senior: return 3
        case .executive: return 4
        }
    }

    private func generateCompanyName(index: Int) -> String {
        let companies = ["Tech Innovations Inc.", "Digital Solutions Corp", "Future Systems Ltd", "Innovative Tech Co"]
        return companies[min(index, companies.count - 1)]
    }

    private func generateLocation(index: Int) -> String {
        let locations = ["San Francisco, CA", "New York, NY", "Seattle, WA", "Austin, TX"]
        return locations[min(index, locations.count - 1)]
    }

    private func categorizeSkill(_ skillName: String) -> String {
        let lower = skillName.lowercased()
        if lower.contains("swift") || lower.contains("python") || lower.contains("java") {
            return "Programming Languages"
        }
        if lower.contains("ui") || lower.contains("kit") || lower.contains("framework") {
            return "Frameworks"
        }
        if lower.contains("ios") || lower.contains("android") || lower.contains("mobile") {
            return "Mobile Development"
        }
        if lower.contains("git") || lower.contains("docker") || lower.contains("jenkins") {
            return "DevOps & Tools"
        }
        if lower.contains("api") || lower.contains("rest") || lower.contains("graphql") {
            return "APIs"
        }
        return "General"
    }
}

// MARK: - Prompt Parser

private struct PromptParser {
    let text: String

    var technologies: [String] {
        let techKeywords = [
            "Swift", "SwiftUI", "UIKit", "iOS", "Xcode", "Objective-C",
            "Python", "Java", "JavaScript", "TypeScript", "React", "Angular",
            "Docker", "Kubernetes", "AWS", "Azure", "GCP",
            "Git", "Jenkins", "CI/CD", "REST", "GraphQL",
            "SQL", "MongoDB", "PostgreSQL", "Firebase",
            "TDD", "Agile", "Scrum"
        ]

        return techKeywords.filter { text.contains($0) }
    }

    func extractKeywords() -> [String] {
        let keywords = [
            "leadership", "management", "architecture", "design",
            "development", "engineering", "analysis", "research",
            "collaboration", "communication", "problem-solving",
            "scalable", "performance", "optimization", "testing"
        ]

        return keywords.filter { text.lowercased().contains($0) }
    }
}
