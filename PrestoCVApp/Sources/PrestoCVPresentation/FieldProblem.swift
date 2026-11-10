/// A field whose text the person should look at, as a code the view words beside the field (R13). The editor names it
/// only once the person has left the field or tried to store, and drops it as soon as it no longer holds (#33).
public struct FieldProblem: Hashable, Sendable {
    /// What is wrong with the text.
    public enum Code: Hashable, Sendable {
        /// The text cannot be read as its kind (an e-mail address, a phone number, a web address, a period). The rest
        /// of the CV is stored; this field is not.
        case unreadable
        /// The end of a period comes before its start. The rest of the CV is stored; this period is not.
        case endBeforeStart
    }

    /// The row the field is on, or nil for a field of the details.
    public let row: RowID?
    public let field: EditorField
    public let code: Code
}

extension EditorViewModel {

    /// The problems the person has met, in the form's order: of the fields they left, and of every field when they last
    /// tried to store. A problem goes as soon as it no longer holds.
    public var problems: [FieldProblem] {
        guard !metProblems.isEmpty else { return [] }
        return form.unreadable.filter(metProblems.contains)
    }

    /// The problem of a field that the person has met, which its note names: of the details, or of the row with `row`; nil
    /// when the field shows no note.
    public func problem(of field: EditorField, row: RowID? = nil) -> FieldProblem.Code? {
        problems.first { $0.row == row && $0.field == field }?.code
    }

    /// The person left a field of the details, or of the row with `row`: what keeps it from being stored is a problem
    /// from now on, until it no longer holds.
    public func fieldWasLeft(_ field: EditorField, row: RowID? = nil) {
        meet(form.unreadable.filter { $0.row == row && $0.field == field })
    }

    /// The person tried to store: every field that cannot be stored is a problem from now on, until it can.
    func meetEveryProblem() {
        meet(form.unreadable)
    }

    /// Forgets the problems that no longer hold, so that a new one in their field waits until the field is left again.
    func forgetProblemsThatRead() {
        guard !metProblems.isEmpty else { return }
        let kept = metProblems.intersection(form.unreadable)
        if kept != metProblems { metProblems = kept }
    }

    /// Makes `problems` met, and tells each one met now once (`announcement`): the first by the status when the status
    /// changes to it, every other one by its note, in the same announcement.
    private func meet(_ problems: [FieldProblem]) {
        let added = Set(problems).subtracting(metProblems)
        guard !added.isEmpty else { return }
        metProblems.formUnion(added)
        tell(status: settleSaveStatus(), problems: added)
    }
}
