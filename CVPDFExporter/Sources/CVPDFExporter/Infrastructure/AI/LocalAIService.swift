import Foundation

/// Local AI service implementation using pattern matching and heuristics
/// This will be replaced with Foundation Models framework when available
public final class LocalAIService: CVTailoringServiceProtocol, @unchecked Sendable {

    public init() {}

    public var isAvailable: Bool { true }

    public func tailorCV(
        jobDescription: String,
        cvDocument: CVDocument,
        targetRole: String?
    ) async throws -> CVTailoringResult {
        // Extract requirements from job description
        let requirements = extractRequirements(from: jobDescription)

        // Match CV skills with requirements
        let (relevant, missing) = matchSkills(cv: cvDocument, requirements: requirements)

        // Generate tailored summary
        let summary = generateTailoredSummary(
            cv: cvDocument,
            role: targetRole ?? "the position",
            requirements: requirements
        )

        // Reorder experiences based on relevance
        let orderedExperiences = prioritizeExperiences(
            cv: cvDocument,
            keywords: requirements.keywords
        )

        // Extract key achievements
        let achievements = extractAchievements(from: cvDocument)

        // Calculate match score
        let score = calculateMatchScore(
            relevant: relevant.count,
            missing: missing.count,
            required: requirements.requiredSkills.count
        )

        return CVTailoringResult(
            suggestedSummary: summary,
            relevantSkills: relevant,
            missingSkills: missing,
            experienceOrder: orderedExperiences,
            highlightedAchievements: achievements,
            matchScore: score
        )
    }

    /// Parses a job description and returns inferred requirements without tailoring a CV
    public func analyzeJobDescription(_ jobDescription: String) -> JobRequirements {
        extractRequirements(from: jobDescription)
    }

    // MARK: - Private Methods

    private func extractRequirements(from jobDescription: String) -> JobRequirements {
        let lowercased = jobDescription.lowercased()

        // Extract skills using common patterns
        let skillPatterns = [
            "swift", "swiftui", "uikit", "ios", "objective-c", "xcode",
            "javascript", "react", "node", "python", "java", "kotlin",
            "aws", "azure", "gcp", "docker", "kubernetes",
            "sql", "nosql", "mongodb", "postgresql",
            "git", "ci/cd", "jenkins", "agile", "scrum"
        ]

        let requiredSkills = skillPatterns.filter { lowercased.contains($0) }

        // Extract years of experience
        let yearsPattern = #"(\d+)\+?\s*years?"#
        let yearsRegex = try? NSRegularExpression(pattern: yearsPattern, options: .caseInsensitive)
        var yearsOfExperience: Int?

        if let regex = yearsRegex,
           let match = regex.firstMatch(in: jobDescription, range: NSRange(jobDescription.startIndex..., in: jobDescription)),
           let range = Range(match.range(at: 1), in: jobDescription) {
            yearsOfExperience = Int(jobDescription[range])
        }

        // Extract keywords
        let keywords = extractKeywords(from: jobDescription)

        // Extract education level
        var educationLevel: String?
        let educationPatterns = ["bachelor", "master", "phd", "degree"]
        for pattern in educationPatterns {
            if lowercased.contains(pattern) {
                educationLevel = pattern.capitalized
                break
            }
        }

        return JobRequirements(
            requiredSkills: requiredSkills,
            preferredSkills: [],
            yearsOfExperience: yearsOfExperience,
            educationLevel: educationLevel,
            keywords: keywords,
            responsibilities: []
        )
    }

    private func matchSkills(
        cv: CVDocument,
        requirements: JobRequirements
    ) -> (relevant: [String], missing: [String]) {
        // Get all skills from CV
        let cvSkills = cv.sections
            .filter { $0.type == .skills }
            .flatMap { $0.items }
            .flatMap { $0.tags }
            .map { $0.lowercased() }

        let requiredLower = requirements.requiredSkills.map { $0.lowercased() }

        let relevant = requiredLower.filter { required in
            cvSkills.contains { skill in
                skill.contains(required) || required.contains(skill)
            }
        }

        let missing = requiredLower.filter { required in
            !cvSkills.contains { skill in
                skill.contains(required) || required.contains(skill)
            }
        }

        return (relevant, missing)
    }

    private func generateTailoredSummary(
        cv: CVDocument,
        role: String,
        requirements: JobRequirements
    ) -> String {
        let currentTitle = cv.sections
            .filter { $0.type == .work }
            .flatMap { $0.items }
            .first?.title ?? "Professional"

        let yearsText = requirements.yearsOfExperience.map { "\($0)+ years of experience" } ?? "extensive experience"

        let skillsText = requirements.requiredSkills.prefix(3).joined(separator: ", ")

        return "\(currentTitle) with \(yearsText) seeking \(role) position. Expertise in \(skillsText) with a proven track record of delivering high-quality solutions."
    }

    private func prioritizeExperiences(
        cv: CVDocument,
        keywords: [String]
    ) -> [String] {
        let experiences = cv.sections
            .filter { $0.type == .work }
            .flatMap { $0.items }

        // Score each experience based on keyword matches
        let scored = experiences.map { item -> (item: CVItem, score: Int) in
            let text = "\(item.title) \(item.subtitle ?? "") \(item.description ?? "")".lowercased()
            let score = keywords.reduce(0) { count, keyword in
                count + (text.contains(keyword.lowercased()) ? 1 : 0)
            }
            return (item, score)
        }

        // Sort by score and return IDs
        return scored
            .sorted { $0.score > $1.score }
            .map { $0.item.id }
    }

    private func extractAchievements(from cv: CVDocument) -> [String] {
        let achievements = cv.sections
            .flatMap { $0.items }
            .compactMap { $0.description }
            .flatMap { description -> [String] in
                // Look for achievement patterns
                let patterns = [
                    "increased", "improved", "reduced", "led", "managed",
                    "delivered", "achieved", "built", "created", "developed"
                ]

                let sentences = description.components(separatedBy: ". ")
                return sentences.filter { sentence in
                    let lower = sentence.lowercased()
                    return patterns.contains { lower.contains($0) }
                }
            }

        return Array(achievements.prefix(5))
    }

    private func calculateMatchScore(relevant: Int, missing: Int, required: Int) -> Double {
        guard required > 0 else { return 0.5 }
        let score = Double(relevant) / Double(required)
        return min(1.0, max(0.0, score))
    }

    private func extractKeywords(from text: String) -> [String] {
        // Common technical and business keywords
        let importantWords = [
            "leadership", "team", "manage", "develop", "design", "implement",
            "optimize", "scale", "architecture", "performance", "quality",
            "customer", "product", "strategy", "analysis", "communication"
        ]

        let lowercased = text.lowercased()
        return importantWords.filter { lowercased.contains($0) }
    }
}
