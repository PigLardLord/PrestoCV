import Foundation

/// The fixtures as the files the app stores its CVs in, handed to the app at launch with `-PrestoCVUITestsSeed`.
extension StoreScreenshotFixture {
    /// The CVs of the list, the complete one first, each saved a little earlier than the one above it.
    func listFiles(now: Date = Date()) throws -> [String: String] {
        let ages: [TimeInterval] = [2 * 3_600, 26 * 3_600, 3 * 86_400, 12 * 86_400]
        let adapted = adaptations.prefix(ages.count - 1).enumerated().map { index, adaptation in
            var cv = complete
            cv.title = adaptation.title
            return file(named: adaptation.name, from: cv, savedAt: now - ages[index + 1])
        }
        return try encode([file(named: completeName, from: complete, savedAt: now - ages[0])] + adapted)
    }

    /// The CV with only the facts of the description, alone in the list.
    func draftFiles(now: Date = Date()) throws -> [String: String] {
        try encode([file(named: draftName, from: draft, savedAt: now - 60)])
    }

    // MARK: - File format

    private func file(named cvName: String, from cv: CV, savedAt: Date) -> StoredCV {
        StoredCV(
            name: cvName,
            personalInfo: .init(name: name, title: cv.title, location: cv.location, email: cv.email, profile: cv.profile),
            relevant_experience: cv.experience.map {
                .init(title: $0.title, company: $0.place, location: $0.location, period: $0.period, description: $0.description)
            },
            education: cv.education.map {
                .init(degree: $0.title, school: $0.place, period: $0.period, description: $0.description)
            },
            skills: cv.skills.map { .init(name: $0.name, level: $0.level) },
            languages: cv.languages.map { .init(name: $0.name, level: $0.level) },
            interests: cv.interests,
            documentLanguage: language,
            createdAt: savedAt - 30 * 86_400,
            updatedAt: savedAt
        )
    }

    private func encode(_ cvs: [StoredCV]) throws -> [String: String] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var files: [String: String] = [:]
        for cv in cvs {
            files["cv_\(cv.id.uuidString).json"] = String(decoding: try encoder.encode(cv), as: UTF8.self)
        }
        return files
    }
}

/// A CV as the app's store keeps it: the CV's fields, flat, and the times it was created and last saved.
private struct StoredCV: Encodable {
    var id = UUID()
    var name: String
    var personalInfo: PersonalInfo
    var relevant_experience: [Experience]
    var education: [Education]
    var skills: [Skill]
    var languages: [Language]
    var certifications: [String] = []
    var interests: [String]
    var social: [String] = []
    var documentLanguage: String
    var createdAt: Date
    var updatedAt: Date

    struct PersonalInfo: Encodable {
        var name: String
        var title: String
        var location: String
        var email: String
        var phone = ""
        var portfolio = ""
        var profile: String
    }

    struct Experience: Encodable {
        var id = UUID()
        var title: String
        var company: String
        var location: String
        var period: String
        var description: String
    }

    struct Education: Encodable {
        var id = UUID()
        var degree: String
        var school: String
        var period: String
        var description: String
    }

    struct Skill: Encodable {
        var id = UUID()
        var name: String
        var level: Int
    }

    struct Language: Encodable {
        var id = UUID()
        var name: String
        var level: String
    }
}
