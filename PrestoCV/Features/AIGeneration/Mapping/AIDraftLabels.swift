import Foundation

/// The localised words the mapper writes into a CV.
///
/// They are injected, not looked up, so the mapper stays pure: tests pass their own words, and the
/// app builds these from the string catalog in one place.
struct AIDraftLabels: Equatable {
    /// End of a current job's period, e.g. "Present"
    let present: String
}
