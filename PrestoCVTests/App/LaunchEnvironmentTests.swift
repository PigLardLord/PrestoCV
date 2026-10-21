import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

@Suite("LaunchEnvironment Tests - the app as the host of the unit tests, and what a UI test may ask of it")
struct LaunchEnvironmentTests {

    @Test("The app is a bare host for the unit tests only when its launch asks for it")
    func hostsUnitTestsOnlyWhenAsked() {
        #expect(LaunchEnvironment.hostsUnitTests(arguments: ["PrestoCV", LaunchEnvironment.unitTestHostArgument]))
        #expect(!LaunchEnvironment.hostsUnitTests(arguments: ["PrestoCV"]))
    }

    @Test("The test plans launch the host that way, so it composes nothing beside the tests")
    func theseTestsRunInABareHost() {
        #expect(
            LaunchEnvironment.hostsUnitTests(arguments: ProcessInfo.processInfo.arguments),
            "The test plan should pass \(LaunchEnvironment.unitTestHostArgument) to the app"
        )
    }

    @Test("A UI test can make the first writes of a CV fail, as on a full disk; the writes after them are stored")
    func firstWritesFailWhenAsked() async throws {
        let store = MockCVManagementUseCase()
        let cvs = LaunchEnvironment.cvs(store, arguments: ["PrestoCV", LaunchEnvironment.failingWritesArgument, "2"])
        let cv = CVModel(personalInfo: PersonalInfo(name: "Marta Rinaldi"))

        await #expect(throws: CocoaError.self) { _ = try await cvs.storeNewCV(cv) }
        await #expect(throws: CocoaError.self) { _ = try await cvs.updateCV(cv) }
        _ = try await cvs.storeNewCV(cv)

        #expect(try await cvs.getCV(by: cv.id) == cv)
        #expect(await store.createCVCallCount == 1, "The failed writes never reach the store")
    }

    @Test("Without the request, or with a count that is not a number above zero, the CVs are the ones given")
    func noWriteFailsUnlessAsked() {
        let store = MockCVManagementUseCase()
        for arguments in [["PrestoCV"], ["PrestoCV", LaunchEnvironment.failingWritesArgument], ["PrestoCV", LaunchEnvironment.failingWritesArgument, "0"]] {
            #expect(LaunchEnvironment.cvs(store, arguments: arguments) as? MockCVManagementUseCase === store, "\(arguments)")
        }
    }
}
