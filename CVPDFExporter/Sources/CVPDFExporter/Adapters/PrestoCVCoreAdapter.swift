import Foundation
#if canImport(PrestoCVCore)
import PrestoCVCore
#endif

/// Adapter to convert PrestoCVCore data to CVDocument format
public struct PrestoCVCoreAdapter: Sendable {

    public init() {}

    /// Convert PrestoCVCore CVModel to CVDocument
    /// - Parameter cvModel: The source CVModel from PrestoCVCore
    /// - Returns: CVDocument for PDF export
    public func convertToCV(from cvModel: Any?) -> CVDocument {
        #if canImport(PrestoCVCore)
        if let model = cvModel as? CVModel {
            return convertFromCVModel(model)
        }
        #endif

        // Fallback for testing with mock data
        if let mockData = cvModel {
            return convertFromMockData(mockData)
        }

        // Default fallback
        return createDefaultDocument()
    }

    #if canImport(PrestoCVCore)
    private func convertFromCVModel(_ model: CVModel) -> CVDocument {
        let personalInfo = PersonalInfo(
            name: model.personalInfo.name,
            email: model.personalInfo.email,
            phone: model.personalInfo.phone,
            location: model.personalInfo.location,
            website: model.personalInfo.linkedIn,
            summary: model.personalInfo.summary
        )

        var sections: [CVSection] = []

        // Map work experience
        let workItems = model.relevant_experience.map { exp in
            CVItem(
                title: exp.title,
                subtitle: exp.company,
                description: exp.description,
                startDate: extractStartDate(from: exp.period),
                endDate: extractEndDate(from: exp.period),
                location: exp.location,
                tags: []
            )
        }
        sections.append(CVSection(
            id: "work",
            type: .work,
            title: "Work Experience",
            items: workItems,
            order: 1
        ))

        // Map education
        let educationItems = model.education.map { edu in
            CVItem(
                title: edu.degree,
                subtitle: edu.institution,
                description: edu.description,
                startDate: extractStartDate(from: edu.period),
                endDate: extractEndDate(from: edu.period),
                location: edu.location,
                tags: []
            )
        }
        sections.append(CVSection(
            id: "education",
            type: .education,
            title: "Education",
            items: educationItems,
            order: 2
        ))

        // Map skills
        let skillItems = model.skills.map { skill in
            CVItem(
                title: skill.name,
                subtitle: skill.level,
                description: nil,
                startDate: nil,
                endDate: nil,
                location: nil,
                tags: [skill.level]
            )
        }
        sections.append(CVSection(
            id: "skills",
            type: .skills,
            title: "Skills",
            items: skillItems,
            order: 3
        ))

        // Map languages
        let languageItems = model.languages.map { lang in
            CVItem(
                title: lang.name,
                subtitle: lang.level,
                description: nil,
                startDate: nil,
                endDate: nil,
                location: nil,
                tags: []
            )
        }
        sections.append(CVSection(
            id: "languages",
            type: .languages,
            title: "Languages",
            items: languageItems,
            order: 4
        ))

        // Map certifications
        let certificationItems = model.certifications.map { cert in
            CVItem(
                title: cert.name,
                subtitle: cert.issuer,
                description: cert.description,
                startDate: cert.date,
                endDate: nil,
                location: nil,
                tags: []
            )
        }
        sections.append(CVSection(
            id: "certifications",
            type: .certifications,
            title: "Certifications",
            items: certificationItems,
            order: 5
        ))

        return CVDocument(
            personalInfo: personalInfo,
            sections: sections,
            metadata: DocumentMetadata()
        )
    }
    #endif

    private func convertFromMockData(_ mockData: Any) -> CVDocument {
        // Use reflection to map mock data for testing
        let mirror = Mirror(reflecting: mockData)

        var name = "Test User"
        var email = "test@example.com"
        var phone: String?
        var location: String?
        var summary: String?
        var sections: [CVSection] = []

        for child in mirror.children {
            switch child.label {
            case "personalInfo":
                let info = child.value
                let infoMirror = Mirror(reflecting: info)
                for prop in infoMirror.children {
                    switch prop.label {
                    case "name": name = prop.value as? String ?? name
                    case "email": email = prop.value as? String ?? email
                    case "phone": phone = prop.value as? String
                    case "location": location = prop.value as? String
                    case "summary": summary = prop.value as? String
                    default: break
                    }
                }
            case "experiences":
                sections.append(mapExperiencesFromMock(child.value))
            case "education":
                sections.append(mapEducationFromMock(child.value))
            case "skills":
                sections.append(mapSkillsFromMock(child.value))
            case "languages":
                sections.append(mapLanguagesFromMock(child.value))
            case "certifications":
                sections.append(mapCertificationsFromMock(child.value))
            default: break
            }
        }

        return CVDocument(
            personalInfo: PersonalInfo(
                name: name,
                email: email,
                phone: phone,
                location: location,
                website: nil,
                summary: summary
            ),
            sections: sections,
            metadata: DocumentMetadata()
        )
    }

    private func mapExperiencesFromMock(_ value: Any) -> CVSection {
        var items: [CVItem] = []

        if let array = value as? [Any] {
            for exp in array {
                let mirror = Mirror(reflecting: exp)
                var title = ""
                var company = ""
                var location = ""
                var period = ""
                var description = ""

                for prop in mirror.children {
                    switch prop.label {
                    case "title": title = prop.value as? String ?? ""
                    case "company": company = prop.value as? String ?? ""
                    case "location": location = prop.value as? String ?? ""
                    case "period": period = prop.value as? String ?? ""
                    case "description": description = prop.value as? String ?? ""
                    default: break
                    }
                }

                items.append(CVItem(
                    title: title,
                    subtitle: company,
                    description: description,
                    startDate: extractStartDate(from: period),
                    endDate: extractEndDate(from: period),
                    location: location,
                    tags: []
                ))
            }
        }

        return CVSection(
            id: "work",
            type: .work,
            title: "Work Experience",
            items: items,
            order: 1
        )
    }

    private func mapEducationFromMock(_ value: Any) -> CVSection {
        var items: [CVItem] = []

        if let array = value as? [Any] {
            for edu in array {
                let mirror = Mirror(reflecting: edu)
                var degree = ""
                var institution = ""
                var period = ""

                for prop in mirror.children {
                    switch prop.label {
                    case "degree": degree = prop.value as? String ?? ""
                    case "institution": institution = prop.value as? String ?? ""
                    case "period": period = prop.value as? String ?? ""
                    default: break
                    }
                }

                items.append(CVItem(
                    title: degree,
                    subtitle: institution,
                    description: nil,
                    startDate: extractStartDate(from: period),
                    endDate: extractEndDate(from: period),
                    location: nil,
                    tags: []
                ))
            }
        }

        return CVSection(
            id: "education",
            type: .education,
            title: "Education",
            items: items,
            order: 2
        )
    }

    private func mapSkillsFromMock(_ value: Any) -> CVSection {
        var items: [CVItem] = []

        if let array = value as? [Any] {
            for skill in array {
                let mirror = Mirror(reflecting: skill)
                var name = ""
                var level = ""

                for prop in mirror.children {
                    switch prop.label {
                    case "name": name = prop.value as? String ?? ""
                    case "level": level = prop.value as? String ?? ""
                    default: break
                    }
                }

                items.append(CVItem(
                    title: name,
                    subtitle: nil,
                    description: nil,
                    startDate: nil,
                    endDate: nil,
                    location: nil,
                    tags: [level]
                ))
            }
        }

        return CVSection(
            id: "skills",
            type: .skills,
            title: "Skills",
            items: items,
            order: 3
        )
    }

    private func mapLanguagesFromMock(_ value: Any) -> CVSection {
        var items: [CVItem] = []

        if let array = value as? [Any] {
            for lang in array {
                let mirror = Mirror(reflecting: lang)
                var name = ""
                var level = ""

                for prop in mirror.children {
                    switch prop.label {
                    case "name": name = prop.value as? String ?? ""
                    case "level": level = prop.value as? String ?? ""
                    default: break
                    }
                }

                items.append(CVItem(
                    title: name,
                    subtitle: level,
                    description: nil,
                    startDate: nil,
                    endDate: nil,
                    location: nil,
                    tags: []
                ))
            }
        }

        return CVSection(
            id: "languages",
            type: .languages,
            title: "Languages",
            items: items,
            order: 4
        )
    }

    private func mapCertificationsFromMock(_ value: Any) -> CVSection {
        var items: [CVItem] = []

        if let array = value as? [Any] {
            for cert in array {
                let mirror = Mirror(reflecting: cert)
                var name = ""
                var issuer = ""
                var date = ""

                for prop in mirror.children {
                    switch prop.label {
                    case "name": name = prop.value as? String ?? ""
                    case "issuer": issuer = prop.value as? String ?? ""
                    case "date": date = prop.value as? String ?? ""
                    default: break
                    }
                }

                items.append(CVItem(
                    title: name,
                    subtitle: issuer,
                    description: nil,
                    startDate: date,
                    endDate: nil,
                    location: nil,
                    tags: []
                ))
            }
        }

        return CVSection(
            id: "certifications",
            type: .certifications,
            title: "Certifications",
            items: items,
            order: 5
        )
    }

    private func createDefaultDocument() -> CVDocument {
        let personalInfo = PersonalInfo(
            name: "John Doe",
            email: "john.doe@example.com",
            phone: "+1 (555) 123-4567",
            location: "San Francisco, CA",
            website: nil,
            summary: "Experienced professional"
        )

        let sections = [
            CVSection(
                id: "work",
                type: .work,
                title: "Work Experience",
                items: [
                    CVItem(
                        title: "Software Engineer",
                        subtitle: "Tech Company",
                        description: "Developing innovative solutions",
                        startDate: "2020",
                        endDate: "Present",
                        location: "San Francisco, CA",
                        tags: []
                    )
                ],
                order: 1
            ),
            CVSection(
                id: "education",
                type: .education,
                title: "Education",
                items: [
                    CVItem(
                        title: "Bachelor of Science",
                        subtitle: "University",
                        description: nil,
                        startDate: "2016",
                        endDate: "2020",
                        location: nil,
                        tags: []
                    )
                ],
                order: 2
            ),
            CVSection(
                id: "skills",
                type: .skills,
                title: "Skills",
                items: [
                    CVItem(
                        title: "Programming",
                        subtitle: "Advanced",
                        description: nil,
                        startDate: nil,
                        endDate: nil,
                        location: nil,
                        tags: ["Advanced"]
                    )
                ],
                order: 3
            )
        ]

        return CVDocument(
            personalInfo: personalInfo,
            sections: sections,
            metadata: DocumentMetadata()
        )
    }

    private func extractStartDate(from period: String) -> String? {
        let components = period.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        return components.first
    }

    private func extractEndDate(from period: String) -> String? {
        let components = period.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count > 1 else { return nil }
        return components[1]
    }
}