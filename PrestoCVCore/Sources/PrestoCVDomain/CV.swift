import Foundation

/// Why a CV cannot be saved: it has no visible name, or it is over a size bound.
public enum SaveBlocker: Hashable, Sendable { case missingName, limit(CVLimitViolation) }

/// Aggregate root: state changes go through methods (R6). Revision and timestamps belong to the
/// repository: they can only be set from inside the package (`package` access).
///
/// Its text is normalised where it enters, by the rule in `TextRule`: the initialisers (so a stored file too), `rename`,
/// `setPersonalDetails` and `setSections`. A CV holds no control character other than the line feed, which a summary or
/// a description keeps, no bidirectional or tag character, and no line break in a one-line field. What a CV returns is
/// the normalised text, not necessarily what was handed over.
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
        self.title = TextRule.singleLine(title); self.personal = personal.normalised(); self.sections = sections.normalised()
        self.design = design; self.language = language
    }

    /// The same content as stored by a repository at `revision`, at time `now`.
    package func stored(revision: Int, at now: Date) -> CV {
        CV(id: id, revision: revision, createdAt: createdAt ?? now, updatedAt: now, title: title, personal: personal,
           sections: sections, design: design, language: language)
    }

    /// The one answer to "can this CV be saved, and why not" (R6): nil when it can. A CV needs a full name with at least
    /// one visible character, and it must be within the size bounds. The name is checked first, then `limitViolation`,
    /// which walks the whole CV.
    public var saveBlocker: SaveBlocker? {
        guard personal.fullName.unicodeScalars.contains(where: \.isVisible) else { return .missingName }
        return limitViolation.map(SaveBlocker.limit)
    }

    /// Whether the CV can be saved: it has no `saveBlocker`, that is, a visible name and no size bound exceeded.
    public var canBeSaved: Bool { saveBlocker == nil }

    public mutating func rename(_ newTitle: String) { title = TextRule.singleLine(newTitle) }
    public mutating func setPersonalDetails(_ details: PersonalDetails) { personal = details.normalised() }
    /// Every edit of the entries goes through here; the order is the one the user chose.
    public mutating func setSections(_ newSections: CVSections) { sections = newSections.normalised() }
    public mutating func choose(design: DesignChoice?) { self.design = design }
    public mutating func setLanguage(_ language: DocumentLanguage?) { self.language = language }

    /// Duplication rule: the copy keeps the content and the design, not the identity or the history.
    /// The new title is composed by presentation, which knows the language (R13).
    public func duplicated(as newID: CVID, title: String) -> CV {
        CV(id: newID, title: title, personal: personal, sections: sections, design: design, language: language)
    }
}

private extension Unicode.Scalar {
    /// False for white space, for the characters a renderer leaves out (default ignorable code points, such as the joiners
    /// and the direction marks) and for control, format, unassigned and surrogate characters: a name made only of these
    /// prints nothing.
    var isVisible: Bool {
        if properties.isWhitespace || properties.isDefaultIgnorableCodePoint { return false }
        switch properties.generalCategory {
        case .control, .format, .unassigned, .surrogate: return false
        default: return true
        }
    }
}
