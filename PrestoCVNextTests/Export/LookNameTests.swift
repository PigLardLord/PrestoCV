import SwiftUI
import Testing
@testable import PrestoCVNext

/// The names of the look picker's choices are looked up by the codes the app gives them (#407).
@Suite("Names of the look picker")
struct LookNameTests {

    @Test("Each code the app offers has its name, under the same key", arguments: [
        "design.minimal", "design.modern", "design.professional",
        "fonts.system", "fonts.serif", "fonts.rounded",
        "palette.ink", "palette.slate", "palette.ocean", "palette.plum"
    ])
    func eachCodeHasItsName(code: String) {
        #expect(LookName.named(code)?.key == code)
    }

    @Test("A code the app has no name for has none, so the item reads as kept")
    func anUnknownCodeHasNoName() {
        #expect(LookName.named("design.retro") == nil)
    }
}
