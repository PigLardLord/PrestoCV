import Foundation

/// The localised words the mapper writes into a CV.
///
/// They are injected, not looked up, so the mapper stays pure: tests pass their own words, and the
/// app builds these from the string catalog in one place.
struct AIDraftLabels: Equatable {
    /// End of a current job's period, e.g. "Present"
    let present: String
    /// Name of a CV drafted without the person's name, e.g. "New CV"
    let untitled: String
    /// Format of a CV's name from the person's name, e.g. "CV of %@"
    let cvNameFormat: String

    func cvName(for personName: String?) -> String {
        guard let name = personName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return untitled
        }
        return String(format: cvNameFormat, name)
    }
}
