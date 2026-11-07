internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// Where the person's text stands with the store, as a code the view words (R13).
public enum SaveStatus: Hashable, Sendable {
    /// The store holds what the form shows, and nothing waits: "saved on this device".
    case saved
    /// A change waits for the pause, or for the editor to be left.
    case pending
    /// The store is being written or read.
    case saving
    /// The CV has nothing to keep yet; nothing is stored until it has.
    case notEnoughContent
    /// A text is above its limit; nothing is stored until it is shorter.
    case textTooLong(EditorField)
    /// A section has more entries than its limit.
    case tooManyEntries(EditorSection)
    /// The CV as a whole is too large to store.
    case tooLarge
    /// A field holds text that cannot be read as its kind (an e-mail address, a phone number, a web address). The rest
    /// is stored; that field is not.
    case unreadable(EditorField)
    /// Someone saved the CV elsewhere since it was opened: `reload()` or `saveAsCopy()`.
    case conflict
    /// The CV was deleted elsewhere: `saveAsCopy()` keeps the text.
    case deletedElsewhere
    /// The store could not be written. The next change or `saveNow()` tries again.
    case failed
}

/// Where the last export stands. Separate from `SaveStatus`: each is reset only by its own intent.
public enum ExportStatus: Hashable, Sendable {
    case idle
    case exporting
    case done(pages: Int)
    /// The document needs more pages than it got.
    case truncated(pages: Int, required: Int)
    /// The CV says no document language, and the app has no detector yet.
    case languageNeeded
    /// The CV lacks what an export needs.
    case notReady
    /// The document language has no bundled headings; nothing is exported in another language.
    case unsupportedLanguage
    case invalid
    case incomplete
    case failed
}

/// A field of the editor's form, named by a status so that the view can mark it.
public enum EditorField: Hashable, Sendable, CaseIterable {
    case title, fullName, professionalTitle, email, phone, location, website, summary
    case experienceRole, experienceCompany, experienceLocation, experienceDescription, experiencePeriod
    case educationDegree, educationSchool, educationDescription, educationPeriod
    case skillName, skillLevel, language, languageProficiency
    case certificationName, certificationIssuer, certificationDescription, certificationIssued, certificationLink
    case profilePlatform, profileLink, interest
}

/// A section of the editor's form.
public enum EditorSection: Hashable, Sendable, CaseIterable {
    case experiences, education, skills, languages, certifications, profiles, interests
}

// MARK: - From the domain's codes

extension SaveStatus {
    /// Every failure of the store has its status (R7).
    init(_ failure: EditFailure) {
        switch failure {
        case .conflict: self = .conflict
        case .deletedElsewhere: self = .deletedElsewhere
        case .tooLarge, .cvTooLarge: self = .tooLarge
        case .notEnoughContent: self = .notEnoughContent
        case .textTooLong(let field): self = .textTooLong(EditorField(field))
        case .tooManyEntries(let section): self = .tooManyEntries(EditorSection(section))
        case .unavailable: self = .failed
        }
    }

    /// The status of content waiting to be written, by the domain's verdict on it: content that may be stored waits for its
    /// write, anything else says why it is not stored.
    init(waiting verdict: SaveVerdict) {
        switch verdict {
        case .ok: self = .pending
        case .notEnoughContent: self = .notEnoughContent
        case .textTooLong(let field): self = .textTooLong(EditorField(field))
        case .tooManyEntries(let section): self = .tooManyEntries(EditorSection(section))
        case .cvTooLarge: self = .tooLarge
        }
    }
}

extension ExportStatus {
    init(_ failure: ExportFailure) {
        switch failure {
        case .notReady: self = .notReady
        case .unsupportedLanguage: self = .unsupportedLanguage
        case .invalidDocument: self = .invalid
        case .incomplete: self = .incomplete
        case .renderingFailed: self = .failed
        }
    }
}

extension EditorField {
    init(_ field: CVTextField) {
        switch field {
        case .title: self = .title
        case .fullName: self = .fullName
        case .professionalTitle: self = .professionalTitle
        case .location: self = .location
        case .summary: self = .summary
        case .experienceRole: self = .experienceRole
        case .experienceCompany: self = .experienceCompany
        case .experienceLocation: self = .experienceLocation
        case .experienceDescription: self = .experienceDescription
        case .educationDegree: self = .educationDegree
        case .educationSchool: self = .educationSchool
        case .educationDescription: self = .educationDescription
        case .skillName: self = .skillName
        case .language: self = .language
        case .certificationName: self = .certificationName
        case .certificationIssuer: self = .certificationIssuer
        case .certificationDescription: self = .certificationDescription
        case .profilePlatform: self = .profilePlatform
        case .interest: self = .interest
        }
    }
}

extension EditorSection {
    init(_ section: CVSection) {
        switch section {
        case .experiences: self = .experiences
        case .education: self = .education
        case .skills: self = .skills
        case .languages: self = .languages
        case .certifications: self = .certifications
        case .profiles: self = .profiles
        case .interests: self = .interests
        }
    }
}
