import Foundation

/// The aggregate a user edits: personal details plus ordered sections of entries (RichDomain). State changes go through
/// methods. The revision and the timestamps belong to the repository: they can only be set from inside the package.
public struct CV: Hashable, Sendable {
    public let id: CVID
    /// 0 until a repository stores the CV for the first time.
    public package(set) var revision = 0
    public package(set) var createdAt: Date?, updatedAt: Date?
    /// The user's name for this CV in the list, such as "iOS roles". Not printed.
    public private(set) var title: String
    public private(set) var personal: PersonalDetails
    public private(set) var sections: CVSections
    public private(set) var design: DesignChoice?
    public private(set) var language: DocumentLanguage?

    /// A CV that has never been stored: revision 0, no timestamps.
    public init(id: CVID, title: String = "", personal: PersonalDetails = PersonalDetails(), sections: CVSections = CVSections(),
                design: DesignChoice? = nil, language: DocumentLanguage? = nil) {
        self.id = id; self.title = title; self.personal = personal; self.sections = sections; self.design = design; self.language = language
    }

    /// The same content as stored by a repository at `revision`, at time `now`.
    package func stored(revision: Int, at now: Date) -> CV {
        var stored = self
        stored.revision = revision
        stored.createdAt = createdAt ?? now
        stored.updatedAt = now
        return stored
    }

    /// The one definition of "has enough content to be saved".
    public var canBeSaved: Bool { !personal.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Gives the CV another title in the list. The title is never printed.
    public mutating func rename(_ newTitle: String) { title = newTitle }
    /// Replaces the personal details.
    public mutating func setPersonalDetails(_ details: PersonalDetails) { personal = details }
    /// Every edit of the entries goes through here; the order is the one the user chose.
    public mutating func setSections(_ newSections: CVSections) { sections = newSections }
    /// Chooses the design the CV is exported with, or clears the choice.
    public mutating func choose(design: DesignChoice?) { self.design = design }
    /// Sets the language the CV is written in, or clears it.
    public mutating func setLanguage(_ language: DocumentLanguage?) { self.language = language }

    /// A copy under a new identity. It keeps the content and the design, not the identity or the history.
    ///
    /// - Parameters:
    ///   - newID: The identity of the copy.
    ///   - title: The title of the copy, composed by presentation, which knows the language (LocalisationAtEdges).
    public func duplicated(as newID: CVID, title: String) -> CV {
        CV(id: newID, title: title, personal: personal, sections: sections, design: design, language: language)
    }
}

extension Sequence where Element == CV {
    /// The CVs most recently changed first: the order of every listing. A CV that was never stored comes last.
    public func mostRecentlyChangedFirst() -> [CV] {
        sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }
}
