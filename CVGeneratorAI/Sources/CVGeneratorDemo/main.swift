import Foundation
import CVGeneratorAI

@main
struct CVGeneratorDemo {
    static func main() async {
        print("🤖 CVGeneratorAI Demo")
        print("=" * 50)
        print()

        // Create service (using Mock for demo)
        let service = MockCVGenerationService(shouldSucceed: true, mockDelay: 1.0)

        // Create use case with validation
        let useCase = CVGeneratorUseCase(service: service)

        // Check availability
        print("Checking service availability...")
        let available = await useCase.isAvailable()
        print("✅ Service available: \(available)")
        print()

        // Create personal info
        let personalInfo = PersonalInfo(
            name: "Alice Johnson",
            email: "alice.johnson@example.com",
            phone: "+1 (555) 234-5678",
            location: "Seattle, WA",
            website: "https://alicejohnson.dev",
            linkedin: "linkedin.com/in/alicejohnson",
            github: "github.com/alicejohnson",
            title: "Senior iOS Developer"
        )

        // Create generation request
        let request = CVGenerationRequest(
            userPrompt: """
            I am a Senior iOS Developer with 8 years of experience building scalable mobile applications.
            I specialize in SwiftUI, UIKit, and mobile architecture patterns.
            I have led teams of developers and mentored junior engineers.
            I hold a Bachelor's degree in Computer Science and several iOS certifications.
            My technical skills include Swift, SwiftUI, Combine, async/await, Core Data, and REST APIs.
            I speak English natively and Spanish at a professional level.
            """,
            personalInfo: personalInfo,
            preferences: GenerationPreferences(
                targetRole: "iOS Developer",
                experienceLevel: .senior,
                focusAreas: ["iOS", "SwiftUI", "Team Leadership"],
                tone: .professional
            )
        )

        print("📝 Generating CV for: \(personalInfo.name)")
        print("Target Role: iOS Developer")
        print("Experience Level: Senior")
        print()

        do {
            // Generate CV
            print("⏳ Generating CV (this may take a moment)...")
            let result = try await useCase.generateCV(from: request)

            print("✅ CV Generated Successfully!")
            print()

            // Display results
            print("=" * 50)
            print("📄 Generated CV Summary")
            print("=" * 50)
            print()

            print("👤 Personal Information:")
            print("   Name: \(result.cvData.personalInfo.name)")
            print("   Email: \(result.cvData.personalInfo.email)")
            if let title = result.cvData.personalInfo.title {
                print("   Title: \(title)")
            }
            if let location = result.cvData.personalInfo.location {
                print("   Location: \(location)")
            }
            print()

            if let summary = result.cvData.summary {
                print("📋 Summary:")
                print("   \(summary)")
                print()
            }

            print("💼 Experience: \(result.cvData.experience.count) entries")
            for (index, exp) in result.cvData.experience.enumerated() {
                print("   \(index + 1). \(exp.title) at \(exp.company)")
                print("      \(exp.startDate) - \(exp.endDate ?? "Present")")
                if !exp.achievements.isEmpty {
                    print("      Achievements: \(exp.achievements.count)")
                }
            }
            print()

            print("🎓 Education: \(result.cvData.education.count) entries")
            for (index, edu) in result.cvData.education.enumerated() {
                print("   \(index + 1). \(edu.degree)")
                print("      \(edu.institution)")
                if let gpa = edu.gpa {
                    print("      GPA: \(gpa)")
                }
            }
            print()

            print("🛠 Skills: \(result.cvData.skills.count) items")
            for skill in result.cvData.skills.prefix(5) {
                print("   • \(skill.name) - \(skill.level.rawValue)")
            }
            if result.cvData.skills.count > 5 {
                print("   ... and \(result.cvData.skills.count - 5) more")
            }
            print()

            print("🌍 Languages: \(result.cvData.languages.count)")
            for lang in result.cvData.languages {
                print("   • \(lang.name) - \(lang.proficiency.rawValue)")
            }
            print()

            print("📊 Generation Metadata:")
            print("   Confidence: \(String(format: "%.1f", result.confidence * 100))%")
            print("   Processing Time: \(String(format: "%.2f", result.metadata.processingTime))s")
            print("   Model Version: \(result.metadata.modelVersion)")
            print()

            if !result.suggestions.isEmpty {
                print("💡 Suggestions:")
                for suggestion in result.suggestions {
                    print("   • \(suggestion)")
                }
                print()
            }

            print("=" * 50)
            print("✨ Demo completed successfully!")

        } catch let error as CVGenerationError {
            print("❌ Generation failed: \(error.errorDescription ?? "Unknown error")")
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }
}

// Helper to repeat string
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
