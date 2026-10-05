import PrestoCVApplication
import PrestoCVDomain

/// Sample CVs from memory, for the use cases that start from a sample.
public struct InMemorySampleCVSource: SampleCVSource {
    private let cvs: [CV]

    /// - Parameter cvs: The samples, in the order they are offered.
    public init(_ cvs: [CV]) { self.cvs = cvs }

    /// The samples given at creation.
    public func samples() async throws(RepositoryError) -> [CV] { cvs }
}
