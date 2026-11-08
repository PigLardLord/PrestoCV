#if canImport(PDFKit)   // Apple platforms only (R11)
import Testing
import CVRenderingNativeTestSupport

@Suite("#78 · the annotations match the links")
struct AnnotationDestinationsTests {
    @Test("one annotation per link matches, in any order")
    func oneEach() {
        #expect(AnnotationDestinations.match(found: ["https://b.example/", "https://a.example/"],
                                             expected: ["https://a.example/", "https://b.example/"]))
    }

    @Test("two annotations for one link do not match")
    func duplicate() {
        #expect(!AnnotationDestinations.match(found: ["https://a.example/", "https://a.example/", "https://b.example/"],
                                              expected: ["https://a.example/", "https://b.example/"]))
    }

    @Test("a link with no annotation does not match")
    func missing() {
        #expect(!AnnotationDestinations.match(found: ["https://a.example/"], expected: ["https://a.example/", "https://b.example/"]))
    }

    @Test("two links to one destination need two annotations")
    func sameDestinationTwice() {
        #expect(AnnotationDestinations.match(found: ["https://a.example/", "https://a.example/"],
                                             expected: ["https://a.example/", "https://a.example/"]))
        #expect(!AnnotationDestinations.match(found: ["https://a.example/"], expected: ["https://a.example/", "https://a.example/"]))
    }
}
#endif
