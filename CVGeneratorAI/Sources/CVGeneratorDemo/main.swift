import Foundation
import CVGeneratorAI

@main
struct CVGeneratorDemo {
    static func main() async {
        print("🤖 CVGeneratorAI Interactive Demo")
        print("=" * 60)
        print()

        // Collect user input
        print("Let's create your CV! Please provide the following information:")
        print()

        let name = prompt("Your full name: ")
        let email = prompt("Your email: ")
        let phone = prompt("Your phone (optional, press Enter to skip): ", optional: true)
        let location = prompt("Your location (e.g., 'San Francisco, CA'): ")
        let title = prompt("Your current/desired job title: ")

        print()
        print("Now, please describe your professional background.")
        print("Include your experience, skills, education, and achievements.")
        print("(Type your description and press Enter):")
        print()

        let background = readMultiline()

        print()
        print("Great! A few more preferences...")
        let targetRole = prompt("Target job role (e.g., 'iOS Developer'): ")

        print()
        print("Experience level:")
        print("1) Entry Level")
        print("2) Intermediate")
        print("3) Senior")
        print("4) Executive")
        let levelChoice = prompt("Choose (1-4): ")
        let experienceLevel = parseExperienceLevel(levelChoice)

        print()
        print("Tone preference:")
        print("1) Professional")
        print("2) Creative")
        print("3) Technical")
        print("4) Academic")
        let toneChoice = prompt("Choose (1-4): ")
        let tone = parseTone(toneChoice)

        print()
        print("=" * 60)
        print()

        // Create service - prefer real AI when available
        let (service, usingFoundationModels) = await selectBestService()
        let useCase = CVGeneratorUseCase(service: service)

        // Create personal info
        let personalInfo = PersonalInfo(
            name: name,
            email: email,
            phone: phone.isEmpty ? nil : phone,
            location: location,
            title: title
        )

        // Create request
        let request = CVGenerationRequest(
            userPrompt: background,
            personalInfo: personalInfo,
            preferences: GenerationPreferences(
                targetRole: targetRole,
                experienceLevel: experienceLevel,
                tone: tone
            )
        )

        print("⏳ Generating your CV...")
        print()

        do {
            let result = try await useCase.generateCV(from: request)

            print("✅ CV Generated Successfully!")
            print()
            displayFullCV(result.cvData, result: result)

        } catch let error as CVGenerationError {
            print("❌ Generation failed: \(error.errorDescription ?? "Unknown error")")

            // If using FoundationModels failed, offer to retry with Mock service
            if usingFoundationModels {
                print()
                print("ℹ️  This may be because:")
                print("   • Apple Intelligence model not yet downloaded")
                print("   • Model not fully initialized")
                print("   • Network connectivity issues")
                print()
                print("💡 Retrying with Mock service for demonstration...")
                print()

                let mockService = MockCVGenerationService(shouldSucceed: true, mockDelay: 1.5)
                let mockUseCase = CVGeneratorUseCase(service: mockService)

                do {
                    let result = try await mockUseCase.generateCV(from: request)
                    print("✅ CV Generated Successfully (using Mock service)!")
                    print()
                    displayFullCV(result.cvData, result: result)
                } catch {
                    print("❌ Mock service also failed: \(error)")
                }
            }
        } catch {
            print("❌ Unexpected error: \(error)")
        }
    }

    // MARK: - Service Selection

    static func selectBestService() async -> (CVGenerationService, Bool) {
        // Try to use FoundationModels service if available
        if #available(macOS 26, iOS 18.2, *) {
            let foundationService = FoundationModelsService()
            if await foundationService.isAvailable() {
                print("🧠 Using Apple Intelligence (FoundationModels)")
                print("   AI will extract exact details from your description")
                print()
                return (foundationService, true)
            } else {
                print("ℹ️  Apple Intelligence not available on this device")
                print("   Falling back to Mock service for demonstration")
                print()
            }
        } else {
            print("ℹ️  Apple Intelligence requires macOS 26+ or iOS 18.2+")
            print("   Falling back to Mock service for demonstration")
            print()
        }

        // Fallback to mock service
        return (MockCVGenerationService(shouldSucceed: true, mockDelay: 1.5), false)
    }

    // MARK: - Input Helpers

    static func prompt(_ message: String, optional: Bool = false) -> String {
        print(message, terminator: "")
        guard let input = readLine() else {
            return ""
        }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !optional && trimmed.isEmpty {
            print("⚠️  This field is required. Please try again.")
            return prompt(message, optional: optional)
        }
        return trimmed
    }

    static func readMultiline() -> String {
        var lines: [String] = []
        while let line = readLine() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !lines.isEmpty {
                break
            }
            lines.append(line)
        }
        return lines.joined(separator: " ")
    }

    static func parseExperienceLevel(_ choice: String) -> ExperienceLevel {
        switch choice {
        case "1": return .entry
        case "2": return .intermediate
        case "3": return .senior
        case "4": return .executive
        default: return .intermediate
        }
    }

    static func parseTone(_ choice: String) -> Tone {
        switch choice {
        case "1": return .professional
        case "2": return .creative
        case "3": return .technical
        case "4": return .academic
        default: return .professional
        }
    }

    // MARK: - Display Helpers

    static func displayFullCV(_ cv: CVData, result: CVGenerationResult) {
        print("=" * 60)
        print("📄 YOUR GENERATED CV")
        print("=" * 60)
        print()

        // Personal Info
        print("👤 PERSONAL INFORMATION")
        print("-" * 60)
        print("Name:     \(cv.personalInfo.name)")
        print("Email:    \(cv.personalInfo.email)")
        if let phone = cv.personalInfo.phone {
            print("Phone:    \(phone)")
        }
        if let location = cv.personalInfo.location {
            print("Location: \(location)")
        }
        if let title = cv.personalInfo.title {
            print("Title:    \(title)")
        }
        if let website = cv.personalInfo.website {
            print("Website:  \(website)")
        }
        if let linkedin = cv.personalInfo.linkedin {
            print("LinkedIn: \(linkedin)")
        }
        if let github = cv.personalInfo.github {
            print("GitHub:   \(github)")
        }
        print()

        // Summary
        if let summary = cv.summary {
            print("📋 PROFESSIONAL SUMMARY")
            print("-" * 60)
            print(wrapText(summary, width: 60))
            print()
        }

        // Experience
        if !cv.experience.isEmpty {
            print("💼 WORK EXPERIENCE")
            print("-" * 60)
            for (index, exp) in cv.experience.enumerated() {
                print("\n[\(index + 1)] \(exp.title)")
                print("    \(exp.company)\(exp.location.map { " | \($0)" } ?? "")")
                print("    \(exp.startDate) - \(exp.endDate ?? "Present")\(exp.current ? " (Current)" : "")")
                print()
                print(wrapText(exp.description, width: 56, indent: "    "))

                if !exp.achievements.isEmpty {
                    print()
                    print("    Key Achievements:")
                    for achievement in exp.achievements {
                        print("    • \(achievement)")
                    }
                }

                if !exp.technologies.isEmpty {
                    print()
                    print("    Technologies: \(exp.technologies.joined(separator: ", "))")
                }

                if index < cv.experience.count - 1 {
                    print()
                }
            }
            print()
        }

        // Education
        if !cv.education.isEmpty {
            print("🎓 EDUCATION")
            print("-" * 60)
            for (index, edu) in cv.education.enumerated() {
                print("\n[\(index + 1)] \(edu.degree)")
                print("    \(edu.institution)\(edu.location.map { " | \($0)" } ?? "")")
                print("    \(edu.startDate) - \(edu.endDate ?? "Present")")
                if let gpa = edu.gpa {
                    print("    GPA: \(gpa)")
                }
                if let description = edu.description {
                    print()
                    print(wrapText(description, width: 56, indent: "    "))
                }
                if !edu.achievements.isEmpty {
                    print()
                    print("    Honors & Achievements:")
                    for achievement in edu.achievements {
                        print("    • \(achievement)")
                    }
                }

                if index < cv.education.count - 1 {
                    print()
                }
            }
            print()
        }

        // Skills
        if !cv.skills.isEmpty {
            print("🛠 SKILLS")
            print("-" * 60)

            let grouped = Dictionary(grouping: cv.skills) { $0.category ?? "General" }
            for (category, skills) in grouped.sorted(by: { $0.key < $1.key }) {
                print("\n\(category):")
                for skill in skills {
                    let years = skill.yearsOfExperience.map { " (\($0) years)" } ?? ""
                    print("  • \(skill.name) - \(skill.level.rawValue)\(years)")
                }
            }
            print()
        }

        // Languages
        if !cv.languages.isEmpty {
            print("🌍 LANGUAGES")
            print("-" * 60)
            for lang in cv.languages {
                print("  • \(lang.name) - \(lang.proficiency.rawValue)")
            }
            print()
        }

        // Certifications
        if !cv.certifications.isEmpty {
            print("📜 CERTIFICATIONS")
            print("-" * 60)
            for cert in cv.certifications {
                print("\n  • \(cert.name)")
                print("    Issued by: \(cert.issuer)")
                print("    Date: \(cert.date)\(cert.expiryDate.map { " - Expires: \($0)" } ?? "")")
                if let credentialId = cert.credentialId {
                    print("    Credential ID: \(credentialId)")
                }
                if let url = cert.url {
                    print("    URL: \(url)")
                }
            }
            print()
        }

        // Projects
        if !cv.projects.isEmpty {
            print("🚀 NOTABLE PROJECTS")
            print("-" * 60)
            for (index, project) in cv.projects.enumerated() {
                print("\n[\(index + 1)] \(project.name)")
                if let role = project.role {
                    print("    Role: \(role)")
                }
                if let startDate = project.startDate {
                    let end = project.endDate ?? "Present"
                    print("    Duration: \(startDate) - \(end)")
                }
                print()
                print(wrapText(project.description, width: 56, indent: "    "))

                if !project.achievements.isEmpty {
                    print()
                    print("    Key Results:")
                    for achievement in project.achievements {
                        print("    • \(achievement)")
                    }
                }

                if !project.technologies.isEmpty {
                    print()
                    print("    Technologies: \(project.technologies.joined(separator: ", "))")
                }

                if let url = project.url {
                    print("    URL: \(url)")
                }

                if index < cv.projects.count - 1 {
                    print()
                }
            }
            print()
        }

        // Interests
        if !cv.interests.isEmpty {
            print("💡 INTERESTS & ACTIVITIES")
            print("-" * 60)
            print(cv.interests.joined(separator: " • "))
            print()
        }

        // Metadata
        print("=" * 60)
        print("📊 GENERATION METADATA")
        print("-" * 60)
        print("Confidence Score:  \(String(format: "%.1f", result.confidence * 100))%")
        print("Processing Time:   \(String(format: "%.2f", result.metadata.processingTime))s")
        print("Model Version:     \(result.metadata.modelVersion)")
        print("Generated At:      \(formatDate(result.metadata.generatedAt))")
        print()

        if !result.suggestions.isEmpty {
            print("💡 SUGGESTIONS FOR IMPROVEMENT")
            print("-" * 60)
            for suggestion in result.suggestions {
                print("  • \(suggestion)")
            }
            print()
        }

        print("=" * 60)
        print("✨ CV Generation Complete!")
        print()
    }

    static func wrapText(_ text: String, width: Int, indent: String = "") -> String {
        let words = text.split(separator: " ")
        var lines: [String] = []
        var currentLine = indent

        for word in words {
            let wordStr = String(word)
            if currentLine.count + wordStr.count + 1 <= width {
                if currentLine != indent {
                    currentLine += " "
                }
                currentLine += wordStr
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = indent + wordStr
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.joined(separator: "\n")
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Helper to repeat string
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
