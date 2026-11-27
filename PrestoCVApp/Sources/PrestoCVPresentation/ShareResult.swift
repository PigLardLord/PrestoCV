/// How the system's share sheet ended, as the platform tells it.
public enum ShareResult: Hashable, Sendable {
    /// The PDF was saved to Files.
    case saved
    /// The PDF was sent by mail, by message or by AirDrop.
    case sent
    /// The share went through another way (print, copy, another app), which says nothing of where the PDF went.
    case other
    /// The person closed the share sheet.
    case cancelled
    /// The share could not go through: the platform reported an error, or the share sheet could not be shown.
    case failed

    /// The activity of the share sheet that saves to Files, by the name the system gives it.
    static let saveToFiles = "com.apple.DocumentManagerUICore.SaveToFiles"

    /// The activities of the share sheet that send the PDF to someone, by the names the system gives them.
    static let sends: Set<String> = [
        "com.apple.UIKit.activity.Mail", "com.apple.UIKit.activity.Message", "com.apple.UIKit.activity.AirDrop",
    ]

    /// The end of a share sheet as the platform reports it: the activity the person chose, when the platform names one,
    /// whether it went through, and whether it reported an error. Saving to Files is a save, and mail, a message and
    /// AirDrop are sends; any other activity that went through is `other`, as the sheet cannot tell what it did with
    /// the PDF, and a confirmation it cannot back is worse than none.
    public init(activity: String?, completed: Bool, failed: Bool) {
        if failed {
            self = .failed
        } else if !completed {
            self = .cancelled
        } else if activity == Self.saveToFiles {
            self = .saved
        } else if let activity, Self.sends.contains(activity) {
            self = .sent
        } else {
            self = .other
        }
    }
}

/// A share that went through, which the sheet confirms.
public enum ShareOutcome: Hashable, Sendable {
    case saved
    case sent
}

/// A share of the PDF that could not go through, which the sheet tells. Each failure is a new value, so that a second
/// failure in a row is told as well.
public struct ShareFailure: Hashable, Sendable {
    /// Which failure of the sheet this is, counted from one.
    let ordinal: Int
}
