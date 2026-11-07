import Foundation

/// What VoiceOver is told when the description goes over the limit. Each crossing is an event of its own: going back under the
/// limit and over it again is announced again, which the state "over the limit" would not do, because the words did not change.
struct OverLimitAnnouncement: Equatable {
    let text: String
    /// Tells two crossings apart.
    let sequence: Int
}
