import Foundation

/// The aggregate a user edits: personal details plus ordered sections of entries (RichDomain). State changes go through
/// methods. The revision and the timestamps belong to the repository: they can only be set from inside the package.
public struct CV: Hashable, Sendable {
    /// The identity of the CV, which no edit changes.
    public let id: CVID
    /// 0 until a repository stores the CV for the first time.
    public let revision: Int
    /// When a repository first stored the CV, or `nil` until it does.
    public let createdAt: Date?
    /// When a repository last stored the CV, or `nil` until it does.
    public let updatedAt: Date?
    /// The user's name for this CV in the list, such as "iOS roles". Not printed.
    public private(set) var title: String
    /// The details printed at the top of the CV. Changed through `setPersonalDetails(_:)`.
    public private(set) var personal: PersonalDetails
    /// The entries, by section. Changed through `setSections(_:)`.
    public private(set) var sections: CVSections
    /// The design the CV is exported with, or `nil` for the default. Changed through `choose(design:)`.
    public private(set) var design: DesignChoice?
    /// The language the CV is written in, or `nil` when it was not chosen. Changed through `setLanguage(_:)`.
    public private(set) var language: DocumentLanguage?

    /// A CV that has never been stored: revision 0, no timestamps.
    ///
    /// - Parameters:
    ///   - id: The identity of the CV.
    ///   - title: The user's name for the CV in the list. Empty until the user gives one.
    ///   - personal: The details printed at the top.
    ///   - sections: The entries.
    ///   - design: The design to export with, if chosen.
    ///   - language: The language the CV is written in, if chosen.
    public init(id: CVID, title: String = "", personal: PersonalDetails = PersonalDetails(), sections: CVSections = CVSections(),
                design: DesignChoice? = nil, language: DocumentLanguage? = nil) {
        self.init(id: id, revision: 0, createdAt: nil, updatedAt: nil, title: title, personal: personal, sections: sections,
                  design: design, language: language)
    }

    /// A CV as a repository stores it. Only repositories set the revision and the timestamps.
    package init(id: CVID, revision: Int, createdAt: Date?, updatedAt: Date?, title: String, personal: PersonalDetails,
                 sections: CVSections, design: DesignChoice?, language: DocumentLanguage?) {
        self.id = id; self.revision = revision; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.title = title; self.personal = personal; self.sections = sections; self.design = design; self.language = language
    }

    /// The same content as stored by a repository at `revision`, created at `createdAt` and last changed at `updatedAt`.
    package func stored(revision: Int, createdAt: Date?, updatedAt: Date) -> CV {
        CV(id: id, revision: revision, createdAt: createdAt, updatedAt: updatedAt, title: title, personal: personal,
           sections: sections, design: design, language: language)
    }

    /// The same content as stored by a repository at `revision`, at time `now`. A CV that was never stored is created at `now`.
    package func stored(revision: Int, at now: Date) -> CV {
        stored(revision: revision, createdAt: createdAt ?? now, updatedAt: now)
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
