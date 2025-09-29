import Foundation

/// Use case for AI-powered CV tailoring
public final class CVTailoringUseCase: Sendable {
    private let aiService: CVTailoringServiceProtocol
    private let cache = TailoringCache()

    public init(aiService: CVTailoringServiceProtocol) {
        self.aiService = aiService
    }

    /// Tailors a CV for a specific job posting
    public func tailorForJob(
        cv: CVDocument,
        jobDescription: String,
        targetRole: String? = nil
    ) async throws -> TailoredCVResult {
        // Check cache first
        let cacheKey = makeCacheKey(cv: cv, job: jobDescription)
        if let cached = await cache.get(key: cacheKey) {
            return cached
        }

        // Get AI tailoring suggestions
        let tailoringResult = try await aiService.tailorCV(
            jobDescription: jobDescription,
            cvDocument: cv,
            targetRole: targetRole
        )

        // Apply tailoring to create new CV document
        let tailoredCV = applyTailoring(to: cv, with: tailoringResult)

        // Create result
        let result = TailoredCVResult(
            originalCV: cv,
            tailoredCV: tailoredCV,
            suggestions: tailoringResult,
            timestamp: Date()
        )

        // Cache it
        await cache.set(key: cacheKey, value: result)

        return result
    }

    /// Extracts requirements from a job posting
    public func analyzeJobPosting(_ jobDescription: String) async throws -> JobRequirements {
        // For now, use the local service's extraction
        let service = LocalAIService()
        let result = try await service.tailorCV(
            jobDescription: jobDescription,
            cvDocument: createEmptyCV(),
            targetRole: nil
        )

        return JobRequirements(
            requiredSkills: result.relevantSkills,
            preferredSkills: [],
            yearsOfExperience: nil,
            educationLevel: nil,
            keywords: [],
            responsibilities: []
        )
    }

    /// Suggests improvements for a CV
    public func suggestImprovements(for cv: CVDocument) async throws -> [CVImprovement] {
        var improvements: [CVImprovement] = []

        // Check for missing summary
        if cv.personalInfo.summary == nil || cv.personalInfo.summary?.isEmpty == true {
            improvements.append(CVImprovement(
                section: .summary,
                suggestion: "Add a professional summary to highlight your key strengths",
                priority: .high,
                example: "Experienced software engineer with 5+ years building scalable iOS applications"
            ))
        }

        // Check for skills section
        let hasSkills = cv.sections.contains { $0.type == .skills }
        if !hasSkills {
            improvements.append(CVImprovement(
                section: .skills,
                suggestion: "Add a skills section to showcase your technical expertise",
                priority: .high,
                example: "Swift, SwiftUI, UIKit, Core Data, REST APIs"
            ))
        }

        // Check for quantified achievements
        let hasNumbers = cv.sections
            .flatMap { $0.items }
            .compactMap { $0.description }
            .contains { desc in
                desc.contains(where: { $0.isNumber })
            }

        if !hasNumbers {
            improvements.append(CVImprovement(
                section: .work,
                suggestion: "Add quantified achievements to demonstrate impact",
                priority: .medium,
                example: "Increased app performance by 40% through optimization"
            ))
        }

        // Check for recent experience
        let currentYear = Calendar.current.component(.year, from: Date())
        let hasRecentExperience = cv.sections
            .filter { $0.type == .work }
            .flatMap { $0.items }
            .contains { item in
                item.endDate?.contains("\(currentYear)") == true ||
                item.endDate?.lowercased() == "present"
            }

        if !hasRecentExperience {
            improvements.append(CVImprovement(
                section: .work,
                suggestion: "Update your work experience with your most recent role",
                priority: .high
            ))
        }

        return improvements
    }

    /// Checks if AI service is available
    public var isAvailable: Bool {
        aiService.isAvailable
    }

    // MARK: - Private Methods

    private func applyTailoring(
        to cv: CVDocument,
        with result: CVTailoringResult
    ) -> CVDocument {
        var tailoredCV = cv

        // Apply suggested summary if available
        if let newSummary = result.suggestedSummary {
            tailoredCV = CVDocument(
                personalInfo: PersonalInfo(
                    name: cv.personalInfo.name,
                    email: cv.personalInfo.email,
                    phone: cv.personalInfo.phone,
                    location: cv.personalInfo.location,
                    website: cv.personalInfo.website,
                    summary: newSummary,
                    image: cv.personalInfo.image
                ),
                sections: cv.sections,
                metadata: cv.metadata
            )
        }

        // Reorder sections based on relevance
        if !result.experienceOrder.isEmpty {
            var reorderedSections = cv.sections
            if let workIndex = reorderedSections.firstIndex(where: { $0.type == .work }) {
                let workSection = reorderedSections[workIndex]
                let reorderedItems = reorderItems(
                    items: workSection.items,
                    order: result.experienceOrder
                )
                reorderedSections[workIndex] = CVSection(
                    id: workSection.id,
                    type: workSection.type,
                    title: workSection.title,
                    items: reorderedItems,
                    order: workSection.order,
                    visible: workSection.visible
                )
            }
            tailoredCV = CVDocument(
                personalInfo: tailoredCV.personalInfo,
                sections: reorderedSections,
                metadata: cv.metadata
            )
        }

        return tailoredCV
    }

    private func reorderItems(items: [CVItem], order: [String]) -> [CVItem] {
        var reordered: [CVItem] = []
        var remaining = items

        // Add items in specified order
        for id in order {
            if let index = remaining.firstIndex(where: { $0.id == id }) {
                reordered.append(remaining[index])
                remaining.remove(at: index)
            }
        }

        // Add remaining items
        reordered.append(contentsOf: remaining)

        return reordered
    }

    private func makeCacheKey(cv: CVDocument, job: String) -> String {
        "\(cv.hashValue)-\(job.hashValue)"
    }

    private func createEmptyCV() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(name: "", email: "")
        )
    }
}

// MARK: - Models

/// Result of CV tailoring
public struct TailoredCVResult: Sendable, Equatable {
    public let originalCV: CVDocument
    public let tailoredCV: CVDocument
    public let suggestions: CVTailoringResult
    public let timestamp: Date

    public init(
        originalCV: CVDocument,
        tailoredCV: CVDocument,
        suggestions: CVTailoringResult,
        timestamp: Date
    ) {
        self.originalCV = originalCV
        self.tailoredCV = tailoredCV
        self.suggestions = suggestions
        self.timestamp = timestamp
    }
}

/// Improvement suggestion for CV
public struct CVImprovement: Sendable, Equatable {
    public enum Section: String, Sendable {
        case summary = "summary"
        case work = "work"
        case education = "education"
        case skills = "skills"
        case projects = "projects"
    }

    public enum Priority: String, Sendable {
        case high = "high"
        case medium = "medium"
        case low = "low"
    }

    public let section: Section
    public let suggestion: String
    public let priority: Priority
    public let example: String?

    public init(
        section: Section,
        suggestion: String,
        priority: Priority,
        example: String? = nil
    ) {
        self.section = section
        self.suggestion = suggestion
        self.priority = priority
        self.example = example
    }
}

// MARK: - Cache

actor TailoringCache {
    private var storage: [String: TailoredCVResult] = [:]
    private let maxItems = 10

    func get(key: String) -> TailoredCVResult? {
        storage[key]
    }

    func set(key: String, value: TailoredCVResult) {
        if storage.count >= maxItems {
            if let firstKey = storage.keys.first {
                storage.removeValue(forKey: firstKey)
            }
        }
        storage[key] = value
    }

    func clear() {
        storage.removeAll()
    }
}