import Testing
import Foundation
@testable import PrestoCV

@Suite("LaunchEnvironment Tests - the app as the host of the unit tests")
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
}
