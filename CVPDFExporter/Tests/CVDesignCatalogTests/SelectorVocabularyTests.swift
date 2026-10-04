import Testing
import Foundation
@testable import CVDesignCatalog

/// The CSS policy checks selectors against a vocabulary (ADR 0019): a design's is the markup contract's, and the cover
/// letter's built-in stylesheet has its own. The property allow-list is the same for both.
@Suite("ADR 0019 · the CSS policy takes a selector vocabulary")
struct SelectorVocabularyTests {
    /// What a second structure could be: two classes, one element, no attribute selectors, no pseudo-classes.
    static let note = SelectorVocabulary(name: "the note structure", elements: ["p", "span"], classes: ["note", "note-title"], sectionKinds: [], ratings: [], pseudoClasses: [])

    @Test("the CV's vocabulary is the markup contract, in every kind of selector")
    func cvIsTheMarkupContract() {
        let cv = SelectorVocabulary.cv
        #expect(cv.elements == MarkupContract.elements && cv.classes == MarkupContract.classes && cv.sectionKinds == MarkupContract.sectionKinds)
        #expect(cv.ratings == MarkupContract.ratings && cv.pseudoClasses == MarkupContract.pseudoClasses)
    }

    @Test("a stylesheet is checked against the vocabulary it is given: its classes pass, the CV's do not")
    func vocabularySelectsWhatIsAllowed() throws {
        let css = "p.note{color:var(--color-text)}.note-title{font-weight:700}span{font-size:9pt}"
        #expect(try ValidatedStylesheet.validating(css, against: Self.note).css == "p.note{color:var(--color-text)}.note-title{font-weight:700}span{font-size:9pt}")
        #expect(throws: CSSRejection.self) { _ = try ValidatedStylesheet.validating(".cv-name{color:var(--color-text)}", against: Self.note) }
        #expect(throws: CSSRejection.self) { _ = try ValidatedStylesheet.validating("h1{color:var(--color-text)}", against: Self.note) }
        #expect(throws: CSSRejection.self) { _ = try ValidatedStylesheet.validating(".note:first-child{color:var(--color-text)}", against: Self.note) }
        #expect(throws: CSSRejection.self) { _ = try ValidatedStylesheet.validating(#"[data-section="summary"]{color:var(--color-text)}"#, against: Self.note) }
        #expect(throws: CSSRejection.self) { _ = try ValidatedStylesheet.validating(".note[data-rating=\"3\"]{color:var(--color-text)}", against: Self.note) }
    }

    @Test("the CV's vocabulary is not loosened: a class of another structure is refused in a design, whatever else accepts it")
    func designsKeepTheirVocabulary() throws {
        _ = try ValidatedStylesheet.validating(".note{color:var(--color-text)}", against: Self.note)
        #expect(rejected(".note{color:var(--color-text)}"))
        #expect(rejected("p.note{color:var(--color-text)}"))
        #expect(throws: CSSRejection.self) { _ = try ValidatedStylesheet.validating(".note{color:var(--color-text)}", against: .cv) }
        _ = try DesignPackageValidator().validate(designData(".cv-name{color:var(--color-text)}"))
    }

    /// The reason of a rejection.
    func reason(_ css: String, against vocabulary: SelectorVocabulary) -> String? {
        do { _ = try ValidatedStylesheet.validating(css, against: vocabulary); return nil } catch { return error.reason }
    }

    @Test("a rejected selector names the vocabulary that refused it, whichever kind of selector it is", arguments: [
        "h5{color:var(--color-text)}", ".other{color:var(--color-text)}", #"[data-section="x"]{color:var(--color-text)}"#, ".note[data-rating=\"3\"]{color:var(--color-text)}",
        ".note:first-child{color:var(--color-text)}", "p.cv-name{color:var(--color-text)}",
    ])
    func rejectionsNameTheVocabulary(css: String) {
        let refusal = reason(css, against: Self.note)
        #expect(refusal?.contains("the note structure") == true, "\(css): \(refusal ?? "accepted")")
        #expect(refusal?.contains("markup contract") == false)
    }

    @Test("a design is refused in the words of the markup contract")
    func designsSayMarkupContract() {
        #expect(reason(".note{color:var(--color-text)}", against: .cv) == "class is not in the markup contract")
        #expect(reason("h5{color:var(--color-text)}", against: .cv) == "element h5 is not in the markup contract")
        #expect(reason(#"[data-section="x"]{color:var(--color-text)}"#, against: .cv) == "attribute selector is not in the markup contract")
        #expect(reason(".cv:hover{color:var(--color-text)}", against: .cv) == "pseudo-class is not in the markup contract, or it is a pseudo-element")
        do {
            _ = try DesignPackageValidator().validate(designData(".note{color:var(--color-text)}"))
            Issue.record("a design with a class outside the contract was accepted")
        } catch let rejected as DesignPackageRejected {
            #expect(rejected.violations == [.css("class is not in the markup contract")])
        } catch { Issue.record("\(error)") }
    }

    @Test("the property allow-list is the same whatever the vocabulary: nothing that loads, hides, moves or injects", arguments: [
        ".note{position:absolute}", ".note{color:red}", ".note{color:#000}", ".note{background:url(https://evil.example/a)}", ".note{display:none}",
        ".note{opacity:0}", ".note{font-size:0}", ".note{font-family:Arial}", ".note{color:var(--color-text) !important}", ".note{content:\"x\"}",
        ".note{display:flex}", ".note::before{color:var(--color-text)}", "#note{color:var(--color-text)}", "*{color:var(--color-text)}",
        "</style><script>x</script>", ".note{margin-top:100000px}", "@import url(x);", ".note{--h:none}", ".note{width:calc(1px)}",
    ])
    func sameAllowList(css: String) {
        #expect(throws: CSSRejection.self) { _ = try ValidatedStylesheet.validating(css, against: Self.note) }
    }

    @Test("a vocabulary with no attribute kinds refuses every attribute selector, and an empty one refuses every selector")
    func emptyKinds() {
        let none = SelectorVocabulary(name: "nothing", elements: [], classes: [], sectionKinds: [], ratings: [], pseudoClasses: [])
        for css in ["p{color:var(--color-text)}", ".cv{color:var(--color-text)}", ".note{color:var(--color-text)}"] {
            #expect(throws: CSSRejection.self) { _ = try ValidatedStylesheet.validating(css, against: none) }
        }
    }

    @Test("what is emitted is the canonical re-serialisation, whichever vocabulary")
    func canonical() throws {
        let css = "/* c */ .note , p.note-title { font-size : 9pt ; margin:0 0 4pt }  @media print { .note{ break-inside: avoid } }"
        #expect(try ValidatedStylesheet.validating(css, against: Self.note).css == ".note,p.note-title{font-size:9pt;margin:0 0 4pt}@media print{.note{break-inside:avoid}}")
    }
}
