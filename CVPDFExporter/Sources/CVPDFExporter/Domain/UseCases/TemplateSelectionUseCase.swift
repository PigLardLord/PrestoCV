import Foundation

/// Use case for template selection and recommendation
public final class TemplateSelectionUseCase: Sendable {
    private let repository: TemplateRepositoryProtocol

    public init(repository: TemplateRepositoryProtocol) {
        self.repository = repository
    }

    /// Gets all available templates
    public func getAvailableTemplates() async throws -> [Template] {
        try await repository.getAllTemplates()
    }

    /// Gets a specific template by ID
    public func getTemplate(byId id: String) async throws -> Template? {
        try await repository.getTemplate(byId: id)
    }

    /// Recommends the most suitable template based on CV content
    public func recommendTemplate(for cv: CVDocument) async throws -> Template {
        let templates = try await repository.getAllTemplates()

        // Analyze CV to determine best template
        let cvType = analyzeCVType(cv)

        // Find matching template or return default
        switch cvType {
        case .technical:
            return templates.first { $0.id == "modern" } ?? templates[0]
        case .executive:
            return templates.first { $0.id == "professional" } ?? templates[0]
        case .creative:
            return templates.first { $0.id == "creative" } ?? templates[0]
        case .academic:
            return templates.first { $0.id == "minimal" } ?? templates[0]
        case .standard:
            return templates.first { $0.id == "professional" } ?? templates[0]
        }
    }

    /// Filters templates based on criteria
    public func filterTemplates(isPremium: Bool? = nil) async throws -> [Template] {
        let allTemplates = try await repository.getAllTemplates()

        var filtered = allTemplates

        if let isPremium = isPremium {
            filtered = filtered.filter { $0.isPremium == isPremium }
        }

        return filtered
    }

    // MARK: - Private Methods

    private func analyzeCVType(_ cv: CVDocument) -> CVType {
        // Check for technical indicators
        let hasSkillsSection = cv.sections.contains { $0.type == .skills }
        let hasTechnicalSkills = cv.sections
            .filter { $0.type == .skills }
            .flatMap { $0.items }
            .flatMap { $0.tags }
            .contains { tag in
                let technical = ["Swift", "iOS", "Android", "Python", "JavaScript", "React", "Java", "C++"]
                return technical.contains { tag.lowercased().contains($0.lowercased()) }
            }

        if hasSkillsSection && hasTechnicalSkills {
            return .technical
        }

        // Check for executive indicators
        let hasExecutiveRole = cv.sections
            .filter { $0.type == .work }
            .flatMap { $0.items }
            .contains { item in
                let executiveTitles = ["CEO", "CTO", "CFO", "Director", "VP", "President", "Executive"]
                return executiveTitles.contains { item.title.contains($0) }
            }

        if hasExecutiveRole {
            return .executive
        }

        // Check for creative indicators
        let hasPortfolio = cv.personalInfo.website != nil
        let hasProjects = cv.sections.contains { $0.type == .projects }
        let hasCreativeSkills = cv.sections
            .filter { $0.type == .skills }
            .flatMap { $0.items }
            .flatMap { $0.tags }
            .contains { tag in
                let creative = ["Design", "UI", "UX", "Photoshop", "Illustrator", "Sketch", "Figma"]
                return creative.contains { tag.contains($0) }
            }

        if hasPortfolio || hasProjects || hasCreativeSkills {
            return .creative
        }

        // Check for academic indicators
        let hasPublications = cv.sections.contains { $0.type == .publications }
        let hasPhD = cv.sections
            .filter { $0.type == .education }
            .flatMap { $0.items }
            .contains { $0.title.contains("PhD") || $0.title.contains("Ph.D.") }

        if hasPublications || hasPhD {
            return .academic
        }

        // Default to standard
        return .standard
    }
}

// MARK: - Supporting Types

private enum CVType {
    case technical
    case executive
    case creative
    case academic
    case standard
}