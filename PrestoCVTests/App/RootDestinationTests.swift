import Testing
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - RootDestination Tests

@Suite("RootDestination Tests - the CV list is always the root")
struct RootDestinationTests {

    @Test("A first-time user lands on the CV list, whose empty state welcomes them")
    func firstTimeUserLandsOnList() {
        #expect(RootDestination.resolve(.firstTime) == .list)
    }

    @Test("A returning user lands on the CV list")
    func returningUserLandsOnList() {
        #expect(RootDestination.resolve(.returning) == .list)
    }

    @Test("While the state is being checked the root shows loading")
    func loadingStateShowsLoading() {
        #expect(RootDestination.resolve(.loading) == .loading)
    }

    @Test("An error state shows the message of the error")
    func errorStateShowsTheRealMessage() {
        let error = AppError.unknown("disk full")

        let destination = RootDestination.resolve(.error(error))

        #expect(destination == .error(message: error.localizedDescription))
        guard case .error(let message) = destination else {
            Issue.record("Expected an error destination")
            return
        }
        #expect(message.contains("disk full"), "The message must say what went wrong")
    }
}
