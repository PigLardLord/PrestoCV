/// What VoiceOver is still to tell of the editor's changes, in one announcement: one posted while another is spoken cuts it
/// short. The view tells the status's words first, then each problem's note, and reports it told with
/// `EditorViewModel.announcementWasTold(_:)`.
public struct EditorAnnouncement: Equatable, Sendable {
    /// Where the status settled, or nil when it has not moved since the last announcement the view told.
    public let status: SaveStatus?
    /// The problems met since the last announcement the view told that still hold and that the status does not name, in
    /// the order of the form.
    public let problems: [FieldProblem]
    /// Makes the same words, told and met again, a new value, so that the view tells them again.
    let serial: Int
}

extension EditorViewModel {

    /// Adds a change to what VoiceOver is still to tell: `status` takes the place of the status waiting, `met` joins the
    /// problems waiting. The announcement is made again from all that waits, so that a change made before the view told
    /// the one before it is not lost: the view reads the value once per update, and two changes in one turn reach it as
    /// one.
    func tell(status: SaveStatus?, problems met: Set<FieldProblem> = []) {
        guard status != nil || !met.isEmpty else { return }
        if let status { statusToTell = status }
        problemsToTell.formUnion(met)
        remakeAnnouncement()
    }

    /// Takes back what waits to be told and no longer holds, once a problem is gone (the person fixed it, or its row
    /// went) before the view told it: its note, and the status that names its field when no problem met is left there.
    /// The status that takes its place, if any, is told by the save status that settles after the change.
    func withdrawWhatNoLongerHolds() {
        guard announcement != nil else { return }
        let held = problemsToTell.intersection(metProblems)
        let statusHolds = if case .unreadable(let field)? = statusToTell {
            metProblems.contains { $0.field == field }
        } else {
            true
        }
        guard held != problemsToTell || !statusHolds else { return }
        problemsToTell = held
        if !statusHolds { statusToTell = nil }
        remakeAnnouncement()
    }

    /// The view told `told`: what it held waits no more. A report of an older one changes nothing, so that what came after
    /// it is still told.
    public func announcementWasTold(_ told: EditorAnnouncement) {
        guard announcement?.serial == told.serial else { return }
        announcement = nil
        statusToTell = nil
        problemsToTell = []
    }

    /// Makes the announcement from what waits: nil when nothing does.
    private func remakeAnnouncement() {
        let shown = problems
        // The status names the first problem in general words; its note would tell it a second time
        let named = shown.first.flatMap { statusToTell == .unreadable($0.field) ? $0 : nil }
        let notes = shown.filter { problemsToTell.contains($0) && $0 != named }
        guard statusToTell != nil || !notes.isEmpty else {
            announcement = nil
            return
        }
        announcements += 1
        announcement = EditorAnnouncement(status: statusToTell, problems: notes, serial: announcements)
    }
}
