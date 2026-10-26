import Testing
import Foundation

// The inputs of the drafting evaluation (#202) are fixtures: these tests keep them honest, so that a fact the counter looks
// for is one the description states, a trap is a real temptation, and no input holds real contact details.

@Suite("Drafting inputs: the 18 descriptions of the drafting evaluation")
struct DraftingInputsTests {
    @Test("Each language has its example, its plain description and its description with traps",
          arguments: DraftingInputs.languages)
    func threeInputsPerLanguage(_ language: String) throws {
        let inputs = try DraftingInputs.all().filter { $0.language == language }

        #expect(inputs.map(\.kind) == [.example, .plain, .traps])
        #expect(inputs.map(\.id) == ["example-\(language)", "\(language)-plain", "\(language)-traps"])
    }

    @Test("There are 18 inputs, each with an id of its own")
    func eighteenInputs() throws {
        let ids = try DraftingInputs.all().map(\.id)

        #expect(ids.count == 18)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Each expected fact and each trap occurs in its description", arguments: DraftingInputs.languages)
    func factsAndTrapsOccur(_ language: String) throws {
        for input in try DraftingInputs.all() where input.language == language {
            for fact in input.facts {
                #expect(!fact.forms.isEmpty, "\(input.id): \(fact)")
                for form in fact.forms {
                    #expect(input.description.range(of: form, options: .caseInsensitive) != nil, "\(input.id): \(form)")
                }
            }
            for trap in input.traps {
                #expect(input.description.range(of: trap, options: .caseInsensitive) != nil, "\(input.id): \(trap)")
            }
        }
    }

    @Test("Every input states a name, a title and two employers; the descriptions with traps have nine traps",
          arguments: DraftingInputs.languages)
    func factsOfEveryInput(_ language: String) throws {
        for input in try DraftingInputs.all() where input.language == language {
            let kinds = input.facts.map(\.kind)
            #expect(kinds.filter { $0 == .name }.count == 1, "\(input.id)")
            #expect(kinds.filter { $0 == .title }.count == 1, "\(input.id)")
            #expect(kinds.filter { $0 == .employer }.count == 2, "\(input.id)")
            #expect(kinds.filter { $0 == .school }.count == 1, "\(input.id)")
            #expect(kinds.filter { $0 == .language }.count == 2, "\(input.id)")
            #expect(input.traps.count == (input.kind == .traps ? 9 : 0), "\(input.id)")
        }
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
