import Testing
import TailoringModel

@Suite("ADR 0013 / R8 · the report and the questions")
struct ReportAndQuestionTests {
    @Test("a report is the model's account of what it did")
    func report() throws {
        let report = try TailoringReport(argument: "Ten years of backend work.", cut: ["Hobby projects"], moved: ["Skills before education"],
                                         reworded: ["Summary", "Second role"])
        #expect(report.argument == "Ten years of backend work.")
        #expect(report.cut == ["Hobby projects"])
        #expect(report.moved == ["Skills before education"])
        #expect(report.reworded == ["Summary", "Second role"])
    }

    @Test("a report may say nothing was cut, moved or reworded")
    func emptyReport() throws {
        let report = try TailoringReport(argument: "", cut: [], moved: [], reworded: [])
        #expect(report.cut.isEmpty && report.moved.isEmpty && report.reworded.isEmpty)
    }

    static let reportFields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(TextFieldCase(.argument) { _ = try TailoringReport(argument: $0, cut: [], moved: [], reworded: []) })
        cases.append(TextFieldCase(.reportItem) { _ = try TailoringReport(argument: "", cut: ["ok", $0], moved: [], reworded: []) })
        cases.append(TextFieldCase(.reportItem) { _ = try TailoringReport(argument: "", cut: [], moved: ["ok", $0], reworded: []) })
        cases.append(TextFieldCase(.reportItem) { _ = try TailoringReport(argument: "", cut: [], moved: [], reworded: ["ok", $0]) })
        return cases
    }()

    @Test("the argument and each item accept 10,000 bytes and refuse one more", arguments: reportFields)
    func reportTextBounds(field: TextFieldCase) throws {
        try field.build(ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(field.field)) { try field.build(ascii(10_001)) }
    }

    static let reportLists: [SectionCase] = {
        var cases: [SectionCase] = []
        cases.append(SectionCase(.cut) { _ = try TailoringReport(argument: "", cut: Array(repeating: "item", count: $0), moved: [], reworded: []) })
        cases.append(SectionCase(.moved) { _ = try TailoringReport(argument: "", cut: [], moved: Array(repeating: "item", count: $0), reworded: []) })
        cases.append(SectionCase(.reworded) { _ = try TailoringReport(argument: "", cut: [], moved: [], reworded: Array(repeating: "item", count: $0)) })
        return cases
    }()

    @Test("each list of the report holds at most 200 items", arguments: reportLists)
    func reportListBounds(list: SectionCase) throws {
        try list.build(200)
        #expect(throws: TailoringModelError.tooMany(list.collection)) { try list.build(201) }
    }

    // MARK: Questions

    @Test("a question asks about a term, a letter field or a request, within a scope")
    func question() throws {
        let source = try Sample.source()
        let experience = try source.experience(1)
        let term = try Question(kind: .unevidencedTerm("Kubernetes"), scope: .experience(experience))
        #expect(term.kind == .unevidencedTerm("Kubernetes"))
        #expect(term.scope == .experience(experience))
        let field = try Question(kind: .letterField(.salaryExpectation), scope: .letter(.salaryExpectation))
        #expect(field.kind == .letterField(.salaryExpectation) && field.scope == .letter(.salaryExpectation))
        let request = try Question(kind: .modelRequest("Which team did you lead?"), scope: .summary)
        #expect(request.kind == .modelRequest("Which team did you lead?") && request.scope == .summary)
        #expect(try Question(kind: .unevidencedTerm("Docker"), scope: .skills).scope == .skills)
    }

    @Test("a letter field is the salary expectation or the start date")
    func letterFields() {
        #expect(Set([LetterField.salaryExpectation, .startDate]).count == 2)
        #expect(LetterField.allCases.count == 2)
    }

    static let blankTexts: [String] = {
        var texts: [String] = []
        texts.append(contentsOf: ["", " ", "\n\t"])
        return texts
    }()

    @Test("a term or a request with nothing in it is refused", arguments: blankTexts)
    func emptyText(text: String) {
        #expect(throws: TailoringModelError.emptyField(.term)) { try Question(kind: .unevidencedTerm(text), scope: .skills) }
        #expect(throws: TailoringModelError.emptyField(.request)) { try Question(kind: .modelRequest(text), scope: .summary) }
    }

    @Test("a term or a request accepts 10,000 bytes and refuses one more")
    func questionBounds() throws {
        _ = try Question(kind: .unevidencedTerm(ascii(10_000)), scope: .skills)
        _ = try Question(kind: .modelRequest(ascii(10_000)), scope: .summary)
        #expect(throws: TailoringModelError.tooLarge(.term)) { try Question(kind: .unevidencedTerm(ascii(10_001)), scope: .skills) }
        #expect(throws: TailoringModelError.tooLarge(.request)) { try Question(kind: .modelRequest(ascii(10_001)), scope: .summary) }
    }

    @Test("a question that needs no text is always valid", arguments: LetterField.allCases)
    func letterFieldQuestion(field: LetterField) throws {
        _ = try Question(kind: .letterField(field), scope: .letter(field))
    }
}
