import Testing
import Foundation
import CVDocumentModel
import CVRenderingTestSupport

private func strings(_ values: [JSON?]) -> [String] {
    values.compactMap { if case .string(let text)? = $0 { text } else { nil } }
}

/// The paths of the optional properties that are nil anywhere in `value`.
private func unsetOptionals(in value: Any, at path: String = "") -> [String] {
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
        guard let wrapped = mirror.children.first else { return [path] }
        return unsetOptionals(in: wrapped.value, at: path)
    }
    return mirror.children.flatMap { unsetOptionals(in: $0.value, at: path + "." + ($0.label ?? "[]")) }
}

@Suite("ADR 0002 · the JSON Schema and the CVDocument model agree")
struct CVDocumentSchemaTests {
    struct Fixture: Sendable, CustomTestStringConvertible {
        let name: String, document: CVDocument
        var testDescription: String { name }
    }

    static let fixtures: [Fixture] = {
        var all: [Fixture] = []
        all.append(Fixture(name: "the contract fixture of the renderers", document: ContractFixture.document))
        all.append(Fixture(name: "every section kind, period end and level, every optional field present", document: ModelSamples.populated))
        all.append(Fixture(name: "required fields only", document: ModelSamples.minimal))
        all.append(Fixture(name: "the smallest and the largest ratings, years and months", document: ModelSamples.limits))
        all.append(Fixture(name: "no sections", document: ModelSamples.withoutSections))
        return all
    }()

    @Test("a document the encoder writes validates against the schema and against the validator", arguments: fixtures)
    func roundTrip(fixture: Fixture) throws {
        let data = try JSONEncoder().encode(fixture.document)
        #expect(try CommittedSchema.validator().violations(of: JSON(parsing: data)) == [])
        #expect(try CVDocumentValidator.decode(json: data) == fixture.document)
    }

    @Test("the schema and the exporter give the same verdict", arguments: DocumentCases.all)
    func verdict(documentCase: DocumentCase) throws {
        let violations = try CommittedSchema.validator().violations(of: JSON(parsing: documentCase.json))
        let exporter = Exporter.verdict(for: documentCase.json)
        let (schemaShouldAccept, exporterShouldAccept) = switch documentCase.agreement {
        case .valid: (true, true)
        case .invalid: (false, false)
        case .beyondSchema: (true, false)
        }
        #expect(violations.isEmpty == schemaShouldAccept, "the schema should \(schemaShouldAccept ? "accept" : "refuse") it: \(violations)")
        #expect((exporter == .accepted) == exporterShouldAccept, "the exporter should \(exporterShouldAccept ? "accept" : "refuse") it: \(exporter)")
    }

    @Test("the populated sample sets every optional field of the model")
    func populatedSample() {
        #expect(unsetOptionals(in: ModelSamples.populated) == [])
    }

    @Test("the schema declares exactly the properties the model writes")
    func properties() throws {
        let written = try JSON(parsing: JSONEncoder().encode(ModelSamples.populated))
        #expect(try CommittedSchema.validator().propertyDifferences(of: written) == [])
    }

    @Test("the section kinds of the schema are the ones the encoder writes")
    func sectionKinds() throws {
        let schema = try CommittedSchema.validator()
        guard case .array(let alternatives)? = schema.definition("section")?["oneOf"] else { throw SchemaShapeError(what: "section is not a oneOf") }
        let declared = strings(alternatives.map { schema.resolve($0)?["properties"]?["kind"]?["const"] })
        let written = try strings(ModelSamples.sections.map { try JSON(parsing: JSONEncoder().encode($0))["kind"] })
        #expect(declared.sorted() == written.sorted())
        #expect(Set(written).count == ModelSamples.sections.count)
    }

    @Test("the period ends of the schema are the ones the encoder writes")
    func periodEnds() throws {
        let written = try strings(ModelSamples.ends.map { end in
            try JSON(parsing: JSONEncoder().encode(DocumentPeriod(start: DocumentDate(year: 2000), end: end)))["end"]
        })
        guard case .array(let declared)? = try CommittedSchema.validator().definition("period")?["properties"]?["end"]?["enum"] else { throw SchemaShapeError(what: "end has no enum") }
        #expect(strings(declared).sorted() == written.sorted())
    }

    @Test("the language levels of the schema are the raw values of LanguageItem.Level")
    func levels() throws {
        guard case .array(let declared)? = try CommittedSchema.validator().definition("languageItem")?["properties"]?["level"]?["enum"] else { throw SchemaShapeError(what: "level has no enum") }
        #expect(strings(declared).sorted() == ModelSamples.levels.map(\.rawValue).sorted())
    }

    struct SchemaShapeError: Error { let what: String }
}
