import Observation
internal import PrestoCVApplication
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// The first run: whether the store holds anything, and the ways to start. A choice gives a draft that nothing has stored,
/// or the import, which another view model runs.
@MainActor
@Observable
public final class FirstRunViewModel {

    public private(set) var state: FirstRunState = .loading
    /// Why there are no examples, nil when they were read.
    public private(set) var examplesIssue: ExamplesIssue?

    /// The ways to start: the examples, then the import, then blank.
    public var choices: [StartChoice] { examples.map(StartChoice.example) + [.importCV, .blank] }

    private var examples: [ExampleChoice] = []
    @ObservationIgnored private var samples: [CVID: CV] = [:]
    @ObservationIgnored private var examplesRead = false
    @ObservationIgnored private let browsing: any CVBrowsing
    @ObservationIgnored private let editing: any CVEditing

    public init(browsing: any CVBrowsing, editing: any CVEditing) {
        self.browsing = browsing
        self.editing = editing
    }

    /// Reads the store and, once, the examples. The view calls it from its `.task`.
    public func load() async {
        do {
            switch try await browsing.onboarding() {
            case .firstRun: state = .firstRun
            case .returning: state = .returning
            }
        } catch {
            if !Task.isCancelled { state = .failed }
        }
        guard !examplesRead else { return }
        do {
            let read = try await browsing.samples()
            samples = Dictionary(read.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            examples = read.map { ExampleChoice(title: CVTitle(name: $0.title, person: "", role: $0.personal.professionalTitle).text(untitled: ""), id: $0.id) }
            examplesIssue = nil
            examplesRead = true
        } catch {
            if !Task.isCancelled { examplesIssue = ExamplesIssue(error) }
        }
    }

    /// Where a choice leads. Nothing is stored: the editor stores the draft the first time it writes it.
    public func start(_ choice: StartChoice) -> StartDestination? {
        switch choice {
        case .blank:
            return .draft(CVDraft(cv: editing.new()))
        case .importCV:
            return .importCV
        case .example(let example):
            return samples[example.id].map { .draft(CVDraft(cv: browsing.startFromSample($0))) }
        }
    }
}
