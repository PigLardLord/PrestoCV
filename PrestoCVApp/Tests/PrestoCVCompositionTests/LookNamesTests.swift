import CVBundledDesigns
import CVDesignCatalog
import CVRenderingTestSupport
import DiagnosticLoggingTestSupport
import Foundation
import PrestoCVIntegration
import Testing
@testable import PrestoCVComposition

/// The export sheet names each design, fonts and palette the launch offers by its code, a key of the new app's string
/// catalog (#407, the owner's D2). The launch's codes and the catalog's design, fonts and palette keys must be the
/// same set: a code without a key would show as the code itself, and a key without a code is a name nothing offers.
@Suite("The names of the look options")
struct LookNamesTests {
    private static let prefixes = ["design.", "fonts.", "palette."]

    @Test("The codes the launch offers are the catalog's design, fonts and palette keys")
    func codesAreTheCatalogKeys() async throws {
        let designs = await DesignBootstrap(
            store: InMemoryDesignStore(), source: BundleDesignSource(), gate: FakeRenderingGate(),
            logger: RecordingLogger(), clock: TickingClock(step: .milliseconds(5))
        ).checked()
        let options = CatalogLookOptions(designs: designs).options()
        let codes = (options.designs + options.palettes + options.fontSchemes).map(\.nameCode)

        let keys = try Self.catalogKeys().filter { key in Self.prefixes.contains(where: key.hasPrefix) }

        #expect(codes.count == designs.current.designs.count + NamedPalette.allCases.count + FontScheme.allCases.count)
        #expect(Set(codes).count == codes.count, "no two options share a code")
        #expect(codes.filter { !keys.contains($0) } == [], "codes without a name in the catalog")
        #expect(keys.filter { !codes.contains($0) }.sorted() == [], "names in the catalog that no option has")
    }

    /// The keys of the new app's string catalog, read from the source tree.
    private static func catalogKeys() throws -> Set<String> {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let data = try Data(contentsOf: root.appending(path: "PrestoCVNext/Resources/Localizable.xcstrings"))
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        return Set(strings.keys)
    }
}
