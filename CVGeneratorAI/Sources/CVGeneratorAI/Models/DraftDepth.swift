import Foundation

/// How much a draft writes, by the model on the device (#354, probe round 3): the model of iOS 27 and macOS 27 answers the longer
/// requests of a rich draft within the request's time; the one of iOS 26 stopped the draft at the time limit, so it keeps the
/// shorter requests.
enum DraftDepth {
    /// The depth a test pins for the task it runs, with `$pinned.withValue`, whatever the OS that runs it; nil reads the device's
    /// model.
    @TaskLocal static var pinned: Bool?

    /// Whether the device's model writes the rich draft: more duties, tools and summary sentences.
    static var isRich: Bool {
        if let pinned { return pinned }
        if #available(iOS 27, macOS 27, *) { return true }
        return false
    }
}
