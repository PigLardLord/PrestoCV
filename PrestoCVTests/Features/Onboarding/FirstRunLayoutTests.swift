import Testing
import SwiftUI
@testable import PrestoCV

@Suite("FirstRunLayout Tests - the ways to start stay within reach of the first screen")
struct FirstRunLayoutTests {

    private let accessibilitySizes: [DynamicTypeSize] = [
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5,
    ]
    private let regularSizes: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
    ]

    @Test("At the regular sizes in portrait the welcome comes first and the ways to start follow it")
    func regularSizesLeadWithTheWelcome() {
        for size in regularSizes {
            #expect(FirstRunLayout.resolve(dynamicTypeSize: size, verticalSizeClass: .regular) == .welcomeFirst, "\(size)")
        }
    }

    @Test("At an accessibility size the ways to start come first, where the welcome alone would fill the screen")
    func accessibilitySizesLeadWithTheActions() {
        for size in accessibilitySizes {
            #expect(FirstRunLayout.resolve(dynamicTypeSize: size, verticalSizeClass: .regular) == .actionsFirst, "\(size)")
        }
    }

    @Test("In landscape on an iPhone the ways to start come first, whatever the text size")
    func compactHeightLeadsWithTheActions() {
        for size in regularSizes + accessibilitySizes {
            #expect(FirstRunLayout.resolve(dynamicTypeSize: size, verticalSizeClass: .compact) == .actionsFirst, "\(size)")
        }
    }

    @Test("A size class that is not known yet leads with the welcome at the regular sizes")
    func unknownSizeClassLeadsWithTheWelcome() {
        #expect(FirstRunLayout.resolve(dynamicTypeSize: .large, verticalSizeClass: nil) == .welcomeFirst)
        #expect(FirstRunLayout.resolve(dynamicTypeSize: .accessibility5, verticalSizeClass: nil) == .actionsFirst)
    }
}
