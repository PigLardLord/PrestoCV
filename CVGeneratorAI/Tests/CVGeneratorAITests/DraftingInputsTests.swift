import Testing
import Foundation

// The inputs of the drafting evaluation (#202) are fixtures: these tests keep them honest, so that a fact the counter looks
// for is one the description states, a trap is a real temptation, and no input holds real contact details.

@Suite("Drafting inputs: the 37 descriptions of the drafting evaluation")
struct DraftingInputsTests {
    @Test("Each language has its example, a plain description, one with traps, a sparse one, one with no role and one with four jobs",
          arguments: DraftingInputs.languages)
    func sixInputsPerLanguage(_ language: String) throws {
        let inputs = try DraftingInputs.all().filter { $0.language == language && $0.kind != .app }

        #expect(inputs.map(\.kind) == [.example, .plain, .traps, .sparse, .noRole, .jobs])
        #expect(inputs.map(\.id) == ["example-", "-plain", "-traps", "-sparse", "-norole", "jobs-"].map {
            $0.hasPrefix("-") ? language + $0 : $0 + language
        })
    }

    @Test("There are 37 inputs, each with an id of its own, one of them from the app's end-to-end campaign")
    func thirtySevenInputs() throws {
        let ids = try DraftingInputs.all().map(\.id)

        #expect(ids.count == 37)
        #expect(DraftingInputs.app.map(\.id) == ["ai-language-data"])
        #expect(Set(ids).count == ids.count)
    }

    @Test("Every input with a role has a field and words of other trades its description does not state; one with no role has none",
          arguments: DraftingInputs.languages)
    func fieldsAndOffField(_ language: String) throws {
        for input in try DraftingInputs.all() where input.language == language {
            guard input.kind != .noRole else {
                #expect(input.field == nil && input.offField.isEmpty, "\(input.id)")
                continue
            }
            #expect(input.field?.isEmpty == false, "\(input.id)")
            #expect(input.offField.count >= 4, "\(input.id)")
            for word in input.offField {
                #expect(!input.states(word), "\(input.id): \(word)")
            }
        }
    }

    @Test("Each expected fact and each trap occurs in its description", arguments: DraftingInputs.languages)
    func factsAndTrapsOccur(_ language: String) throws {
        for input in try DraftingInputs.all() where input.language == language {
            for fact in input.facts {
                #expect(!fact.forms.isEmpty, "\(input.id): \(fact)")
                for form in fact.forms {
                    #expect(input.states(form), "\(input.id): \(form)")
                }
            }
            for trap in input.traps {
                #expect(input.states(trap), "\(input.id): \(trap)")
            }
        }
    }

    @Test("A phrase is stated only as whole words that follow each other", arguments: StatedCase.all)
    func statesWholeWords(_ item: StatedCase) {
        #expect(item.input.states(item.phrase) == item.stated, "\(item)")
    }

    @Test("Every full input states a name, a title and two employers; the descriptions with traps have nine traps",
          arguments: DraftingInputs.languages)
    func factsOfEveryInput(_ language: String) throws {
        for input in try DraftingInputs.all() where input.language == language && input.kind != .jobs {
            let kinds = input.facts.map(\.kind)
            guard input.kind != .sparse, input.kind != .noRole, input.kind != .app else {
                // A sparse description states a title alone, one with no role states no fact, and the app's states an employer
                // and a tool.
                let expected: [ExpectedFact.Kind] = switch input.kind {
                case .sparse: [.title]
                case .app: [.employer, .skill]
                default: []
                }
                #expect(kinds == expected, "\(input.id)")
                #expect(input.traps.isEmpty, "\(input.id)")
                continue
            }
            #expect(kinds.filter { $0 == .name }.count == 1, "\(input.id)")
            #expect(kinds.filter { $0 == .title }.count == 1, "\(input.id)")
            #expect(kinds.filter { $0 == .employer }.count == 2, "\(input.id)")
            #expect(kinds.filter { $0 == .school }.count == 1, "\(input.id)")
            #expect(kinds.filter { $0 == .language }.count == 2, "\(input.id)")
            #expect(input.traps.count == (input.kind == .traps ? 9 : 0), "\(input.id)")
        }
    }

    @Test("A description with four jobs states no name, three titles and four employers, and the job the person looks for is its one trap",
          arguments: DraftingInputs.languages)
    func factsOfFourJobs(_ language: String) throws {
        let input = try #require(try DraftingInputs.all().first { $0.language == language && $0.kind == .jobs })
        let kinds = input.facts.map(\.kind)

        #expect(input.id == "jobs-\(language)")
        #expect(!kinds.contains(.name) && !kinds.contains(.school) && !kinds.contains(.language), "\(input.id)")
        #expect(kinds.filter { $0 == .title }.count == 3, "\(input.id)")
        #expect(kinds.filter { $0 == .employer }.count == 4, "\(input.id)")
        #expect(input.traps.count == 1, "\(input.id)")
        #expect(input.description.split(separator: "\n").count == 8, "\(input.id)")
    }

    @Test("No trap is a phrase of an expected fact, so a kept fact never counts as a trap",
          arguments: DraftingInputs.languages)
    func trapsAreNotFacts(_ language: String) throws {
        func words(_ text: String) -> [String] {
            text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        }
        for input in try DraftingInputs.all() where input.language == language {
            for trap in input.traps.map(words) {
                for form in input.facts.flatMap(\.forms).map(words) where form.count >= trap.count {
                    let holdsTrap = (0...(form.count - trap.count)).contains { Array(form[$0..<($0 + trap.count)]) == trap }
                    #expect(!holdsTrap, "\(input.id): \(trap) in \(form)")
                }
            }
        }
    }

    @Test("The examples are the app's, read from its string catalog in every language it has")
    func examplesAreTheCatalogs() throws {
        let data = try Data(contentsOf: SourceTree.root.appendingPathComponent("PrestoCV/Localizable.xcstrings"))
        let catalog = try JSONDecoder().decode(Catalog.self, from: data)
        let example = try #require(catalog.strings["ai.generation.example_text"])
        let examples = try DraftingInputs.examples()

        let localizations = try #require(example.localizations)
        #expect(Set(localizations.keys) == Set(DraftingInputs.languages))
        #expect(examples.count == 6)
        for input in examples {
            #expect(input.kind == .example)
            #expect(input.description == localizations[input.language]?.stringUnit?.value, "\(input.id)")
            #expect(input.facts.first { $0.kind == .name }?.forms == ["Maria Rossi"], "\(input.id)")
        }
    }

    @Test("No input holds an email outside example.com or a phone number outside the invented +39 333 style",
          arguments: DraftingInputs.languages)
    func contactDetailsAreInvented(_ language: String) throws {
        for input in try DraftingInputs.all() where input.language == language {
            for email in input.description.matches(of: /[\w.+-]+@[\w-]+(\.[\w-]+)+/) {
                #expect(email.output.0.hasSuffix("@example.com"), "\(input.id): \(email.output.0)")
            }
            for phone in input.description.matches(of: /\+?\d[\d ]{5,}\d/) {
                #expect(phone.output.hasPrefix("+39 333 "), "\(input.id): \(phone.output)")
            }
            for link in input.description.matches(of: /(https?:\/\/|www\.)\S+/) {
                Issue.record("\(input.id): a link \(link.output.0)")
            }
        }
    }

    // MARK: - The language detector

    @Test("The copy of the app's language detector tells the language of every input", arguments: DraftingInputs.languages)
    func detectorTellsEveryInputsLanguage(_ language: String) throws {
        for input in try DraftingInputs.all() where input.language == language {
            #expect(AppLanguageDetector.languageTag(of: input.description) == language, "\(input.id)")
        }
    }

    @Test("The copy of the language detector has the app's lines")
    func detectorCopyHasTheAppsLines() throws {
        let app = try Self.codeLines(of: "PrestoCV/Features/AIGeneration/Mapping/DescriptionLanguageDetector.swift")
        let copy = try Self.codeLines(of: "CVGeneratorAI/Tests/CVGeneratorAITests/Support/AppLanguageDetector.swift")

        #expect(app.count == 7)
        #expect(copy == app)
    }

    /// The lines from `minimumConfidence` to the returned tag, trimmed, without blank lines or comments.
    private static func codeLines(of path: String) throws -> [String] {
        let text = try String(contentsOf: SourceTree.root.appendingPathComponent(path), encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
        let start = try #require(lines.firstIndex { $0.hasPrefix("static let minimumConfidence") }, "\(path)")
        let end = try #require(lines.firstIndex { $0 == "return language.rawValue" }, "\(path)")
        return Array(lines[start...end])
    }
}

/// The part of `Localizable.xcstrings` these tests read.
private struct Catalog: Decodable {
    struct Entry: Decodable {
        struct Localization: Decodable {
            struct StringUnit: Decodable { let value: String }
            let stringUnit: StringUnit?
        }

        let localizations: [String: Localization]?
    }

    let strings: [String: Entry]
}

/// A phrase and a description, and whether the description states the phrase.
struct StatedCase: Sendable, CustomTestStringConvertible {
    let phrase: String
    let description: String
    let stated: Bool

    var testDescription: String { "\"\(phrase)\" in \"\(description)\" is \(stated)" }

    var input: DraftingInput {
        DraftingInput(id: "stated", kind: .plain, language: "en", description: description, facts: [], traps: [])
    }

    static let all: [StatedCase] = [
        StatedCase(phrase: "20", description: "We grew from 12 to 20 nurses.", stated: true),
        StatedCase(phrase: "20", description: "I joined in 2024 and left in 2020.", stated: false),
        StatedCase(phrase: "20", description: "I managed 20.5 beds and 20,000 euro.", stated: false),
        StatedCase(phrase: "20", description: "A team of 20, mostly nurses.", stated: true),
        StatedCase(phrase: "Tom", description: "Tomorrow I start; my colleague tom said so.", stated: true),
        StatedCase(phrase: "Tom", description: "Tomorrow I start; the tomato season ends.", stated: false),
        StatedCase(phrase: "SAP", description: "I can use SAP and Excel.", stated: true),
        StatedCase(phrase: "SAP", description: "I know the sapphire trade.", stated: false),
        StatedCase(phrase: "grace.lowe@example.com", description: "Write to Grace.Lowe@example.com.", stated: true),
        StatedCase(phrase: "grace.lowe@example.com", description: "Write to ms.grace.lowe@example.com.", stated: false),
        StatedCase(phrase: "Riverside Clinic", description: "I left Riverside  Clinic, then Kestrel.", stated: true),
        StatedCase(phrase: "Riverside Clinic", description: "Riverside Hospital and the Clinic.", stated: false),
        StatedCase(phrase: "Zürich", description: "He lives in ZÜRICH.", stated: true),
        StatedCase(phrase: "Grace", description: "Grace's team and Graceland.", stated: true),
        StatedCase(phrase: "Riverside Clinic", description: "Riverside, Clinic.", stated: true),
        StatedCase(phrase: "+49 170 1234567", description: "Call +49 170 1234567 today.", stated: true),
        StatedCase(phrase: "+49 170 1234567", description: "Call +49 170 12345678 today.", stated: false),
        StatedCase(phrase: "", description: "Anything at all.", stated: false),
        StatedCase(phrase: "...", description: "Anything at all.", stated: false),
    ]
}
