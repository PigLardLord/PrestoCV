#if DEBUG
import CVBundledDesigns
import CVDesignCatalog
import CVRenderingTestSupport
import DiagnosticLoggingTestSupport
import Foundation
import PrestoCVIntegration
import Testing
@testable import PrestoCVComposition

/// The gate of the UI tests that are not about the designs or the first launch: the real sync installs every bundled design
/// through it, and a launch reaches it only from its argument, over a folder of the fixture.
@Suite("The fixture that accepts the bundled designs without rendering them")
struct AcceptedDesignsTests {
    private static let program = "/path/to/PrestoCVNext"

    @Test("The real check, over the real bundled packages, offers the three designs through the accepted gate")
    func checkOffersTheBundledDesigns() async {
        let designs = await DesignBootstrap(
            store: InMemoryDesignStore(), source: BundleDesignSource(), gate: AcceptedDesigns(), logger: RecordingLogger(),
            clock: TickingClock(step: .milliseconds(5))
        ).checked().current

        #expect(designs.designs.map(\.manifest.id) == ["professional", "minimal", "modern"])
        #expect(designs.status == .ready)
    }

    @Test("The fixture checks the designs through the accepted gate only when its argument is given")
    func fixtureChoosesTheAcceptedGate() throws {
        let ready = try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage", LaunchFixtures.readyDesignsArgument])
        let plain = try LaunchFixtures.parse([Self.program, "-PrestoCVNextEmptyStorage"])

        #expect(ready.acceptsBundledDesigns)
        #expect(ready.unknownArguments.isEmpty)
        #expect(!plain.acceptsBundledDesigns)
        #expect(ready.designGate(FakeRenderingGate()) is AcceptedDesigns)
        #expect(plain.designGate(FakeRenderingGate()) is FakeRenderingGate)
    }

    @Test("The accepted gate needs a folder of the fixture, so the device's own design store never holds an unchecked design")
    func readyDesignsWithoutFolder() throws {
        #expect(throws: LaunchFixtures.Failure.readyDesignsWithoutFolder) {
            try LaunchFixtures.parse([Self.program, LaunchFixtures.readyDesignsArgument])
        }
        let named = try LaunchFixtures.parse([Self.program, "-PrestoCVNextStorage", "shared", LaunchFixtures.readyDesignsArgument])
        #expect(named.acceptsBundledDesigns)
    }
}
#endif
