import Testing
import PrestoCVPresentation

/// A text field can hand the same text over twice. The second hand-over of a pasted text with a line break comes against
/// the text the field kept, with a space for the break, and on its own it would read as the return key over that space:
/// the focus moved on to the next field (#478). A text handed over again, once, is one entry; the return key still moves
/// on each time it comes.
@Suite("Field entries")
struct FieldEntriesTests {
    private let pasted = "Payments platform.\nTeam of six."
    private let oneLine = "Payments platform. Team of six."

    @Test("a pasted text handed over twice keeps its words with a space and moves no focus")
    func pasteHandedOverTwice() {
        var entries = FieldEntries()

        #expect(entries.entry(pasted, after: "", in: .location) == .text(oneLine))
        #expect(entries.entry(pasted, after: oneLine, in: .location) == .text(oneLine))
    }

    @Test("the return key after a paste moves on")
    func returnKeyAfterAPaste() {
        var entries = FieldEntries()
        _ = entries.entry(pasted, after: "", in: .location)

        #expect(entries.entry(oneLine + "\n", after: oneLine, in: .location) == .returnKey(next: .website))
    }

    @Test("the return key moves on each time it comes, handed over twice or pressed again in the same field")
    func returnKeyEachTime() {
        var entries = FieldEntries()

        #expect(entries.entry("Leipzig\n", after: "Leipzig", in: .location) == .returnKey(next: .website))
        #expect(entries.entry("Leipzig\n", after: "Leipzig", in: .location) == .returnKey(next: .website))
    }

    @Test("the same paste after the text changed elsewhere is a new entry")
    func samePasteAfterAChangeElsewhere() {
        var entries = FieldEntries()
        _ = entries.entry(pasted, after: "", in: .location)

        // The form's text went back to empty without passing through the field, as when the stored text is read again
        #expect(entries.entry(pasted, after: "", in: .location) == .text(oneLine))
    }

    @Test("the same text a third time is the person's: the return key over the space the break became moves on")
    func memoryHoldsOneRepeat() {
        var entries = FieldEntries()
        _ = entries.entry(pasted, after: "", in: .location)
        _ = entries.entry(pasted, after: oneLine, in: .location)

        #expect(entries.entry(pasted, after: oneLine, in: .location) == .returnKey(next: .website))
    }

    @Test("a hand-over in another field between the two leaves the repeat one entry")
    func repeatAfterAnotherField() {
        var entries = FieldEntries()
        _ = entries.entry(pasted, after: "", in: .location)

        #expect(entries.entry(pasted, after: "", in: .professionalTitle) == .text(oneLine))
        #expect(entries.entry(pasted, after: oneLine, in: .location) == .text(oneLine))
    }

    @Test("each field has its own entries")
    func entriesPerField() {
        var entries = FieldEntries()
        _ = entries.entry(pasted, after: "", in: .location)

        #expect(entries.entry(pasted, after: oneLine, in: .professionalTitle) == .returnKey(next: .email))
    }

    @Test("a paragraph keeps its breaks: a text added after a paste, and the return key, each time")
    func paragraphKeepsItsBreaks() {
        var entries = FieldEntries()
        _ = entries.entry(pasted, after: "", in: .summary)

        #expect(entries.entry(pasted + " More.", after: pasted, in: .summary) == .text(pasted + " More."))
        #expect(entries.entry("x\n", after: "x", in: .summary) == .text("x\n"))
        #expect(entries.entry("x\n", after: "x", in: .summary) == .text("x\n"))
    }
}
