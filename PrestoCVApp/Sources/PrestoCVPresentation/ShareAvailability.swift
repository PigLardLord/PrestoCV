/// Whether the export sheet's Share can be used now.
public enum ShareAvailability: Hashable, Sendable {
    /// The PDF is there and no file of a share is being written: a tap opens the share sheet.
    case ready
    /// An export runs, or the file of a share is being written: a tap does nothing yet.
    case preparing
    /// There is no PDF: the CV lacks something, the export failed, or the sheet has ended.
    case unavailable
}
