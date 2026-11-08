import PrestoCVDomain
import PrestoCVApplication

/// What the list of CVs and the first run need.
public protocol CVBrowsing: Sendable {
    /// The CVs, most recently changed first, with the files the store could not read.
    func list() async throws(EditFailure) -> CVListing
    func onboarding() async throws(EditFailure) -> OnboardingState
    func samples() async throws(EditFailure) -> [CV]
    /// An unsaved copy of the sample under a new identity.
    func startFromSample(_ sample: CV) -> CV
}
