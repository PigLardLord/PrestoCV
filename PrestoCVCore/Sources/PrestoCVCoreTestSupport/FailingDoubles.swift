import PrestoCVApplication
import PrestoCVDomain

/// A repository whose every operation fails with `failure`, to test how a use case reports a failure of its port.
public struct FailingRepository: CVRepository {
    public let failure: RepositoryError

    /// - Parameter failure: The error every operation throws.
    public init(failure: RepositoryError) { self.failure = failure }

    /// Always fails with `failure`.
    public func create(_ cv: CV) async throws(RepositoryError) -> CV { throw failure }
    /// Always fails with `failure`.
    public func update(_ cv: CV) async throws(RepositoryError) -> CV { throw failure }
    /// Always fails with `failure`.
    public func load(_ id: CVID) async throws(RepositoryError) -> CV { throw failure }
    /// Always fails with `failure`.
    public func list() async throws(RepositoryError) -> CVListing { throw failure }
    /// Always fails with `failure`.
    public func delete(_ id: CVID, revision: Int) async throws(RepositoryError) { throw failure }
}

/// A sample source that fails with `failure`.
public struct FailingSampleCVSource: SampleCVSource {
    public let failure: RepositoryError

    /// - Parameter failure: The error `samples()` throws.
    public init(failure: RepositoryError) { self.failure = failure }

    /// Always fails with `failure`.
    public func samples() async throws(RepositoryError) -> [CV] { throw failure }
}
