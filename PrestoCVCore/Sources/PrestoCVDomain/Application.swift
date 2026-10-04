import Foundation

/// The job advert that a tailoring was made for: the company, the role and the text. The company and the role are what a
/// list shows, and an advert may not name either, so they may be empty. The text is what the tailoring read, and is not.
public struct Advert: Hashable, Sendable {
    public static let maxLineBytes = 256, maxTextBytes = 65_536
    public let company: String, role: String, text: String

    public init(company: String, role: String, text: String) throws(ApplicationError) {
        self.company = try ApplicationTextRule.trimmed(company, .advertCompany, maxBytes: Self.maxLineBytes)
        self.role = try ApplicationTextRule.trimmed(role, .advertRole, maxBytes: Self.maxLineBytes)
        self.text = try ApplicationTextRule.required(text, .advertText, maxBytes: Self.maxTextBytes, multiline: true)
    }
}

/// What a tailoring produces and the user keeps (ADR 0019): the advert, the tailored CV, its cover letter, when it was made
/// and where it came from. It is an aggregate of CV Authoring: state changes go through methods, and the revision and the
/// timestamps belong to the repository, so they are settable only inside the package (R6).
///
/// The tailored CV is part of the aggregate. It keeps its own `CVID`, which is given when the application is created and
/// never replaced, and it is never listed among the user's CVs. It has no revision or timestamps of its own: the
/// application's are its, and the repository stores them once. So an edit of the CV and an edit of the letter are both
/// conditional on the application's revision, and two edits made from the same revision conflict.
///
/// `createdAt` is when the user kept the application.
public struct Application: Hashable, Sendable {
    public let id: ApplicationID
    public let revision: Int                 // 0 = never saved
    public let createdAt: Date?, updatedAt: Date?
    /// The tailored CV, at the application's revision and with its timestamps.
    public private(set) var cv: CV
    public private(set) var letter: CoverLetter
    public let advert: Advert
    public let provenance: ApplicationProvenance

    /// A new, never-saved application. The CV is the tailored one, with the identity that it keeps; `CV.canBeSaved` holds for it.
    public init(id: ApplicationID, cv: CV, letter: CoverLetter, advert: Advert, provenance: ApplicationProvenance) throws(ApplicationError) {
        try self.init(id: id, revision: 0, createdAt: nil, updatedAt: nil, cv: cv, letter: letter, advert: advert, provenance: provenance)
    }

    package init(id: ApplicationID, revision: Int, createdAt: Date?, updatedAt: Date?, cv: CV, letter: CoverLetter, advert: Advert,
                 provenance: ApplicationProvenance) throws(ApplicationError) {
        guard cv.canBeSaved else { throw .cvCannotBeSaved }
        self.id = id; self.revision = revision; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.cv = Self.content(of: cv, id: cv.id, revision: revision, createdAt: createdAt, updatedAt: updatedAt)
        self.letter = letter; self.advert = advert; self.provenance = provenance
    }

    private static func content(of cv: CV, id: CVID, revision: Int, createdAt: Date?, updatedAt: Date?) -> CV {
        CV(id: id, revision: revision, createdAt: createdAt, updatedAt: updatedAt, title: cv.title, personal: cv.personal,
           sections: cv.sections, design: cv.design, language: cv.language)
    }

    private init(id: ApplicationID, revision: Int, createdAt: Date?, updatedAt: Date?, validated cv: CV, letter: CoverLetter, advert: Advert,
                  provenance: ApplicationProvenance) {
        self.id = id; self.revision = revision; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.cv = cv; self.letter = letter; self.advert = advert; self.provenance = provenance
    }

    /// The same application as a repository stores it, at `revision` and with these times. The CV takes them too.
    package func stamped(revision: Int, createdAt: Date?, updatedAt: Date?) -> Application {
        Application(id: id, revision: revision, createdAt: createdAt, updatedAt: updatedAt,
                    validated: Self.content(of: cv, id: cv.id, revision: revision, createdAt: createdAt, updatedAt: updatedAt),
                    letter: letter, advert: advert, provenance: provenance)
    }

    /// The same application as stored at `revision`, at time `now`.
    package func stored(revision: Int, at now: Date) -> Application { stamped(revision: revision, createdAt: createdAt ?? now, updatedAt: now) }

    /// Keeps the edited CV. Its identity stays the one it was given, its revision and times stay the application's, and it
    /// must meet `CV.canBeSaved`.
    public mutating func setCV(_ edited: CV) throws(ApplicationError) {
        guard edited.id == cv.id else { throw .cvIdentityChanged }
        guard edited.canBeSaved else { throw .cvCannotBeSaved }
        cv = Self.content(of: edited, id: cv.id, revision: revision, createdAt: createdAt, updatedAt: updatedAt)
    }

    public mutating func setLetter(_ edited: CoverLetter) { letter = edited }
}
