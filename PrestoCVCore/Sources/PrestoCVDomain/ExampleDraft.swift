/// A part of a CV that a rule names, whatever shape the CV is kept in.
public enum CVField: CaseIterable, Hashable, Sendable {
    /// The CV's own name, which only the list shows
    case title
    case fullName, professionalTitle, email, phone, location, website, summary
    /// The links of the person's profiles, such as GitHub's: a profile keeps its platform
    case profileLinks
}

/// A draft started from an example CV keeps what the example says of the work, and leaves blank who its person is and
/// how to reach them: their name, e-mail, phone, location and website, the links of their profiles, and the CV's own
/// name. Nothing is stored until the person saves the draft.
public enum ExampleDraft {
    public static let clearedFields: Set<CVField> = [.title, .fullName, .email, .phone, .location, .website, .profileLinks]
}
