/// Who the CV is about. The e-mail address, the phone number and the website are plain strings: each mapper hands over
/// values its own side has already validated, and this model only bounds them. The app's mapper (`PrestoCVIntegration`)
/// reads them from its domain types, and the server's reads them from its API types. An absent one is nil.
public struct SourcePersonalDetails: Hashable, Sendable {
    public let fullName: String
    public let professionalTitle: String
    public let email: String?
    public let phone: String?
    public let location: String
    public let website: String?

    /// The name must not be empty once trimmed; it is kept as written.
    public init(fullName: String, professionalTitle: String = "", email: String? = nil, phone: String? = nil,
                location: String = "", website: String? = nil) throws(TailoringModelError) {
        try Bounds.requiredText(fullName, .fullName)
        try Bounds.text(professionalTitle, .professionalTitle)
        try Bounds.optionalText(email, .email)
        try Bounds.optionalText(phone, .phone)
        try Bounds.text(location, .location)
        try Bounds.optionalText(website, .website)
        self.fullName = fullName
        self.professionalTitle = professionalTitle
        self.email = email
        self.phone = phone
        self.location = location
        self.website = website
    }
}
