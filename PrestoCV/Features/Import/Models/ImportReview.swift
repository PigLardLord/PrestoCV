import Foundation

/// What the editor shows above a CV imported from the person's text: the values to check, and the text that was not
/// imported, by where it stood in the CV, ready to copy (ADR 0027). It holds codes and the person's own text; the views
/// word the codes. It is kept with the CV until the person dismisses it, so it is `Codable`.
struct ImportReview: Hashable, Sendable, Codable {

    /// A value to check, where it is, and why.
    struct Item: Hashable, Sendable, Codable {
        enum Field: Hashable, Sendable, Codable {
            case name, title, location, summary
            /// An experience entry, counted from one as the editor lists it.
            case experience(Int)
            case education(Int)
            case language
        }

        enum Reason: Hashable, Sendable, Codable {
            /// Taken from where it stands, with no label or mark that says what it is.
            case byPosition
            /// Nothing told the role from the employer, or the degree from the school.
            case partsByOrder
            /// The lines next to the entry's dates may be the entry's beside it: the more common layout decided.
            case entryBounds
            /// A date that could not be read as a period, or a period with no end.
            case period
            /// A language whose level the text gives in words, or not at all: the CV needs a level, so it was not added.
            case languageNotAdded
            /// A Europass grid that gives a language several levels.
            case languageLevels
        }

        let field: Field
        let reason: Reason
        /// The value as the text states it.
        let text: String

        var fieldKey: String {
            switch field {
            case .name: return "import.review.field.name"
            case .title: return "import.review.field.title"
            case .location: return "import.review.field.location"
            case .summary: return "import.review.field.summary"
            case .experience: return "import.review.field.experience"
            case .education: return "import.review.field.education"
            case .language: return "import.review.field.language"
            }
        }

        var reasonKey: String {
            switch reason {
            case .byPosition: return "import.review.reason.position"
            case .partsByOrder: return "import.review.reason.order"
            case .entryBounds: return "import.review.reason.bounds"
            case .period: return "import.review.reason.period"
            case .languageNotAdded: return "import.review.reason.language"
            case .languageLevels: return "import.review.reason.levels"
            }
        }
    }

    /// Text that fits no field, with where it stood in the CV.
    struct Passage: Hashable, Sendable, Codable {
        enum Place: Hashable, Sendable, Codable {
            /// The top of the CV, before its first heading: the name, the headline and the contact lines.
            case top
            /// The section under this heading, as the CV writes it.
            case section(String)
            /// A place the CV gives no heading for.
            case elsewhere
        }

        let place: Place
        /// The text, one piece per line, as the person wrote it.
        let text: String
        /// The CV has no field for the section, so its text was left out with its heading.
        let isWholeSection: Bool

        /// The key of the header the review shows above the passage; a section's names its heading (`heading`).
        var headerKey: String {
            switch place {
            case .top: return "import.review.place.top"
            case .section: return "import.review.place.section"
            case .elsewhere: return "import.review.not_imported_title"
            }
        }

        /// The heading of the section the passage stood in, as the CV writes it; nil outside a section.
        var heading: String? {
            guard case .section(let heading) = place else { return nil }
            return heading
        }
    }

    let items: [Item]
    /// The text that fits no field, in the order of the CV.
    let passages: [Passage]

    init(items: [Item], passages: [Passage]) {
        self.items = items
        self.passages = passages
    }

    /// A review whose text not imported has no place: one passage, or none when the text is empty.
    init(items: [Item], notImported: String) {
        self.init(items: items, passages: notImported.isEmpty ? [] : [Passage(place: .elsewhere, text: notImported, isWholeSection: false)])
    }

    /// The text that fits no field, one piece per line, as the person wrote it.
    var notImported: String { passages.map(\.text).joined(separator: "\n") }

    /// The headings of the sections left out whole, as the CV writes them.
    var sectionsNotImported: [String] {
        passages.compactMap { passage in
            guard passage.isWholeSection, case .section(let heading) = passage.place else { return nil }
            return heading
        }
    }

    var isEmpty: Bool { items.isEmpty && passages.isEmpty }
}
