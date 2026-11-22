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
    /// What the CV keeps of the way its values were made: never printed, not content (`DraftBlock`). Nil: no draft.
    public private(set) var draft: DraftBlock?

    public init(id: CVID, title: String = "", personal: PersonalDetails = PersonalDetails(), sections: CVSections = CVSections(),
                design: DesignChoice? = nil, language: DocumentLanguage? = nil) {
        self.init(id: id, revision: 0, createdAt: nil, updatedAt: nil, title: title, personal: personal, sections: sections,
                  design: design, language: language)
    }

    /// `draft` is taken as it is: a caller that reads one from outside checks it with `setDraft(_:)`.
    package init(id: CVID, revision: Int, createdAt: Date?, updatedAt: Date?, title: String, personal: PersonalDetails,
                 sections: CVSections, design: DesignChoice?, language: DocumentLanguage?, draft: DraftBlock? = nil) {
        self.id = id; self.revision = revision; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.title = TextRules.singleLine(title); self.personal = personal; self.sections = sections; self.design = design; self.language = language
        self.draft = draft
    }

    /// The same content as stored by a repository at `revision`, at time `now`.
    package func stored(revision: Int, at now: Date) -> CV {
        CV(id: id, revision: revision, createdAt: createdAt ?? now, updatedAt: now, title: title, personal: personal,
           sections: sections, design: design, language: language, draft: draft)
    }

    /// "Has enough content to be saved", as `SaveRule` defines it. The size limits are not part of it: `saveCheck()` has both.
    var hasEnoughContent: Bool {
        let p = personal, s = sections
        return SaveRule.allowsSaving(
            personalDetails: [p.fullName, p.professionalTitle, p.email?.value ?? "", p.phone?.value ?? "", p.location,
                              p.website?.value ?? "", p.summary],
            sectionSizes: [s.experiences.count, s.education.count, s.skills.count, s.languages.count, s.certifications.count,
                           s.profiles.count, s.interests.count]
        )
    }

    /// Whether the CV can be saved: enough content, and within `CVLimits`. `saveCheck()` says why not.
    public var canBeSaved: Bool { saveCheck() == .ok }

    public mutating func rename(_ newTitle: String) { title = TextRules.singleLine(newTitle) }
    /// A detail with another value loses its draft mark.
    public mutating func setPersonalDetails(_ details: PersonalDetails) {
        draft = draft?.keeping(personal, changedTo: details)
        personal = details
    }
    /// Every edit of the entries goes through here; the order is the one the user chose. The draft's marks move with
    /// their rows (`DraftBlock.anchored(from:to:)`).
    public mutating func setSections(_ newSections: CVSections) {
        draft = draft?.anchored(from: sections, to: newSections)
        sections = newSections
    }
    public mutating func choose(design: DesignChoice?) { self.design = design }
    public mutating func setLanguage(_ language: DocumentLanguage?) { self.language = language }

    /// Sets the draft block; an empty block is no draft. A mark that names an entry the sections do not have refuses
    /// the whole block, and the CV keeps the draft it had.
    public mutating func setDraft(_ block: DraftBlock) throws(DraftError) {
        guard block.origins.keys.allSatisfy({ $0.isInside(sections) }) else { throw .placeOutsideSections }
        draft = block.isEmpty ? nil : block
    }

    /// This CV with the text of `other`: its title, details and sections. The identity, the revision, the times, the design,
    /// the language and the draft stay this CV's own, so that an editor's text can be written over the stored CV it started
    /// from without undoing a look or a language chosen since; the draft's marks follow the new text as in `setSections(_:)`.
    public func holding(contentOf other: CV) -> CV {
        var result = self
        result.rename(other.title)
        result.setPersonalDetails(other.personal)
        result.setSections(other.sections)
        return result
    }

    /// Duplication rule: the copy keeps the content, the design and the draft, not the identity or the history.
    /// The new title is composed by presentation, which knows the language (R13).
    public func duplicated(as newID: CVID, title: String) -> CV {
        CV(id: newID, revision: 0, createdAt: nil, updatedAt: nil, title: title, personal: personal, sections: sections,
           design: design, language: language, draft: draft)
    }
}
