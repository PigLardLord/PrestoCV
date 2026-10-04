import Foundation
import Testing
@testable import DocsCheckKit

@Suite("The README describes the tool")
struct ReadmeTests {
    private func readme() throws -> String {
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: package.appendingPathComponent("README.md"), encoding: .utf8)
    }

    @Test("the codes listed after \"Codes:\" are exactly the codes the tool prints")
    func codes() throws {
        var listed: [String] = []
        for line in try readme().components(separatedBy: "\n") where line.hasPrefix("Codes: ") {
            listed += line.components(separatedBy: "`").enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        }
        #expect(Set(listed) == Set(FindingCode.allCases.map(\.rawValue)))
        #expect(listed.count == Set(listed).count)
    }

    @Test("the markers the rule check looks for are the ones the README gives")
    func markers() throws {
        let text = try readme().lowercased()
        #expect(text.contains("\"\(RuleStatedCheck.ruleMarker)\""))
        #expect(text.contains("\"\(RuleStatedCheck.templateHeadingMarker)\""))
        #expect(text.contains(RuleStatedCheck.agentsPath.lowercased()) && text.contains(RuleStatedCheck.templatePath))
    }
}
