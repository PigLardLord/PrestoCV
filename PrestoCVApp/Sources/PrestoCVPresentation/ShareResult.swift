/// How the system's share sheet ended, as the platform tells it.
public enum ShareResult: Hashable, Sendable {
    /// The PDF was saved, to Files or elsewhere.
    case saved
    /// The PDF was sent, by mail, a message or another app.
    case sent
    /// The person closed the share sheet.
    case cancelled

    /// The activity of the share sheet that saves to Files, by the name the system gives it.
    static let saveToFiles = "com.apple.DocumentManagerUICore.SaveToFiles"

    /// The end of a share sheet as the platform reports it: the activity the person chose, when the platform names one,
    /// and whether it went through. Saving to Files is a save; any other activity that went through is a send.
    public init(activity: String?, completed: Bool) {
        if !completed {
            self = .cancelled
        } else if activity == Self.saveToFiles {
            self = .saved
        } else {
            self = .sent
        }
    }
}

/// A share that went through, which the sheet confirms.
public enum ShareOutcome: Hashable, Sendable {
    case saved
    case sent
}
