import Foundation
import PrestoCVDomain
import PrestoCVApplication

/// A CV file of the released legacy store (ADR 0022): `cv_<UUID>.json`, the legacy CV flat in the JSON, plus the
/// whole-second times the legacy repository stamped. It is read as the legacy app reads it (a missing key is the
/// default, a key of the wrong type makes the file unreadable) and then mapped to the domain by `LegacyMapper`. A
/// legacy file never carries `schemaVersion`; if one does, the key is ignored, so no legacy file is ever read as schema 1.
enum LegacyCVFile {
    static func read(_ data: Data, fileName: String, fallback: Date) -> LegacyContent {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let raw: Raw
        do { raw = try decoder.decode(Raw.self, from: data) } catch { return .invalid(.json) }
        guard let text = raw.id, let uuid = UUID(uuidString: text) else { return .invalid(.id) }
        // The legacy repository names a file after the id's `uuidString`, so only that exact spelling is a legacy file.
        guard text == uuid.uuidString, fileName == "cv_\(text).json" else { return .invalid(.name) }
        var mapper = LegacyMapper()
        let cv = mapper.map(raw, id: CVID(uuid), fallback: fallback)
        return .cv(LegacyCV(cv: cv, drops: mapper.drops))
    }

    // MARK: The legacy shape

    struct Raw: Decodable {
        var id: String?, name: String?
        var personalInfo: Personal?
        var experiences: [Experience]?, education: [Education]?, skills: [Skill]?, languages: [Language]?
        var certifications: [Certification]?, interests: [String]?, social: [Social]?
        var documentLanguage: String?
        /// A look that cannot be read is no look, as in the legacy app: it only says how the CV is printed.
        var look: Lenient<Look>?
        var createdAt: Lenient<Date>?, updatedAt: Lenient<Date>?

        enum CodingKeys: String, CodingKey {
            case id, name, personalInfo, education, skills, languages, certifications, interests, social, documentLanguage, look
            case createdAt, updatedAt
            case experiences = "relevant_experience"
        }
    }

    struct Personal: Decodable { var name, title, location, email, phone, portfolio, profile: String? }
    struct Experience: Decodable { var title, company, location, period, description: String? }
    struct Education: Decodable { var degree, school, period, description: String? }
    struct Skill: Decodable { var name: String?, level: Int? }
    struct Language: Decodable { var name: String?, level: Lenient<String>? }
    struct Certification: Decodable { var name, issuer, url, description: String?, year: Int? }
    struct Social: Decodable { var platform, url: String? }
    struct Look: Decodable { var design, palette, fonts: String? }

    /// Decodes to nil instead of failing.
    struct Lenient<Value: Decodable>: Decodable {
        let value: Value?
        init(from decoder: any Decoder) throws {
            do { value = try decoder.singleValueContainer().decode(Value.self) } catch { value = nil }
        }
    }
}
