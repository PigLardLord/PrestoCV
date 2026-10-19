import Testing
import PrestoCVDomain

@Suite("Version 1's export policy")
struct ExportPolicyTests {
    @Test("a CV is printed on A4, with a margin of 43 points on every side, on at most 10 pages")
    func page() {
        let policy = ExportPolicy.standard
        #expect(policy.pageWidth == 595.28 && policy.pageHeight == 841.89)
        #expect(policy.margin == 43 && policy.maxPages == 10)
    }
}
