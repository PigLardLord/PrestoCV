/// The notices the app shows on its Licences screen (#504): its own attribution and, once the app ships them, those of the
/// works of others it contains, each with the licence it names. The Licences screen owns this port (R3); its adapter is
/// `LicenceNoticesFile`, in `PrestoCVIntegration`, over the file the app bundles.
public protocol LicenceNoticesReading: Sendable {
    /// Every notice, in the order the screen lists them. A file that cannot be read or decoded throws; a cancelled task
    /// stays a `CancellationError` (R3, R7).
    func notices() async throws -> [LicenceNotice]
}

/// One notice: what it is about, whether that is the work of others, its text as written, and the licence it names.
public struct LicenceNotice: Hashable, Sendable {
    /// Unique among the notices.
    public let id: String
    /// What the notice is about, as the file writes it ("PrestoCV").
    public let title: String
    /// True for the work of others the app contains, false for the app's own notice.
    public let isThirdParty: Bool
    /// The notice, paragraphs apart by a blank line. Legal text is English in every app language.
    public let text: String
    public let licence: Licence

    public init(id: String, title: String, isThirdParty: Bool, text: String, licence: Licence) {
        self.id = id
        self.title = title
        self.isThirdParty = isThirdParty
        self.text = text
        self.licence = licence
    }
}

/// A licence a notice names: its name as the file writes it ("Apache License 2.0") and its whole text, paragraphs apart
/// by a blank line.
public struct Licence: Hashable, Sendable {
    public let id: String
    public let name: String
    public let text: String

    public init(id: String, name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }
}
