import Foundation

/// Mock implementation of CVGenerationService for testing and development
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

        // Generate mock CV data
        let personalInfo = request.personalInfo ?? PersonalInfo(
            name: "John Doe",
            email: "john.doe@example.com",
            phone: "+1 (555) 123-4567",
            location: "San Francisco, CA",
            title: "Software Engineer"
        )

        let cvData = CVData(
            personalInfo: personalInfo,
            summary: "Experienced professional with a strong background in technology and innovation.",
            experience: [
                Experience(
                    title: "Senior Software Engineer",
                    company: "Tech Corp",
                    location: "San Francisco, CA",
                    startDate: "Jan 2020",
                    endDate: nil,
                    current: true,
                    description: "Leading development of scalable applications",
                    achievements: [
                        "Improved system performance by 40%",
                        "Mentored team of 5 junior developers"
                    ],
                    technologies: ["Swift", "iOS", "SwiftUI"]
                )
            ],
            education: [
                Education(
                    degree: "Bachelor of Science in Computer Science",
                    institution: "University of Technology",
                    location: "Boston, MA",
                    startDate: "2015",
                    endDate: "2019",
                    gpa: "3.8/4.0",
                    description: "Focus on Software Engineering and AI"
                )
            ],
            skills: [
                Skill(name: "Swift", level: .expert, category: "Programming Languages", yearsOfExperience: 5),
                Skill(name: "iOS Development", level: .expert, category: "Mobile Development", yearsOfExperience: 5),
                Skill(name: "SwiftUI", level: .advanced, category: "Frameworks", yearsOfExperience: 3)
            ],
            languages: [
                Language(name: "English", proficiency: .native),
                Language(name: "Spanish", proficiency: .b2)
            ]
        )

        return CVGenerationResult(
            cvData: cvData,
            confidence: 0.85,
            suggestions: [
                "Consider adding more quantifiable achievements",
                "Add certifications to strengthen your profile"
            ],
            metadata: ResultMetadata(
                generatedAt: Date(),
                processingTime: mockDelay,
                modelVersion: "mock-1.0"
            )
        )
    }
}
