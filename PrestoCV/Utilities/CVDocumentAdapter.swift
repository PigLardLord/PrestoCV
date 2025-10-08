import Foundation
import PrestoCVCore
import CVPDFExporter

/// Adapter to convert CVDocument (from CVPDFExporter) to CVModel (for iOS app)
/// This is the reverse direction of PrestoCVCoreAdapter
struct CVDocumentAdapter {

    /// Convert CVDocument to CVModel
    /// - Parameter document: The source CVDocument from CVPDFExporter
    /// - Returns: CVModel for iOS app
    func convertToCVModel(from document: CVDocument) -> CVModel {
        CVModel(
            id: UUID(),
            name: "CV",
            personalInfo: convertPersonalInfo(from: document.personalInfo, sections: document.sections),
            relevant_experience: convertExperience(from: document.sections),
            education: convertEducation(from: document.sections),
            skills: convertSkills(from: document.sections),
            languages: convertLanguages(from: document.sections),
            certifications: convertCertifications(from: document.sections),
            interests: convertInterests(from: document.sections),
            social: convertSocial(from: document)
        )
    }

    // MARK: - Private Converters

    private func convertPersonalInfo(from info: CVPDFExporter.PersonalInfo, sections: [CVSection]) -> PrestoCVCore.PersonalInfo {
        PrestoCVCore.PersonalInfo(
            name: info.name,
            title: extractFirstJobTitle(from: sections),
            location: info.location ?? "",
            email: info.email ?? "",
            phone: info.phone ?? "",
            portfolio: info.website ?? "",
            profile: info.summary ?? ""
        )
    }

    private func extractFirstJobTitle(from sections: [CVSection]) -> String {
        sections
            .first(where: { $0.type == .work })?
            .items.first?.title ?? ""
    }

    private func convertExperience(from sections: [CVSection]) -> [Experience] {
        guard let workSection = sections.first(where: { $0.type == .work }) else {
            return []
        }

        return workSection.items.map { item in
            Experience(
                id: UUID(),
                title: item.title,
                company: item.subtitle ?? "",
                location: item.location ?? "",
                period: formatPeriod(item),
                description: formatDescription(item)
            )
        }
    }

    private func convertEducation(from sections: [CVSection]) -> [Education] {
        guard let eduSection = sections.first(where: { $0.type == .education }) else {
            return []
        }

        return eduSection.items.map { item in
            Education(
                id: UUID(),
                degree: item.title,
                school: item.subtitle ?? "",
                period: formatPeriod(item),
                description: item.description ?? ""
            )
        }
    }

    private func convertSkills(from sections: [CVSection]) -> [Skill] {
        guard let skillsSection = sections.first(where: { $0.type == .skills }) else {
            return []
        }

        return skillsSection.items.map { item in
            let level = extractSkillLevel(from: item)
            return Skill(name: item.title, level: level)
        }
    }

    private func convertLanguages(from sections: [CVSection]) -> [Language] {
        guard let langSection = sections.first(where: { $0.type == .languages }) else {
            return []
        }

        return langSection.items.map { item in
            let level = parseLanguageLevel(from: item.tags.first ?? "")
            return Language(name: item.title, level: level)
        }
    }

    private func convertCertifications(from sections: [CVSection]) -> [Certification] {
        guard let certSection = sections.first(where: { $0.type == .certifications }) else {
            return []
        }

        return certSection.items.map { item in
            let year = extractYear(from: item)
            return Certification(
                id: UUID(),
                name: item.title,
                issuer: item.subtitle ?? "",
                year: year,
                url: item.url ?? "",
                description: item.description
            )
        }
    }

    private func convertInterests(from sections: [CVSection]) -> [String] {
        sections
            .first(where: { $0.type == .interests })?
            .items.map { $0.title } ?? []
    }

    private func convertSocial(from document: CVDocument) -> [Social] {
        var socials: [Social] = []

        if let linkedin = document.personalInfo.linkedin {
            socials.append(Social(platform: "LinkedIn", url: linkedin))
        }
        if let github = document.personalInfo.github {
            socials.append(Social(platform: "GitHub", url: github))
        }

        return socials
    }

    // MARK: - Helpers

    private func formatPeriod(_ item: CVItem) -> String {
        if let range = item.dateRange, !range.isEmpty {
            return range
        }
        if let start = item.startDate, let end = item.endDate {
            return "\(start) - \(end)"
        }
        if let start = item.startDate {
            return start
        }
        return ""
    }

    private func formatDescription(_ item: CVItem) -> String {
        var parts: [String] = []

        if let desc = item.description {
            parts.append(desc)
        }

        if !item.highlights.isEmpty {
            parts.append(item.highlights.map { "• \($0)" }.joined(separator: " "))
        }

        return parts.joined(separator: " ")
    }

    private func extractSkillLevel(from item: CVItem) -> Int {
        if let levelStr = item.metadata["level"], let level = Int(levelStr) {
            return level
        }

        for tag in item.tags {
            if let level = Int(tag), (1...5).contains(level) {
                return level
            }
        }

        return 3
    }

    private func parseLanguageLevel(from tag: String) -> LanguageLevel {
        let lowercased = tag.lowercased()
        if lowercased.contains("native") { return .native }
        if lowercased.contains("c2") { return .c2 }
        if lowercased.contains("c1") { return .c1 }
        if lowercased.contains("b2") || lowercased.contains("professional") { return .b2 }
        if lowercased.contains("b1") { return .b1 }
        if lowercased.contains("a2") || lowercased.contains("conversational") { return .a2 }
        if lowercased.contains("a1") { return .a1 }
        return .b1
    }

    private func extractYear(from item: CVItem) -> Int {
        if let yearStr = item.metadata["year"], let year = Int(yearStr) {
            return year
        }
        if let startDate = item.startDate, let year = Int(startDate) {
            return year
        }
        return 2023
    }
}
