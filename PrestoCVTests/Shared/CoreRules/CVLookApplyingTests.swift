import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
import struct PrestoCVApplication.LookChange
import struct PrestoCVDomain.DesignChoice

/// A change of the look sets the parts the person chose and leaves the others as the CV holds them.
@Suite("CVLook - applying a change")
struct CVLookApplyingTests {

    private let shown = DesignChoice(design: "modern", palette: "minimal", fonts: "serif")!

    private func change(_ parts: Set<LookChange.Part>) -> LookChange {
        LookChange(shown: shown, parts: parts)
    }

    @Test("Each part chosen is set from the look the sheet showed, and no other part changes",
          arguments: [
              (LookChange.Part.design, CVLook(design: "modern", palette: "neon", fonts: "handwritten")),
              (LookChange.Part.palette, CVLook(design: "future-design", palette: "minimal", fonts: "handwritten")),
              (LookChange.Part.fonts, CVLook(design: "future-design", palette: "neon", fonts: "serif")),
          ])
    func onlyTheChosenPartChanges(part: LookChange.Part, expected: CVLook) {
        let stored = CVLook(design: "future-design", palette: "neon", fonts: "handwritten")

        #expect(CVLook.applying(change([part]), to: stored) == expected)
    }

    @Test("Several parts chosen at once are all set")
    func severalPartsChange() {
        let stored = CVLook(design: "future-design", palette: "neon", fonts: "handwritten")

        #expect(CVLook.applying(change([.design, .fonts]), to: stored) == CVLook(design: "modern", palette: "neon", fonts: "serif"))
    }

    @Test("A part the look does not have yet stays missing unless it was chosen")
    func missingPartsStayMissing() {
        let stored = CVLook(design: "modern", palette: nil, fonts: nil)

        #expect(CVLook.applying(change([.fonts]), to: stored) == CVLook(design: "modern", palette: nil, fonts: "serif"))
    }

    @Test("A CV with no look takes the whole look the sheet showed, whichever part was chosen", arguments: LookChange.Part.allCases)
    func noLookTakesWhatWasShown(part: LookChange.Part) {
        #expect(CVLook.applying(change([part]), to: nil) == CVLook(design: "modern", palette: "minimal", fonts: "serif"))
    }

    @Test("A choice of what the CV holds already changes nothing")
    func sameChoiceChangesNothing() {
        let stored = CVLook(design: "modern", palette: "minimal", fonts: "serif")

        #expect(CVLook.applying(change([.design, .palette, .fonts]), to: stored) == stored)
    }
}
