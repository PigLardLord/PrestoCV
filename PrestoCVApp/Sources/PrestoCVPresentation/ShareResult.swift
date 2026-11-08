/// How the system's share sheet ended, as the platform tells it.
public enum ShareResult: Hashable, Sendable {
    /// The PDF was saved, to Files or elsewhere.
    case saved
    /// The PDF was sent, by mail, a message or another app.
    case sent
    /// The person closed the share sheet.
    case cancelled
}

/// A share that went through, which the sheet confirms.
public enum ShareOutcome: Hashable, Sendable {
    case saved
    case sent
}
