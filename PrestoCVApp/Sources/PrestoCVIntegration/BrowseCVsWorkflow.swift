import PrestoCVDomain
import PrestoCVApplication
import PrestoCVWorkflowPorts

/// Listing the CVs and starting from a sample, on the use cases of the application layer. Each listing has every file the
/// store reported it could not read since the workflow was made, that is during the launch: the store reports a file once,
/// on the listing that sets it aside, and at launch that listing is the first-run screen's.
public struct BrowseCVsWorkflow: CVBrowsing {
    private let repository: any CVRepository
    private let sampleSource: any SampleCVSource
    private let ids: any IDGenerator

    public init(repository: any CVRepository, samples: any SampleCVSource, ids: any IDGenerator) {
        self.repository = LaunchIssues(store: repository); sampleSource = samples; self.ids = ids
    }

    public func list() async throws(EditFailure) -> CVListing {
        do { return try await ListCVs(repository: repository)() } catch { throw EditFailure(error) }
    }

    public func onboarding() async throws(EditFailure) -> OnboardingState {
        do { return try await DetermineOnboarding(repository: repository)() } catch { throw EditFailure(error) }
    }

    public func samples() async throws(EditFailure) -> [CV] {
        do { return try await StartFromSample(samples: sampleSource, ids: ids).available() } catch { throw EditFailure(error) }
    }

    public func startFromSample(_ sample: CV) -> CV { StartFromSample(samples: sampleSource, ids: ids)(sample) }
}

/// The store, with each listing giving every issue its listings reported since this was made, one per file: as the store
/// last reported it, where the store first met it. Copies of the workflow share it.
private actor LaunchIssues: CVRepository {
    private let store: any CVRepository
    private var reported: [StoreIssue] = []

    init(store: any CVRepository) { self.store = store }

    func list() async throws(RepositoryError) -> CVListing {
        let listing = try await store.list()
        for issue in listing.issues {
            if let index = reported.firstIndex(where: { $0.file == issue.file }) {
                reported[index] = issue
            } else {
                reported.append(issue)
            }
        }
        return CVListing(cvs: listing.cvs, issues: reported)
    }

    func create(_ cv: CV) async throws(RepositoryError) -> CV { try await store.create(cv) }
    func update(_ cv: CV) async throws(RepositoryError) -> CV { try await store.update(cv) }
    func load(_ id: CVID) async throws(RepositoryError) -> CV { try await store.load(id) }
    func delete(_ id: CVID, revision: Int) async throws(RepositoryError) { try await store.delete(id, revision: revision) }
}

private extension StoreIssue {
    /// The file the issue is about.
    var file: String {
        switch self {
        case .corrupt(let file, _), .upgradeRequired(let file, _), .unreadable(let file), .tooLarge(let file, _),
             .quarantineFailed(let file):
            file
        }
    }
}
