import PrestoCVDomain
import PrestoCVApplication
import PrestoCVWorkflowPorts

/// Listing the CVs and starting from a sample, on the use cases of the application layer.
public struct BrowseCVsWorkflow: CVBrowsing {
    private let repository: any CVRepository
    private let sampleSource: any SampleCVSource
    private let ids: any IDGenerator

    public init(repository: any CVRepository, samples: any SampleCVSource, ids: any IDGenerator) {
        self.repository = repository; sampleSource = samples; self.ids = ids
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
