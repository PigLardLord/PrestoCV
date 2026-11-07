import Testing
import Foundation
@testable import CVDocumentModel

/// `Docs/cv-document.schema.json` is the JSON Schema of `CVDocument`, schema version 1 (ADR 0002, #82). These tests hold
/// the schema and the type to each other in both directions: what the type encodes must validate, what the schema names
/// must be what the type has, and the bounds that both state must agree.
@Suite("cv-document.schema.json matches CVDocument (#82)")
struct DocumentSchemaTests {
    struct SchemaError: Error, CustomStringConvertible { let description: String }

    /// The schema, which the test target copies into its bundle.
    static func schema() throws -> JSONSchemaSubset {
        guard let url = Bundle.module.url(forResource: "cv-document.schema", withExtension: "json") else {
            throw SchemaError(description: "the test bundle has no cv-document.schema.json")
        }
        return JSONSchemaSubset(root: try JSONValue.parse(Data(contentsOf: url)))
    }

    static func definition(_ name: String) throws -> JSONValue {
        guard let found = try schema().root["$defs"]?[name] else { throw SchemaError(description: "the schema has no definition \(name)") }
        return found
    }

    func encoded(_ document: CVDocument) throws -> JSONValue { try JSONValue.parse(JSONEncoder().encode(document)) }

    func problems(_ document: CVDocument) throws -> [String] { try Self.schema().problems(try encoded(document)) }

    // MARK: Everything the type encodes is valid

    @Test("the documents the type encodes are valid", arguments: [SchemaSamples.minimal, SchemaSamples.full])
    func encodedDocumentsAreValid(document: CVDocument) throws {
        #expect(try problems(document) == [])
    }

    @Test("every section kind, period end and language level the type has is valid", arguments: SchemaSamples.Kind.allCases)
    func everyKindIsValid(kind: SchemaSamples.Kind) throws {
        let document = CVDocument(language: "en", person: Person(name: "Ada"), sections: [SchemaSamples.section(kind)])
        #expect(try problems(document) == [])
        #expect(try JSONDecoder().decode(CVDocument.self, from: JSONEncoder().encode(document)) == document)
    }

    @Test("every language level the type has is valid", arguments: LanguageItem.Level.allCases)
    func everyLevelIsValid(level: LanguageItem.Level) throws {
        let document = CVDocument(language: "en", person: Person(name: "Ada"), sections: [.languages([LanguageItem(language: "x", level: level)])])
        #expect(try problems(document) == [])
    }

    @Test("every way a period can end is valid", arguments: [PeriodEnd.present, .unspecified, .date(DocumentDate(year: 2020)), .date(DocumentDate(year: 2020, month: 5))])
    func everyPeriodEndIsValid(end: PeriodEnd) throws {
        let period = DocumentPeriod(start: DocumentDate(year: 2019, month: 1), end: end)
        let document = CVDocument(language: "en", person: Person(name: "Ada"), sections: [.education([EducationItem(degree: "d", school: "s", period: period)])])
        #expect(try problems(document) == [])
    }

    // MARK: What the schema must refuse

    @Test("the schema refuses what is not a CV document", arguments: [
        #"{"language":"en","person":{"name":"A"},"sections":[]}"#,
        #"{"schemaVersion":2,"language":"en","person":{"name":"A"},"sections":[]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[],"extra":1}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A","age":3},"sections":[]}"#,
        #"{"schemaVersion":1,"language":"en","person":{},"sections":[]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[{"kind":"hobbies","items":[]}]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[{"kind":"summary","items":["x"]}]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[{"kind":"skills","items":[{"name":"x","rating":9}]}]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[{"kind":"skills","items":[{"name":"x","rating":0}]}]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[{"kind":"languages","items":[{"language":"x","level":"d1"}]}]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[{"kind":"education","items":[{"degree":"d","school":"s","period":{"start":{"year":2020,"month":13},"end":"present"}}]}]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[{"kind":"education","items":[{"degree":"d","school":"s","period":{"start":{"year":2020},"end":"date"}}]}]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[{"kind":"education","items":[{"degree":"d","school":"s","period":{"start":{"year":2020},"end":"present","endDate":{"year":2021}}}]}]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[{"kind":"education","items":[{"degree":"d","school":"s","period":{"start":{"year":2020},"end":"someday"}}]}]}"#,
        #"{"schemaVersion":1,"language":"en","person":{"name":"A"},"sections":[{"kind":"certifications","items":[{"name":"n","issuer":"i","year":"2021"}]}]}"#,
    ])
    func refusals(json: String) throws {
        #expect(try !Self.schema().problems(JSONValue.parse(Data(json.utf8))).isEmpty)
    }

    // MARK: The schema names what the type has

    /// The names a type has: its stored properties, which a `Mirror` lists even when the value is nil, plus the keys of
    /// its encoded samples (a key the encoding adds, such as a period's `endDate`).
    func names(of value: Any, encodedAs samples: [JSONValue] = []) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label)).union(samples.flatMap(\.keys))
    }

    func declared(_ definition: String) throws -> Set<String> { try Self.definition(definition)["properties"]?.keys ?? [] }

    @Test("the person has the properties of the schema, no more and no fewer")
    func personProperties() throws {
        #expect(names(of: SchemaSamples.person) == (try declared("person")))
    }

    @Test("the document has the properties of the schema, no more and no fewer")
    func documentProperties() throws {
        let sample = try encoded(SchemaSamples.full)
        #expect(names(of: SchemaSamples.full, encodedAs: [sample]) == (try Self.schema().root["properties"]?.keys ?? []))
        #expect(Set(sample.keys) == (try Self.schema().root["properties"]?.keys ?? []))
    }

    @Test("each item type has the properties of its schema definition, no more and no fewer")
    func itemProperties() throws {
        #expect(names(of: SchemaSamples.experience) == (try declared("experienceItem")))
        #expect(names(of: SchemaSamples.education) == (try declared("educationItem")))
        #expect(names(of: SchemaSamples.skill) == (try declared("skillItem")))
        #expect(names(of: SchemaSamples.language) == (try declared("languageItem")))
        #expect(names(of: SchemaSamples.certification) == (try declared("certificationItem")))
        #expect(names(of: SchemaSamples.profile) == (try declared("profileLink")))
        #expect(names(of: DocumentDate(year: 2020, month: 1)) == (try declared("date")))
    }

    @Test("a period has the properties of the schema, with the end date its encoding adds")
    func periodProperties() throws {
        let ends: [PeriodEnd] = [.present, .unspecified, .date(DocumentDate(year: 2020))]
        let samples = try ends.map { try JSONValue.parse(JSONEncoder().encode(DocumentPeriod(start: DocumentDate(year: 2019), end: $0))) }
        let period = DocumentPeriod(start: DocumentDate(year: 2019), end: .present)
        #expect(names(of: period, encodedAs: samples) == (try declared("period")))
    }

    @Test("the schema allows the section kinds the type has and no others")
    func sectionKinds() throws {
        let alternatives = try Self.definition("section")["oneOf"]
        let schemaKinds = Set((alternatives?.arrayValue ?? []).compactMap { alternative -> String? in
            if case .string(let kind)? = alternative["properties"]?["kind"]?["const"] { return kind } else { return nil }
        })
        let typeKinds = Set(try SchemaSamples.Kind.allCases.map { kind -> String in
            let key = try JSONValue.parse(JSONEncoder().encode(SchemaSamples.section(kind)))["kind"]
            guard case .string(let name)? = key else { throw SchemaError(description: "a section without a kind") }
            return name
        })
        #expect(schemaKinds == typeKinds)
        #expect(alternatives?.arrayValue?.count == typeKinds.count)
    }

    @Test("the schema allows the language levels the type has and no others")
    func languageLevels() throws {
        let levels = try Self.definition("languageItem")["properties"]?["level"]?["enum"]?.strings ?? []
        #expect(Set(levels) == Set(LanguageItem.Level.allCases.map(\.rawValue)))
        #expect(levels.count == LanguageItem.Level.allCases.count)
    }

    @Test("the schema version is the one the type writes")
    func version() throws {
        #expect(try Self.schema().root["properties"]?["schemaVersion"]?["const"]?.integerValue == CVDocument.currentSchemaVersion)
    }

    // MARK: The bounds agree with the validator

    func validatorAccepts(_ document: CVDocument) -> Bool {
        do { try CVDocumentValidator.validate(document); return true } catch { return false }
    }

    @Test("the years the schema allows are the years the validator accepts")
    func yearBounds() throws {
        let year = try Self.definition("date")["properties"]?["year"]
        let low = try #require(year?["minimum"]?.integerValue), high = try #require(year?["maximum"]?.integerValue)
        func document(_ y: Int) -> CVDocument {
            CVDocument(language: "en", person: Person(name: "A"), sections: [.education([EducationItem(degree: "d", school: "s", period: DocumentPeriod(start: DocumentDate(year: y), end: .present))])])
        }
        for (y, valid) in [(low - 1, false), (low, true), (high, true), (high + 1, false)] {
            #expect(validatorAccepts(document(y)) == valid, "validator, year \(y)")
            #expect((try problems(document(y))).isEmpty == valid, "schema, year \(y)")
        }
    }

    @Test("the ratings the schema allows are the ratings the validator accepts")
    func ratingBounds() throws {
        let rating = try Self.definition("skillItem")["properties"]?["rating"]
        let low = try #require(rating?["minimum"]?.integerValue), high = try #require(rating?["maximum"]?.integerValue)
        for (r, valid) in [(low - 1, false), (low, true), (high, true), (high + 1, false)] {
            let document = CVDocument(language: "en", person: Person(name: "A"), sections: [.skills([SkillItem(name: "x", rating: r)])])
            #expect(validatorAccepts(document) == valid, "validator, rating \(r)")
            #expect((try problems(document)).isEmpty == valid, "schema, rating \(r)")
        }
    }

    @Test("the months the schema allows are the months the validator accepts")
    func monthBounds() throws {
        let month = try Self.definition("date")["properties"]?["month"]
        let low = try #require(month?["minimum"]?.integerValue), high = try #require(month?["maximum"]?.integerValue)
        for (m, valid) in [(low - 1, false), (low, true), (high, true), (high + 1, false)] {
            let document = CVDocument(language: "en", person: Person(name: "A"), sections: [.education([EducationItem(degree: "d", school: "s", period: DocumentPeriod(start: DocumentDate(year: 2020, month: m), end: .present))])])
            #expect(validatorAccepts(document) == valid, "validator, month \(m)")
            #expect((try problems(document)).isEmpty == valid, "schema, month \(m)")
        }
    }

    @Test("the number of entries the schema allows is the number the validator accepts")
    func itemCountBounds() throws {
        let limit = CVDocumentValidator.maxItems
        let sections = try #require(try Self.schema().root["properties"]?["sections"]?["maxItems"]?.integerValue)
        #expect(sections == limit)
        for kind in SchemaSamples.Kind.allCases {
            let items = SchemaSamples.section(kind, count: limit + 1)
            guard let items else { continue }
            let over = CVDocument(language: "en", person: Person(name: "A"), sections: [items])
            #expect(!validatorAccepts(over), "validator, \(kind)")
            #expect(try !problems(over).isEmpty, "schema, \(kind)")
            let atLimit = CVDocument(language: "en", person: Person(name: "A"), sections: [SchemaSamples.section(kind, count: limit) ?? items])
            #expect(validatorAccepts(atLimit), "validator, \(kind) at the limit")
            #expect(try problems(atLimit).isEmpty, "schema, \(kind) at the limit")
        }
    }
}
