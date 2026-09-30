import Testing
import PrestoCVDomain
import PrestoCVCoreTestSupport
import PrestoCVIntegration
import CVDocumentModel

/// R6: "can be saved" is the authoring rule and "can be rendered" is the document's, and a CV that can be saved maps to a
/// document that passes the document's validator.
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
}
