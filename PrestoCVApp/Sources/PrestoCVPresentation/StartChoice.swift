internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// A way to start the first CV. Blank is always the last of the choices.
public enum StartChoice: Hashable, Sendable {
    case example(ExampleChoice)
    /// The person's own CV: the screen turns it into the import flow.
    case importCV
    case blank
}

/// An example CV the person can start from. Its text is the example's own.
public struct ExampleChoice: Hashable, Sendable {
    public let title: String
    let id: CVID
}

/// Where a choice leads: a draft for the editor, or the import flow, which this view model does not run.
public enum StartDestination: Sendable {
    case draft(CVDraft)
    case importCV
}

public enum FirstRunState: Hashable, Sendable {
    case loading
    /// The store holds nothing at all: no CV and no file with an issue.
    case firstRun
    case returning
    /// The store could not be read.
    case failed
}

/// Why the examples are missing.
public enum ExamplesIssue: Hashable, Sendable {
    case unavailable
    case failed
}

extension ExamplesIssue {
    init(_ failure: EditFailure) {
        switch failure {
        case .unavailable: self = .unavailable
        case .conflict, .deletedElsewhere, .tooLarge, .notEnoughContent, .textTooLong, .tooManyEntries, .cvTooLarge:
            self = .failed
        }
    }
}
