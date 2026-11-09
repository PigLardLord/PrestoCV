import Testing
import PrestoCVPresentation

/// The kind of input each field asks for: a code the view maps to a keyboard, a content type and the corrections.
@Suite("Field input")
struct FieldInputTests {

    @Test("the email field asks for an address, so the keyboard has the @ and nothing is capitalised")
    func emailIsAnAddressField() {
        #expect(EditorField.email.input == .email)
    }

    @Test("a skill's name is plain text: tools and platforms are written as they are, with no correction")
    func skillNameIsPlainText() {
        #expect(EditorField.skillName.input == .plain)
        #expect(EditorField.profilePlatform.input == .plain)
    }

    @Test("a description is a paragraph, written over several lines")
    func descriptionIsAParagraph() {
        #expect(EditorField.experienceDescription.input == .paragraph)
        #expect(EditorField.summary.input == .paragraph)
    }

    static let expected: [EditorField: FieldInput] = [
        .title: .sentence, .fullName: .personName, .professionalTitle: .jobTitle, .email: .email, .phone: .phone,
        .location: .city, .website: .webAddress, .summary: .paragraph,
        .experienceRole: .jobTitle, .experienceCompany: .organization, .experienceLocation: .city,
        .experienceDescription: .paragraph, .experiencePeriod: .year,
        .educationDegree: .sentence, .educationSchool: .organization, .educationDescription: .paragraph,
        .educationPeriod: .year,
        .skillName: .plain, .skillLevel: .plain, .language: .sentence, .languageProficiency: .plain,
        .certificationName: .sentence, .certificationIssuer: .organization, .certificationDescription: .paragraph,
        .certificationIssued: .year, .certificationLink: .webAddress,
        .profilePlatform: .plain, .profileLink: .webAddress, .interest: .sentence,
    ]

    @Test("every field has the input of its kind", arguments: EditorField.allCases)
    func everyFieldHasAnInput(field: EditorField) {
        #expect(Self.expected[field] != nil, "the table lists every field: \(field) is missing")
        #expect(field.input == Self.expected[field], "\(field) asks for the input of its kind")
    }
}
