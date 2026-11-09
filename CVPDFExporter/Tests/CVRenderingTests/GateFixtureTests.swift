import Testing
import CVDocumentModel
import CVRendering
import CVRenderingTestSupport

/// The kind of a section, by an exhaustive switch: a new kind of section stops this file from compiling until the test
/// names it, and the fixture must then use it.
private func kind(of section: Section) -> String {
    switch section {
    case .summary: "summary"
    case .experience: "experience"
    case .education: "education"
    case .skills: "skills"
    case .languages: "languages"
    case .certifications: "certifications"
    case .profiles: "profiles"
    case .interests: "interests"
    }
}

private let everyKind: Set<String> = ["summary", "experience", "education", "skills", "languages", "certifications", "profiles", "interests"]

@Suite("the gate fixture is the document the bundled designs were proven against")
struct GateFixtureTests {
    @Test("the gate fixture is the contract document, unchanged")
    func isTheContractDocument() {
        #expect(GateFixture.document == ContractFixture.document)
    }

    @Test("the gate fixture uses every kind of section")
    func usesEverySection() {
        #expect(Set(GateFixture.document.sections.map(kind(of:))) == everyKind)
    }

    @Test("the gate fixture is in Italian, the language its headings are read in")
    func italian() {
        #expect(GateFixture.document.language == "it")
    }
}
