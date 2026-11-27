import SwiftUI
import Testing
@testable import PrestoCVNext

@Suite("ReadableMargins: a form's rows keep the readable width, centred in the space the safe area leaves")
struct ReadableMarginsTests {
    @Test("A space as wide as the readable width and a medium spacing on each side centres the rows in it", arguments: [
        // An iPad with the list beside the form: the scroll view reaches under the list
        (ReadableMargins(width: 712, leadingInset: 320, trailingInset: 0), [396, 76]),
        // The same iPad with the list hidden
        (ReadableMargins(width: 1032, leadingInset: 0, trailingInset: 0), [236, 236]),
        // An iPhone on its side, covered at both edges
        (ReadableMargins(width: 750, leadingInset: 62, trailingInset: 62), [157, 157]),
        // The narrowest such space: a medium spacing on each side
        (ReadableMargins(width: 592, leadingInset: 0, trailingInset: 0), [16, 16]),
    ] as [(ReadableMargins, [CGFloat?])])
    func centred(margins: ReadableMargins, expected: [CGFloat?]) {
        #expect([margins.leading, margins.trailing] == expected)
    }

    @Test("A narrower space keeps the system's margins", arguments: [
        // An iPhone upright
        ReadableMargins(width: 402, leadingInset: 0, trailingInset: 0),
        // One point under the narrowest centred space
        ReadableMargins(width: 591, leadingInset: 0, trailingInset: 0),
        // A space beside a list that is too narrow, though the whole width is not
        ReadableMargins(width: 580, leadingInset: 320, trailingInset: 0),
    ])
    func system(margins: ReadableMargins) {
        #expect(margins.leading == nil)
        #expect(margins.trailing == nil)
    }
}
