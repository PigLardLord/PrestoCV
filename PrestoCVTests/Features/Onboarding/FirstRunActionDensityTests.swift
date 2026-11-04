import Testing
import SwiftUI
@testable import PrestoCV

@Suite("FirstRunActionDensity Tests - the ways to start fit a short screen at the accessibility sizes")
struct FirstRunActionDensityTests {

    private let accessibilitySizes: [DynamicTypeSize] = [
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5,
    ]
    private let regularSizes: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
    ]

    @Test("At the regular sizes the ways to start keep their room and their symbols")
    func regularSizesKeepTheRoomAndTheSymbols() {
        for size in regularSizes {
            let density = FirstRunActionDensity.resolve(dynamicTypeSize: size)
            #expect(density == .regular, "\(size)")
            #expect(density.spacing == DesignTokens.Spacing.lg, "\(size)")
            #expect(density.symbol("sparkles") == "sparkles", "\(size)")
        }
    }

    @Test("At an accessibility size the ways to start sit closer together and leave their titles the whole width")
    func accessibilitySizesSetTheWaysToStartClose() {
        for size in accessibilitySizes {
            let density = FirstRunActionDensity.resolve(dynamicTypeSize: size)
            #expect(density == .compact, "\(size)")
            #expect(density.spacing < FirstRunActionDensity.regular.spacing, "\(size)")
            #expect(density.symbol("sparkles") == nil, "\(size)")
        }
    }

    @Test("The line under the dimmed AI draft stops growing at the first accessibility size")
    func theReasonLineStopsGrowingAtTheFirstAccessibilitySize() {
        #expect(FirstRunActionDensity.largestReasonLineSize == .accessibility1)
    }
}
