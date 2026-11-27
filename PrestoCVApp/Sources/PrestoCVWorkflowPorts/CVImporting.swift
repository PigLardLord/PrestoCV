import Foundation
import PrestoCVDomain

// The import port and its value types (#393). Contents, layer and allowed imports: docs/architecture/modules.md.

/// What an import of a CV gives the person: a CV that is not saved yet, the values to check, and the text that fits
/// nowhere. The CV is the import's own words and nothing else (ADR 0027).
public struct ImportOutcome: Sendable, Equatable {
    /// A new CV: it has an id, revision 0 and nothing stored. Saving it is the caller's decision.
    public let cv: CV
    public let review: [ImportReviewItem]
    /// Whether the CV can be saved, and if not, why: the CV's own `saveCheck()` (R6). A CV that cannot be saved is
    /// returned all the same, since it is the person's text; this says why the screen cannot offer to save it.
    public let saving: SaveVerdict
    /// Text of the person's CV that is in no field, whole and ready to copy: the text the rules could not place, and the
    /// values the CV cannot hold.
    public let notImported: String
    public init(cv: CV, review: [ImportReviewItem], saving: SaveVerdict, notImported: String) {
        self.cv = cv; self.review = review; self.saving = saving; self.notImported = notImported
    }
}

/// A value of the new CV the person should check, with the text as the person wrote it. A code and a text of the
/// person's: the words of the screen belong to presentation (R13).
public struct ImportReviewItem: Sendable, Equatable {
    public let field: ImportReviewField
    public let reason: ImportReviewReason
    public let text: String
    public init(field: ImportReviewField, reason: ImportReviewReason, text: String) {
        self.field = field; self.reason = reason; self.text = text
    }
}

/// Where in the CV a value to check is. Entries are counted from one, as the person counts them on the screen.
public enum ImportReviewField: Sendable, Hashable {
    case name, title, location, summary
    case experience(Int)
    case experiencePeriod(Int)
    case education(Int)
    case educationPeriod(Int)
    case educationLocation(Int)
    /// The position in the returned CV's languages.
    case language(Int)
    /// The n-th language the text lists (from one, in the text's order), which the CV does not hold; its words are in the text not imported.
    case languageNotKept(Int)
    case certificationYear(Int)
    /// The position in the returned CV's certifications.
    case certification(Int)
}

/// Why a value should be checked.
public enum ImportReviewReason: String, Sendable, Hashable, CaseIterable {
    case nameByPosition, titleByPosition, locationByPosition, summaryWithoutHeading
    case roleOrEmployerByOrder, entryBoundsUnsure
    /// A line in capitals in the entry may be a section heading the import does not know.
    case headingUnsure
    /// The dates could not be made a period, such as an end before the start.
    case periodUnreadable
    /// The period has no end; the CV does not call it current.
    case periodOpenEnd
    /// A single date is no period; the CV keeps none.
    case periodNotARange
    /// The language has a level in words that are no CEFR level, so the CV does not hold it.
    case levelNotCEFR
    /// The text gives the language different levels, so the CV does not hold it.
    case levelsDiffer
    /// The text states no level for the language, so the CV does not hold it.
    case levelMissing
    /// The CV's education has no place; the text's place is kept in the text not imported.
    case locationNotKept
    /// The certification's year is no year the CV can hold.
    case yearUnreadable
    /// A line may be the certification's description or a certification of its own.
    case descriptionOrEntryUnsure
}

/// Why an import gave no CV.
public enum ImportFailure: Error, Equatable, Sendable {
    /// No text at all.
    case empty
    case tooLarge
    case tooManyPages
    case encrypted
    /// The text or document cannot be read.
    case unreadable
    /// A document without a text layer.
    case noText
    /// The file the person chose could not be read, for a reason that is none of the above (`ImportFileReading`).
    case fileNotRead
}

/// Reads the CV a person already has into a new CV, from a text or from the bytes of a PDF. The failure is an
/// `ImportFailure`; a cancelled task stays a `CancellationError` (R3, R7).
public protocol CVImporting: Sendable {
    func importCV(fromText text: String) async throws -> ImportOutcome
    /// A PDF is read as a PDF, with the layout of its words, never as a text taken out of it first (ADR 0027).
    func importCV(fromPDF data: Data) async throws -> ImportOutcome
}
