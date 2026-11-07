import Testing
import Foundation
import PrestoCVDomain
@testable import PrestoCVIntegration
import CVDocumentModel
import CVRendering

private typealias DomainLink = PrestoCVDomain.WebLink
private typealias PrintedLink = CVRendering.WebLink

@Suite("Links of the document")
struct DocumentLinksTests {
    /// Forms the domain accepts, with the odd ones: case, default ports, query, fragment, escapes, padding.
    private static let accepted = [
        "https://example.com", "http://example.com", "https://example.com/", "HTTPS://EXAMPLE.COM/Path", "http://example.com:80/a",
        "https://example.com:443/a?b=c&d=e#frag", "https://sub.example-site.co.uk/a%20b/c", " https://example.com/trim \n",
        "https://127.0.0.1/", "https://example.com?q=1", "https://example.com#top", "https://a.b.c.d.example/x/y/z?k=v%2Fw",
    ]

    @Test("every link the domain accepts is printed by the exporter as it is", arguments: accepted)
    func theTwoRulesAgree(raw: String) throws {
        let domain = try #require(DomainLink(raw))
        let printed = try #require(PrintedLink(domain.value), "the exporter refuses \(domain.value)")
        #expect(printed.url == domain.value)
    }

    @Test("a document whose links are all printable has no unprintable link")
    func printableLinks() throws {
        let doc = CVDocument(language: "it", person: Person(name: "Ada", website: "https://ada.example"), sections: [
            .certifications([CertificationItem(name: "A", issuer: "B", url: "https://cert.example/x")]),
            .profiles([CVDocumentModel.ProfileLink(platform: "Git", url: "https://github.com/ada")]),
        ])
        #expect(DocumentLinks.unprintable(in: doc).isEmpty)
    }

    @Test("a link the exporter would drop is reported, wherever it is", arguments: ["ftp://x.example", "https://user@x.example", "javascript:alert(1)", "https://x.example:8443", ""])
    func unprintableLinks(raw: String) {
        let doc = CVDocument(language: "it", person: Person(name: "Ada", website: raw), sections: [
            .certifications([CertificationItem(name: "A", issuer: "B", url: raw)]),
            .profiles([CVDocumentModel.ProfileLink(platform: "Git", url: raw)]),
        ])
        #expect(DocumentLinks.unprintable(in: doc) == [raw, raw, raw])
    }
}
