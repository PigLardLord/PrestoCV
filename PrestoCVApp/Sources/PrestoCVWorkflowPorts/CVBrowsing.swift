import PrestoCVDomain
import PrestoCVApplication

/// What the list of CVs and the first run need.
public protocol CVBrowsing: Sendable {
    /// The CVs, most recently changed first, with every file the store could not read during the launch, one issue per file.
    func list() async throws(EditFailure) -> CVListing
    func onboarding() async throws(EditFailure) -> OnboardingState
    func samples() async throws(EditFailure) -> [CV]
    /// An unsaved copy of the sample under a new identity.
    func startFromSample(_ sample: CV) -> CV
}
