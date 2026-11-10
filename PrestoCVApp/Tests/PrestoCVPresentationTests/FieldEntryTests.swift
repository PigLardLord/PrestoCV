import Testing
import PrestoCVPresentation

/// A field of one line takes no line break: its return key moves to the next field and leaves the text as it was, and a
/// break that comes with other text becomes a space. A paragraph keeps its breaks (#402, 5-11d).
@Suite("Field entry")
struct FieldEntryTests {

    @Test("the return key at the end, in the middle or in an empty field moves on and leaves the text as it was")
    func returnKeyMovesOn() {
        #expect(FieldEntry("Backend Engineer\n", after: "Backend Engineer", in: .title) == .returnKey(next: .fullName))
        #expect(
            FieldEntry("Backend\n Engineer", after: "Backend Engineer", in: .professionalTitle) == .returnKey(next: .email)
        )
        #expect(FieldEntry("\n", after: "", in: .website) == .returnKey(next: .summary))
    }

    @Test("the return key over a selection leaves the selected text in place")
    func returnKeyOverASelection() {
        #expect(FieldEntry("Mara\n", after: "Mara Ellison", in: .fullName) == .returnKey(next: .professionalTitle))
        #expect(FieldEntry("\n", after: "Mara Ellison", in: .fullName) == .returnKey(next: .professionalTitle))
        #expect(FieldEntry("Mara\nson", after: "Mara Ellison", in: .fullName) == .returnKey(next: .professionalTitle))
    }

    @Test(
        "every kind of line break the text rules know is the return key",
        arguments: ["\n", "\r", "\r\n", "\u{0B}", "\u{0C}", "\u{85}", "\u{2028}", "\u{2029}"]
    )
    func everyLineBreakIsTheReturnKey(_ lineBreak: String) {
        #expect(FieldEntry("Mara" + lineBreak, after: "Mara", in: .fullName) == .returnKey(next: .professionalTitle))
    }

    @Test("a text that comes with line breaks keeps its words, with a space for each break")
    func pastedBreaksBecomeSpaces() {
        #expect(FieldEntry("Mara\nEllison", after: "", in: .fullName) == .text("Mara Ellison"))
        #expect(FieldEntry("Mara\r\nEllison", after: "", in: .fullName) == .text("Mara Ellison"))
        #expect(FieldEntry("Lead\u{2028}Engineer\n", after: "", in: .professionalTitle) == .text("Lead Engineer "))
        #expect(FieldEntry("Mara Ellison\nmara", after: "Mara Ellison", in: .fullName) == .text("Mara Ellison mara"))
    }

    @Test("a break added with text that repeats the field's own is not the return key")
    func repeatedTextIsAPaste() {
        #expect(FieldEntry("Mara\nMara", after: "Mara", in: .fullName) == .text("Mara Mara"))
        #expect(FieldEntry("ab\nb", after: "ab", in: .location) == .text("ab b"))
    }

    @Test("typing and deleting keep the text as it is")
    func typingAndDeleting() {
        #expect(FieldEntry("Backend Engineer L", after: "Backend Engineer", in: .title) == .text("Backend Engineer L"))
        #expect(FieldEntry("Backend Enginee", after: "Backend Engineer", in: .title) == .text("Backend Enginee"))
        #expect(FieldEntry("", after: "Backend Engineer", in: .title) == .text(""))
    }

    @Test("the return key in a text that holds a break already, such as one stored before, moves on")
    func returnKeyAfterAStoredBreak() {
        #expect(
            FieldEntry("Mara\nEllison\n", after: "Mara\nEllison", in: .fullName) == .returnKey(next: .professionalTitle)
        )
    }

    @Test("a break stored before becomes a space at the next change that is not the return key")
    func aStoredBreakBecomesASpaceAtTheNextChange() {
        #expect(FieldEntry("Mara\nEllisonX", after: "Mara\nEllison", in: .fullName) == .text("Mara EllisonX"))
        #expect(FieldEntry("Mara\nEllison", after: "Mara\nEllison", in: .fullName) == .text("Mara Ellison"))
    }

    @Test("a paragraph keeps its line breaks", arguments: [EditorField.summary, .experienceDescription])
    func paragraphKeepsBreaks(_ field: EditorField) {
        #expect(FieldEntry("Line one\nLine two", after: "Line one", in: field) == .text("Line one\nLine two"))
        #expect(FieldEntry("Line one\n", after: "Line one", in: field) == .text("Line one\n"))
    }

    @Test("the return key in a field of a section ends the editing")
    func returnKeyInASectionEnds() {
        #expect(FieldEntry("Site manager\n", after: "Site manager", in: .experienceRole) == .returnKey(next: nil))
    }

    @Test("the return key goes through the details in the order the form shows them, and the summary is the last")
    func detailsOrder() {
        var visited: [EditorField] = []
        var next: EditorField? = .title
        while let field = next {
            visited.append(field)
            next = field.nextDetail
        }
        #expect(visited == Self.details)
    }

    @Test("a field of the sections has no next detail", arguments: EditorField.allCases.filter { !details.contains($0) })
    func sectionFieldHasNoNextDetail(_ field: EditorField) {
        #expect(field.nextDetail == nil)
    }

    static let details: [EditorField] = [.title, .fullName, .professionalTitle, .email, .phone, .location, .website, .summary]
}
