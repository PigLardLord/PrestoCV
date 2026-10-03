import Testing
import TailoringModel

/// A string of exactly `count` UTF-8 bytes, all ASCII.
func ascii(_ count: Int) -> String { String(repeating: "a", count: count) }

/// A string of exactly `count` UTF-8 bytes made of two-byte characters, so a character count and a byte count differ.
func twoByteCharacters(bytes count: Int) -> String { String(repeating: "\u{00E9}", count: count / 2) }

/// A text field of the model, reached through the initialiser that owns it, so a bound is tested where it is enforced.
struct TextFieldCase: Sendable, CustomTestStringConvertible {
    let field: TailoringModelError.Field
    let build: @Sendable (String) throws -> Void
    init(_ field: TailoringModelError.Field, _ build: @escaping @Sendable (String) throws -> Void) {
        self.field = field
        self.build = build
    }
    var testDescription: String { "\(field)" }
}

/// One entry of each section of a CV, so a test names only what it varies.
enum Sample {
    static func personal() throws -> SourcePersonalDetails {
        try SourcePersonalDetails(fullName: "Ada Lovelace", professionalTitle: "Analyst", email: "ada@example.com", location: "London")
    }

    static func experience(_ name: String = "Engineer", description: String = "") throws -> SourceExperience {
        try SourceExperience(role: name, company: "Acme", description: description)
    }

    static func education() throws -> SourceEducation { try SourceEducation(degree: "BSc", school: "University") }
    static func skill() throws -> SourceSkill { try SourceSkill(name: "Swift", level: 4) }
    static func language() throws -> SourceLanguage { try SourceLanguage(name: "Italian", proficiency: .native) }
    static func certification() throws -> SourceCertification { try SourceCertification(name: "CKA", issuer: "CNCF") }
    static func profile() throws -> SourceProfile { try SourceProfile(platform: "GitHub", link: "https://github.com/ada") }
}
