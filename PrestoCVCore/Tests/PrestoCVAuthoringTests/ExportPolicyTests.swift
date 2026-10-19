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

    @Test("a CV is exported only once it has the name and the e-mail of its person; white space is not a value",
          arguments: [("Ada Lovelace", "ada@example.com", nil), ("", "ada@example.com", ExportBlocker.missingNameOrEmail),
                      ("Ada Lovelace", " ", .missingNameOrEmail), (" \n", "", .missingNameOrEmail)] as [(String, String, ExportBlocker?)])
    func blocker(name: String, email: String, blocker: ExportBlocker?) {
        #expect(ExportPolicy.standard.blocker(name: name, email: email) == blocker)
    }
}
