import Foundation

// MARK: - JSON Resume Adapter

/// Adapter to convert between CVDocument and JSON Resume format
/// Sprint 5: Export format support
public final class JSONResumeAdapter: Sendable {

    public init() {}

    // MARK: - CVDocument to JSON Resume

    /// Convert CVDocument to JSON Resume format
    public func toJSONResume(from document: CVDocument) -> JSONResume {
        // Convert basics
        let basics = createBasics(from: document.personalInfo)

        // Convert work experience
        let work = createWork(from: document.sections)

        // Convert education
        let education = createEducation(from: document.sections)

        // Convert skills
        let skills = createSkills(from: document.sections)

        return JSONResume(
            basics: basics,
            work: work.isEmpty ? nil : work,
            education: education.isEmpty ? nil : education,
            skills: skills.isEmpty ? nil : skills
        )
    }

    // MARK: - JSON Resume to CVDocument

    /// Convert JSON Resume to CVDocument format
    public func fromJSONResume(_ resume: JSONResume) -> CVDocument {
        // Convert personal info
        let personalInfo = createPersonalInfo(from: resume.basics)

        // Convert sections
        var sections: [CVSection] = []

        // Add work section
        if let workItems = createWorkSection(from: resume.work) {
            sections.append(workItems)
        }

        // Add education section
        if let educationItems = createEducationSection(from: resume.education) {
            sections.append(educationItems)
        }

        // Add skills section
        if let skillItems = createSkillsSection(from: resume.skills) {
            sections.append(skillItems)
        }

        return CVDocument(
            personalInfo: personalInfo,
            sections: sections,
            metadata: DocumentMetadata()
        )
    }

    // MARK: - Private Conversion Methods

    private func createBasics(from personalInfo: PersonalInfo) -> JSONResume.Basics {
        // Parse location if it's a string like "City, State, Country"
        let location: JSONResume.Location?
        if let locationString = personalInfo.location {
            location = JSONResume.Location(address: locationString)
        } else {
            location = nil
        }

        return JSONResume.Basics(
            name: personalInfo.name,
            label: nil, // We don't have a direct mapping for label
            image: nil, // No image support in PersonalInfo
            email: personalInfo.email,
            phone: personalInfo.phone,
            url: personalInfo.website,
            summary: personalInfo.summary,
            location: location,
            profiles: nil // No profiles support yet
        )
    }

    private func createWork(from sections: [CVSection]) -> [JSONResume.Work] {
        var workItems: [JSONResume.Work] = []

        for section in sections where section.type == .work {
            for item in section.items {
                let work = JSONResume.Work(
                    name: item.subtitle, // Company name
                    position: item.title, // Job title
                    url: nil,
                    startDate: item.startDate,
                    endDate: item.endDate,
                    summary: item.description,
                    highlights: nil // Could extract from description
                )
                workItems.append(work)
            }
        }

        return workItems
    }

    private func createEducation(from sections: [CVSection]) -> [JSONResume.Education] {
        var educationItems: [JSONResume.Education] = []

        for section in sections where section.type == .education {
            for item in section.items {
                let education = JSONResume.Education(
                    institution: item.subtitle, // School name
                    area: item.title, // Field of study
                    studyType: item.description, // Degree type
                    startDate: item.startDate,
                    endDate: item.endDate,
                    gpa: nil,
                    courses: nil
                )
                educationItems.append(education)
            }
        }

        return educationItems
    }

    private func createSkills(from sections: [CVSection]) -> [JSONResume.Skill] {
        var skillItems: [JSONResume.Skill] = []

        for section in sections where section.type == .skills {
            for item in section.items {
                let skill = JSONResume.Skill(
                    name: item.title,
                    level: nil, // Could determine from tags or description
                    keywords: item.tags.isEmpty ? nil : item.tags
                )
                skillItems.append(skill)
            }
        }

        return skillItems
    }

    private func createPersonalInfo(from basics: JSONResume.Basics?) -> PersonalInfo {
        guard let basics = basics else {
            return PersonalInfo(name: "", email: "")
        }

        // Combine location fields into a single string
        let location: String?
        if let loc = basics.location {
            let parts = [loc.city, loc.region, loc.countryCode].compactMap { $0 }
            location = parts.isEmpty ? loc.address : parts.joined(separator: ", ")
        } else {
            location = nil
        }

        return PersonalInfo(
            name: basics.name ?? "",
            email: basics.email ?? "",
            phone: basics.phone,
            location: location,
            website: basics.url,
            summary: basics.summary
        )
    }

    private func createWorkSection(from work: [JSONResume.Work]?) -> CVSection? {
        guard let work = work, !work.isEmpty else { return nil }

        let items = work.map { workItem in
            CVItem(
                title: workItem.position ?? "",
                subtitle: workItem.name,
                description: workItem.summary,
                startDate: workItem.startDate,
                endDate: workItem.endDate,
                location: nil,
                tags: []
            )
        }

        return CVSection(
            id: "work",
            type: .work,
            title: "Work Experience",
            items: items
        )
    }

    private func createEducationSection(from education: [JSONResume.Education]?) -> CVSection? {
        guard let education = education, !education.isEmpty else { return nil }

        let items = education.map { edu in
            CVItem(
                title: edu.area ?? "",
                subtitle: edu.institution,
                description: edu.studyType,
                startDate: edu.startDate,
                endDate: edu.endDate,
                location: nil,
                tags: []
            )
        }

        return CVSection(
            id: "education",
            type: .education,
            title: "Education",
            items: items
        )
    }

    private func createSkillsSection(from skills: [JSONResume.Skill]?) -> CVSection? {
        guard let skills = skills, !skills.isEmpty else { return nil }

        let items = skills.map { skill in
            CVItem(
                title: skill.name ?? "",
                subtitle: nil,
                description: nil,
                startDate: nil,
                endDate: nil,
                location: nil,
                tags: skill.keywords ?? []
            )
        }

        return CVSection(
            id: "skills",
            type: .skills,
            title: "Skills",
            items: items
        )
    }
}