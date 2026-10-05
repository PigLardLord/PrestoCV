import Testing
import Foundation
import PrestoCVDomain
@testable import PrestoCVApplication
import PrestoCVCoreTestSupport

private typealias Translation = (failure: RepositoryError, translated: AuthoringError)

/// The failures of a port, each mapped to `.unavailable`.
private func unavailable(_ failures: [RepositoryError]) -> [Translation] { failures.map { ($0, AuthoringError.unavailable) } }

/// What reading a stored file can fail with, whichever operation reads it.
private let readFailures: [RepositoryError] = [.corrupt(file: "f"), .unreadable(file: "f"), .upgradeRequired(file: "f", version: 2),
                                                .tooLarge(file: "f"), .storeUnavailable(.cannotList)]

/// Every case of `RepositoryError`, with the one `AuthoringError` it becomes.
private let allTranslations: [Translation] = {
    var cases: [Translation] = [(.conflict(id1, storedRevision: 7), .conflict(storedRevision: 7)), (.notFound(id1), .deletedElsewhere),
                                (.wouldNotReadBack(file: "f"), .tooLarge)]
    cases += unavailable([.alreadyExists(id1), .invalidName("f"), .writeFailed(file: "f")])
    cases += unavailable(readFailures)
    return cases
}()

private let createFailures: [Translation] = {
    var cases = unavailable([.alreadyExists(id1), .writeFailed(file: "f"), .storeUnavailable(.cannotLock)] + readFailures)
    cases.append((.wouldNotReadBack(file: "f"), .tooLarge))
    return cases
}()

private let updateFailures: [Translation] = {
    var cases = unavailable([.writeFailed(file: "f"), .storeUnavailable(.cannotLock)] + readFailures)
    cases.append((.notFound(id1), .deletedElsewhere))
    cases.append((.conflict(id1, storedRevision: 7), .conflict(storedRevision: 7)))
    cases.append((.wouldNotReadBack(file: "f"), .tooLarge))
    return cases
}()

private let loadFailures: [Translation] = {
    var cases = unavailable(readFailures)
    cases.append((.notFound(id1), .deletedElsewhere))
    return cases
}()

private let listFailures = unavailable([.storeUnavailable(.notADirectory), .storeUnavailable(.cannotList), .storeUnavailable(.cannotLock)])

private let deleteFailures: [Translation] = {
    var cases = unavailable([.writeFailed(file: "f"), .storeUnavailable(.cannotLock)] + readFailures)
    cases.append((.notFound(id1), .deletedElsewhere))
    cases.append((.conflict(id1, storedRevision: 7), .conflict(storedRevision: 7)))
    return cases
}()

private let sampleFailures = unavailable([.unreadable(file: "f"), .upgradeRequired(file: "f", version: 2), .corrupt(file: "f"),
                                          .tooLarge(file: "f"), .storeUnavailable(.cannotList)])

@Suite("CleanErrors · translation for presentation")
struct ErrorTranslationTests {
    private let stored = named("Ada").stored(revision: 1, at: Date(timeIntervalSince1970: 0))

    @Test("every repository error has exactly one translation", arguments: allTranslations)
    func table(failure: RepositoryError, translated: AuthoringError) {
        #expect(AuthoringError(failure) == translated)
    }

    @Test("saving a CV that was never saved reports what a create can fail with", arguments: createFailures)
    func create(failure: RepositoryError, translated: AuthoringError) async {
        await #expect(throws: translated) { _ = try await SaveCV(repository: FailingRepository(failure: failure))(named("Ada")) }
    }

    @Test("saving a stored CV reports what an update can fail with", arguments: updateFailures)
    func update(failure: RepositoryError, translated: AuthoringError) async {
        await #expect(throws: translated) { _ = try await SaveCV(repository: FailingRepository(failure: failure))(stored) }
    }

    @Test("loading a CV reports what a load can fail with", arguments: loadFailures)
    func load(failure: RepositoryError, translated: AuthoringError) async {
        await #expect(throws: translated) { _ = try await LoadCV(repository: FailingRepository(failure: failure))(id1) }
    }

    @Test("listing reports what a listing can fail with", arguments: listFailures)
    func list(failure: RepositoryError, translated: AuthoringError) async {
        await #expect(throws: translated) { _ = try await ListCVs(repository: FailingRepository(failure: failure))() }
    }

    @Test("deleting a CV reports what a delete can fail with", arguments: deleteFailures)
    func delete(failure: RepositoryError, translated: AuthoringError) async {
        await #expect(throws: translated) { try await DeleteCV(repository: FailingRepository(failure: failure))(stored) }
    }

    @Test("offering the samples reports what a sample source can fail with", arguments: sampleFailures)
    func samples(failure: RepositoryError, translated: AuthoringError) async {
        let useCase = StartFromSample(samples: FailingSampleCVSource(failure: failure), ids: SequentialIDGenerator())
        await #expect(throws: translated) { _ = try await useCase.available() }
    }
}
