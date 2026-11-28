import PrestoCVIntegration
@testable import PrestoCVComposition

extension DesignBootstrap {
    /// Runs the check as the app does, through `CheckedDesigns`, and gives the designs once it is over.
    func checked() async -> CheckedDesigns {
        let designs = CheckedDesigns(checking: self, defaultDesign: Self.defaultDesign)
        designs.start()
        for await status in designs.changes({ $0.status }) where status != .checking { break }
        return designs
    }
}
