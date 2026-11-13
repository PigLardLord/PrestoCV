import Foundation

/// What the editor shows above a CV imported from the person's text: the values to check, and the text that was not
/// imported, ready to copy (ADR 0027). It holds codes and the person's own text; the views word the codes.
struct ImportReview: Hashable, Sendable {

    /// A value to check, where it is, and why.
    struct Item: Hashable, Sendable {
        enum Field: Hashable, Sendable {
            case name, title, location, summary
            /// An experience entry, counted from one as the editor lists it.
            case experience(Int)
            case education(Int)
            case language
        }

        enum Reason: Hashable, Sendable {
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
            /// The place of a study: the CV has no field for it, so it is kept in the text not imported.
            case placeNotKept
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
            case .placeNotKept: return "import.review.reason.place"
            }
        }
    }

    let items: [Item]
    /// The text that fits no field, one piece per line, as the person wrote it.
    let notImported: String

    var isEmpty: Bool { items.isEmpty && notImported.isEmpty }
}
