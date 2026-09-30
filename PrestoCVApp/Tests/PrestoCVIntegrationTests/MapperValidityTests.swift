import Testing
import PrestoCVDomain
import PrestoCVCoreTestSupport
import PrestoCVIntegration
import CVDocumentModel

/// R6 has two rules: "can be saved" is the authoring rule and "can be rendered" is the document's. These tests check that the
/// validator accepts the mapped fixture and the mapped CV that holds only a name. That every CV that can be saved maps to a
/// valid document does not hold yet; the last test records the gap (#124).
@Suite("Mapper validity (#88)")
struct MapperValidityTests {
    let mapper = CVToDocumentMapper()

    @Test("the document mapped from the fixture is valid")
    func fixtureIsValid() throws {
        try CVDocumentValidator.validate(mapper.map(FixtureCV.full(), language: try documentLanguage("it")))
    }

    @Test("the document mapped from a CV that holds only a name is valid")
    func nameOnlyIsValid() throws {
        let nameOnly = CV(id: SequentialIDGenerator().next(), personal: PersonalDetails(fullName: "Ada"))

        try CVDocumentValidator.validate(mapper.map(nameOnly, language: try documentLanguage("it")))
    }

    @Test("a saveable CV with a tab in a text maps to a document the validator refuses (#124)")
    func saveableWithTab() throws {
        let tabbed = CV(id: SequentialIDGenerator().next(), personal: PersonalDetails(fullName: "Ada", summary: "Builds\tsoftware."))
        let document = mapper.map(tabbed, language: try documentLanguage("it"))

        #expect(tabbed.canBeSaved)
        withKnownIssue("A saveable CV can hold text the document validator refuses: #124") {
            try CVDocumentValidator.validate(document)
        }
    }
}
