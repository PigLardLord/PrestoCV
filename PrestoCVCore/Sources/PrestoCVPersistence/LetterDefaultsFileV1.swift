import Foundation
import PrestoCVDomain

/// The three texts of the letter defaults in schema 1, without an envelope: what `LetterDefaultsFileV1` and the provenance
/// of `ApplicationFileV1` both write, so the bounds exist once, in `LetterDefaults` (R6, R12).
struct LetterDefaultsContentV1: Codable, Equatable {
    let salaryExpectation: String, startDate: String, note: String

    init(_ defaults: LetterDefaults) {
        salaryExpectation = defaults.salaryExpectation; startDate = defaults.startDate; note = defaults.note
    }

    /// A stored text is exactly what the domain produces from it: trimmed and within its bound. A text that is not is corrupt,
    /// never normalised on read.
    func toDomain() throws(FileInvalid) -> LetterDefaults {
        let defaults: LetterDefaults
        do { defaults = try LetterDefaults(salaryExpectation: salaryExpectation, startDate: startDate, note: note) }
        catch { throw FileInvalid(reason: "letter defaults: \(error)") }
        guard LetterDefaultsContentV1(defaults) == self else { throw FileInvalid(reason: "letter defaults are not canonical") }
        return defaults
    }
}
