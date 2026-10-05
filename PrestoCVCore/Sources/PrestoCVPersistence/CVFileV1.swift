import Foundation

/// The stored form of a CV, schema 1: a DTO separate from the domain (ADR 0009, PersistedSchema). Decoding is strict: required
/// fields are required, sizes are capped, and every value must be in the canonical, valid form its value object
/// produces. A file is never normalised or defaulted on read. The envelope is frozen: `schemaVersion` is a top-level
/// integer in every future version.
struct CVFileV1: Codable, Equatable {
    static let version = 1
    static let maxText = 10_000, maxItems = 500

    let schemaVersion: Int
    let id: UUID
    let revision: Int
    let createdAt: Date, updatedAt: Date
    let title: String
    let personal: PersonalV1
    let experiences: [ExperienceV1]
    let education: [EducationV1]
    let skills: [SkillV1]
    let languages: [LanguageV1]
    let certifications: [CertificationV1]
    let profiles: [ProfileV1]
    let interests: [String]
    let design: DesignV1?
    let language: String?

    struct PersonalV1: Codable, Equatable {
        let fullName: String, professionalTitle: String, email: String?, phone: String?, location: String, website: String?, summary: String
    }
    struct DateV1: Codable, Equatable { let year: Int, month: Int? }
    /// The three fields that store a period inside an entry. They are not nested in the file: the entry holds them itself.
    struct PeriodFieldsV1: Equatable { let start: DateV1?, end: DateV1?, current: Bool }
    struct ExperienceV1: Codable, Equatable {
        let role: String, company: String, location: String, description: String, start: DateV1?, end: DateV1?, current: Bool
    }
    struct EducationV1: Codable, Equatable {
        let degree: String, school: String, description: String, start: DateV1?, end: DateV1?, current: Bool
    }
    struct SkillV1: Codable, Equatable { let name: String, level: Int? }
    struct LanguageV1: Codable, Equatable { let language: String, proficiency: String }
    struct CertificationV1: Codable, Equatable { let name: String, issuer: String, description: String, issued: DateV1?, link: String? }
    struct ProfileV1: Codable, Equatable { let platform: String, link: String }
    struct DesignV1: Codable, Equatable { let design: String, palette: String?, fonts: String? }

    /// Why a file that decodes is still not a valid CV. The reason names the field and is shown with the quarantined file.
    struct Invalid: Error, Equatable { let reason: String }

    static func decode(_ data: Data) throws -> CVFileV1 {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CVFileV1.self, from: data)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
