internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// What the person chose to start the first CV: the argument of `FirstRunViewModel.start(_:)`.
public enum StartChoice: Hashable, Sendable {
    case example(ExampleChoice)
    /// The person's own CV: the screen turns it into the import flow.
    case importCV
    case blank
}

/// What the start screen shows, in order: `FirstRunViewModel.entries`. Blank is always the last entry.
public enum StartEntry: Hashable, Sendable, Identifiable {
    /// The person's own CV, offered when the app has an import flow.
    case importCV
    /// One entry that opens the examples, which the person then picks from.
    case examples([ExampleChoice])
    /// Why the examples are missing, shown where their entry would be.
    case examplesIssue(ExamplesIssue)
    case blank

    /// One identity per kind of entry, so the screen can list them.
    public var id: String {
        switch self {
        case .importCV: "import"
        case .examples: "examples"
        case .examplesIssue: "examples.issue"
        case .blank: "blank"
        }
    }
}

/// An example CV the person can start from. Its title and summary are the example's own text.
public struct ExampleChoice: Hashable, Sendable {
    public let title: String
    /// The example's own summary, which tells two examples apart.
    public let summary: String
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
