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
    public var interests: [InterestRow]
}

/// The identity of a row in the form: it stays with the row while the rows around it come and go, and the CV never holds
/// it. Only the editor makes them (a view takes the ids of the rows it is given), so there is no public initialiser.
public struct RowID: Hashable, Sendable {
    let value: Int
}

/// The ids of the rows of one editor: a counter, so that no two rows of its life share one (no clock, no randomness).
struct RowIDs {
    private var issued = 0

    mutating func make() -> RowID {
        issued += 1
        return RowID(value: issued)
    }

    /// `content` with unique row ids, the one place every entry of rows into the form passes through: a row whose id was
    /// never issued here, or is taken by an earlier row of any section, gets a fresh one; the first row keeps its id.
    mutating func unique(_ content: EditorContent) -> EditorContent {
        var taken = Set<RowID>()
        var unique = content
        unique.experiences = settle(content.experiences, taken: &taken)
        unique.education = settle(content.education, taken: &taken)
        unique.skills = settle(content.skills, taken: &taken)
        unique.languages = settle(content.languages, taken: &taken)
        unique.certifications = settle(content.certifications, taken: &taken)
        unique.profiles = settle(content.profiles, taken: &taken)
        unique.interests = settle(content.interests, taken: &taken)
        return unique
    }

    private mutating func settle<Row: EditorRow>(_ rows: [Row], taken: inout Set<RowID>) -> [Row] {
        rows.map { row in
            var row = row
            if row.id.value < 1 || row.id.value > issued || !taken.insert(row.id).inserted {
                row.id = make()
                taken.insert(row.id)
            }
            return row
        }
    }
}

/// The rows go by their ids in a view's lists.
extension ExperienceRow: Identifiable {}
extension EducationRow: Identifiable {}
extension SkillRow: Identifiable {}
extension LanguageRow: Identifiable {}
extension CertificationRow: Identifiable {}
extension ProfileRow: Identifiable {}
extension InterestRow: Identifiable {}

extension Array where Element: Identifiable, Element.ID == RowID {
    /// The row with this id, wherever it stands: a view binds a row's fields through it, never through its place (#32).
    /// A row that went meanwhile reads as `shown`, the row as the view last had it, and a write to it is dropped.
    public subscript(row id: RowID, or shown: Element) -> Element {
        get { first { $0.id == id } ?? shown }
        set {
            guard let index = firstIndex(where: { $0.id == id }) else { return }
            self[index] = newValue
        }
    }
}

/// A row of a section: it has an id and a name, and it can have nothing in it.
protocol EditorRow {
    var id: RowID { get set }
    var rowName: RowName { get }
    var isBlank: Bool { get }
}

/// An interest in the form.
public struct InterestRow: Hashable, Sendable {
    public internal(set) var id: RowID
    public var text: String
}

/// A job in the form. The period is the text of its start and its end ("2020" or "2020-05"); `isCurrent` says it goes on.
public struct ExperienceRow: Hashable, Sendable {
    public internal(set) var id: RowID
    public var role: String
    public var company: String
    public var location: String
    public var periodStart: String
    public var periodEnd: String
    public var isCurrent: Bool
    public var description: String
}

public struct EducationRow: Hashable, Sendable {
    public internal(set) var id: RowID
    public var degree: String
    public var school: String
    public var periodStart: String
    public var periodEnd: String
    public var isCurrent: Bool
    public var description: String
}

public struct SkillRow: Hashable, Sendable {
    public internal(set) var id: RowID
    public var name: String
    /// The level, as the number the person picked; nil when none.
    public var level: Int?
}

public struct LanguageRow: Hashable, Sendable {
    public internal(set) var id: RowID
    public var language: String
    /// The code of the level ("b2", "native"); blank until one is picked. The view words it (R13).
    public var proficiency: String
}

public struct CertificationRow: Hashable, Sendable {
    public internal(set) var id: RowID
    public var name: String
    public var issuer: String
    /// The text of the date it was issued ("2021" or "2021-06").
    public var issued: String
    public var link: String
    public var description: String
}

public struct ProfileRow: Hashable, Sendable {
    public internal(set) var id: RowID
    public var platform: String
    public var link: String
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

/// The identity of one export of the export sheet: two exports have different ones, whatever their PDFs hold.
public struct ExportID: Hashable, Sendable {
    let generation: Int

    init(generation: Int) { self.generation = generation }
}

/// The PDF of an export, shown on the whole screen.
public struct FullPDF: Identifiable, Hashable, Sendable {
    /// The export that made the PDF.
    public let id: ExportID
    public let document: ExportedDocument
    /// The title of the screen: the name of the PDF's file.
    public let fileName: String
}
