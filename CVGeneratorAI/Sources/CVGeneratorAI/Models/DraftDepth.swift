import Foundation

/// How much a draft writes, by the model on the device (#354, probe round 3): the model of iOS 27 and macOS 27 answers the longer
/// requests of a rich draft within the request's time; the one of iOS 26 stopped the draft at the time limit, so it keeps the
/// shorter requests.
enum DraftDepth {
    /// Whether the device's model writes the rich draft: more duties, tools and summary sentences.
    static var isRich: Bool {
        if #available(iOS 27, macOS 27, *) { return true }
        return false
    }
}
