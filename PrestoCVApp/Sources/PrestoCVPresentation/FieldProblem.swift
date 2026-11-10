/// A field whose text the person should look at, as a code the view words beside the field (R13). The editor names it
/// only once the person has left the field or tried to store, and drops it as soon as the text reads (#33).
public struct FieldProblem: Hashable, Sendable {
    /// What is wrong with the text.
    public enum Code: Hashable, Sendable {
        /// The text cannot be read as its kind (an e-mail address, a phone number, a web address, a period). The rest
        /// of the CV is stored; this field is not.
        case unreadable
    }

    /// The row the field is on, or nil for a field of the details.
    public let row: RowID?
    public let field: EditorField
    public let code: Code
}

extension EditorViewModel {

    /// The problems the person has met, in the form's order: of the fields they left, and of every field when they last
    /// tried to store. A problem goes as soon as its text reads.
    public var problems: [FieldProblem] {
        guard !metProblems.isEmpty else { return [] }
        return form.unreadable.filter(metProblems.contains)
    }

    /// The problem of a field of the details that the person has met, which its note names; nil when the field shows no
    /// note.
    public func problem(of field: EditorField) -> FieldProblem.Code? {
        problems.first { $0.row == nil && $0.field == field }?.code
    }

    /// The person left a field of the details: text in it that cannot be read is a problem from now on, until it reads.
    public func fieldWasLeft(_ field: EditorField) {
        meet(form.unreadable.filter { $0.row == nil && $0.field == field })
    }

    /// The person tried to store: every field that cannot be read is a problem from now on, until it reads.
    func meetEveryProblem() {
        meet(form.unreadable)
    }

    /// Forgets the problems whose text reads now, so that text typed again in their field waits until it is left again.
    func forgetProblemsThatRead() {
        guard !metProblems.isEmpty else { return }
        let kept = metProblems.intersection(form.unreadable)
        if kept != metProblems { metProblems = kept }
    }

    private func meet(_ problems: [FieldProblem]) {
        let met = metProblems.union(problems)
        guard met != metProblems else { return }
        metProblems = met
        refreshSaveStatus()
    }
}
