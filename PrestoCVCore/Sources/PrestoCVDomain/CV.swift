import Foundation

/// Aggregate root: state changes go through methods (R6). Revision and timestamps belong to the
/// repository: they can only be set from inside the package (`package` access).
public struct CV: Hashable, Sendable {
    public let id: CVID
    public let revision: Int                 // 0 = never saved
    public let createdAt: Date?, updatedAt: Date?
    /// The user's name for this CV in the list, such as "iOS roles". Not printed.
    public private(set) var title: String
    public private(set) var personal: PersonalDetails
    public private(set) var sections: CVSections
    public private(set) var design: DesignChoice?
    public private(set) var language: DocumentLanguage?

    public init(id: CVID, title: String = "", personal: PersonalDetails = PersonalDetails(), sections: CVSections = CVSections(),
                design: DesignChoice? = nil, language: DocumentLanguage? = nil) {
        self.init(id: id, revision: 0, createdAt: nil, updatedAt: nil, title: title, personal: personal, sections: sections,
                  design: design, language: language)
    }

    package init(id: CVID, revision: Int, createdAt: Date?, updatedAt: Date?, title: String, personal: PersonalDetails,
                 sections: CVSections, design: DesignChoice?, language: DocumentLanguage?) {
        self.id = id; self.revision = revision; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.title = title; self.personal = personal; self.sections = sections; self.design = design; self.language = language
    }

    /// The same content as stored by a repository at `revision`, at time `now`.
    package func stored(revision: Int, at now: Date) -> CV {
        CV(id: id, revision: revision, createdAt: createdAt ?? now, updatedAt: now, title: title, personal: personal,
           sections: sections, design: design, language: language)
    }

    /// The one definition of "has enough content to be saved".
    public var canBeSaved: Bool { !personal.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public mutating func rename(_ newTitle: String) { title = newTitle }
    public mutating func setPersonalDetails(_ details: PersonalDetails) { personal = details }
    /// Every edit of the entries goes through here; the order is the one the user chose.
    public mutating func setSections(_ newSections: CVSections) { sections = newSections }
    public mutating func choose(design: DesignChoice?) { self.design = design }
    public mutating func setLanguage(_ language: DocumentLanguage?) { self.language = language }

    /// Duplication rule: the copy keeps the content and the design, not the identity or the history.
    /// The new title is composed by presentation, which knows the language (R13).
    public func duplicated(as newID: CVID, title: String) -> CV {
        CV(id: newID, title: title, personal: personal, sections: sections, design: design, language: language)
    }
}
