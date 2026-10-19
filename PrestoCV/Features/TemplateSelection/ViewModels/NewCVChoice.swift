/// A way to start a new CV, as the first run and the "New CV" screen offer it.
enum NewCVChoice: Hashable {
    /// The person describes themselves and AI drafts the CV.
    case aiDraft
    /// The AI draft, dimmed: it cannot be made now, for the reason given.
    case aiDraftUnavailable(AIEntry.Reason)
    /// A blank CV.
    case blank
    /// One of the example CVs, with the details of its person left blank.
    case example
}
