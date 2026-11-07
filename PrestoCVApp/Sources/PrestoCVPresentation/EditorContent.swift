import Foundation

/// The person's text in the editor's form, as they typed it. The view model reads it into a CV when it stores or exports
/// it; the form keeps the text as typed, spaces and half-written addresses and dates included.
///
/// The sections are lists of rows. A row holds text and codes only: a period is the text of its start and its end, a level
/// is a number, a proficiency is the code of its level. The domain reads them when the CV is built.
public struct EditorContent: Hashable, Sendable {
    public var title: String
    public var fullName: String
    public var professionalTitle: String
    public var email: String
    public var phone: String
    public var location: String
    public var website: String
    public var summary: String
    public var experiences: [ExperienceRow]
    public var education: [EducationRow]
    public var skills: [SkillRow]
    public var languages: [LanguageRow]
    public var certifications: [CertificationRow]
    public var profiles: [ProfileRow]
    public var interests: [String]
}

/// A job in the form. The period is the text of its start and its end ("2020" or "2020-05"); `isCurrent` says it goes on.
public struct ExperienceRow: Hashable, Sendable {
    public var role: String
    public var company: String
    public var location: String
    public var periodStart: String
    public var periodEnd: String
    public var isCurrent: Bool
    public var description: String
}

public struct EducationRow: Hashable, Sendable {
    public var degree: String
    public var school: String
    public var periodStart: String
    public var periodEnd: String
    public var isCurrent: Bool
    public var description: String
}

public struct SkillRow: Hashable, Sendable {
    public var name: String
    /// The level, as the number the person picked; nil when none.
    public var level: Int?

    public init(name: String, level: Int?) {
        self.name = name
        self.level = level
    }
}

public struct LanguageRow: Hashable, Sendable {
    public var language: String
    /// The code of the level ("b2", "native"); blank until one is picked. The view words it (R13).
    public var proficiency: String

    public init(language: String, proficiency: String) {
        self.language = language
        self.proficiency = proficiency
    }
}

public struct CertificationRow: Hashable, Sendable {
    public var name: String
    public var issuer: String
    /// The text of the date it was issued ("2021" or "2021-06").
    public var issued: String
    public var link: String
    public var description: String
}

public struct ProfileRow: Hashable, Sendable {
    public var platform: String
    public var link: String

    public init(platform: String, link: String) {
        self.platform = platform
        self.link = link
    }
}

/// A look of the document, by the ids of its design, palette and fonts.
public struct EditorLook: Hashable, Sendable {
    public let design: String
    public let palette: String?
    public let fonts: String?

    public init(design: String, palette: String?, fonts: String?) {
        self.design = design
        self.palette = palette
        self.fonts = fonts
    }
}

/// A part of a look the person chose in the look picker.
public enum LookPart: Hashable, Sendable, CaseIterable {
    case design, palette, fonts
}

/// The PDF an export made, for the share sheet.
public struct ExportedDocument: Hashable, Sendable {
    public let pdf: Data
    public let pages: Int
}
