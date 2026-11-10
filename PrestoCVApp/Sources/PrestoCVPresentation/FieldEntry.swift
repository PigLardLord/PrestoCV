/// What a field keeps of a change the person made, and where the focus goes (#402, 5-11d). A field of one line takes no
/// line break, even where it wraps onto more lines at a large text size: its return key moves to the next field and
/// leaves the text as it was, and a break that comes with other text, such as a pasted one, becomes a space. A paragraph
/// keeps its breaks.
public enum FieldEntry: Hashable, Sendable {
    /// The text the field keeps.
    case text(String)
    /// The return key: the text stays as it was, and the focus moves to `next`; nil ends the editing.
    case returnKey(next: EditorField?)

    /// What `field` keeps when its text `old` became `new`. A change that adds one line break where the cursor was, or
    /// puts one in place of a selection, is the return key: a field that wraps takes it as a line break, and the
    /// selection stays. Any other line break becomes a space.
    public init(_ new: String, after old: String, in field: EditorField) {
        if field.input == .paragraph {
            self = .text(new)
        } else if Self.isReturnKey(new, after: old) {
            self = .returnKey(next: field.nextDetail)
        } else {
            self = .text(String(new.map { $0.isNewline ? " " : $0 }))
        }
    }

    /// Whether `new` is `old` with one line break in place of the text between a start and an end of it, maybe none.
    /// "\r\n" is one character, so it counts once.
    private static func isReturnKey(_ new: String, after old: String) -> Bool {
        guard !old.contains(where: \.isNewline) else { return false }
        let breaks = new.indices.filter { new[$0].isNewline }
        guard breaks.count == 1, let lineBreak = breaks.first else { return false }
        let before = new[..<lineBreak]
        let after = new[new.index(after: lineBreak)...]
        return before.count + after.count <= old.count && old.hasPrefix(before) && old.hasSuffix(after)
    }
}

extension EditorField {
    /// The field after this one in the details, in the order the form shows them; nil after the summary, the last, and
    /// for the fields of the sections.
    public var nextDetail: EditorField? {
        switch self {
        case .title: .fullName
        case .fullName: .professionalTitle
        case .professionalTitle: .email
        case .email: .phone
        case .phone: .location
        case .location: .website
        case .website: .summary
        case .summary,
             .experienceRole, .experienceCompany, .experienceLocation, .experienceDescription, .experiencePeriod,
             .educationDegree, .educationSchool, .educationDescription, .educationPeriod,
             .skillName, .skillLevel, .language, .languageProficiency,
             .certificationName, .certificationIssuer, .certificationDescription, .certificationIssued,
             .certificationLink, .profilePlatform, .profileLink, .interest:
            nil
        }
    }
}
