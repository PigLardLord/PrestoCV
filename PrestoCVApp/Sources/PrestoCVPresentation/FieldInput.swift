/// The kind of text a field asks for, as a code: the view maps it to a keyboard, a content type and the corrections
/// (R13), through its platform shim.
public enum FieldInput: Hashable, Sendable, CaseIterable {
    /// A person's name: words capitalised, the name content type.
    case personName
    /// A role, such as "Product designer".
    case jobTitle
    /// A company, a school or an issuer.
    case organization
    /// A place, such as "Florence".
    case city
    /// An email address: no capitals, no correction.
    case email
    /// A phone number.
    case phone
    /// A web address: no capitals, no correction.
    case webAddress
    /// A year or a period, such as "2019 - 2023".
    case year
    /// Text written as it is, with no correction and no capitals: tools, skills, platforms.
    case plain
    /// A short text in sentence case.
    case sentence
    /// Several lines of text.
    case paragraph
}

extension EditorField {
    /// The kind of text the field asks for.
    public var input: FieldInput {
        switch self {
        case .fullName: .personName
        case .professionalTitle, .experienceRole: .jobTitle
        case .experienceCompany, .educationSchool, .certificationIssuer: .organization
        case .location, .experienceLocation: .city
        case .email: .email
        case .phone: .phone
        case .website, .certificationLink, .profileLink: .webAddress
        case .experiencePeriod, .educationPeriod, .certificationIssued: .year
        case .skillName, .skillLevel, .languageProficiency, .profilePlatform: .plain
        case .title, .educationDegree, .language, .certificationName, .interest: .sentence
        case .summary, .experienceDescription, .educationDescription, .certificationDescription: .paragraph
        }
    }
}
