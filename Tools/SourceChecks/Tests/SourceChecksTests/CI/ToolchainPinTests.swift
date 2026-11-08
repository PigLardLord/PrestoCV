import Foundation
import Testing

// MARK: - Toolchain Pin Tests

/// `.swift-version` pins the Swift of every build: a computer, the Linux job, the Mac checks and Xcode Cloud (ADR 0026).
/// `Tools/check-toolchain.sh` fails a run whose Swift is another one; these tests hold the versions the CI workflow names to
/// the pin, so that moving to another Swift is one commit that changes `.swift-version` and the workflow together.
@Suite("The pinned Swift")
struct ToolchainPinTests {

    private static let pinFile = ".swift-version"
    private static let workflow = ".github/workflows/ci.yml"

    /// A Swift version the workflow names, with its line.
    struct Mention: Equatable, CustomStringConvertible {
        let line: Int
        let version: String

        var description: String { "line \(line): \(version)" }
    }

    /// The Swift versions a workflow names: the container image `swift:<version>`, the variable `SWIFT_VERSION: <version>`
    /// and the checker's cache key `checker-linux-swift-<version>-`.
    static func mentions(in text: String) -> [Mention] {
        let patterns = [
            /container:\s*swift:([0-9][0-9.]*[0-9])/,
            /SWIFT_VERSION:\s*"?([0-9][0-9.]*[0-9])/,
            /checker-linux-swift-([0-9][0-9.]*[0-9])-/,
        ]
        var mentions: [Mention] = []
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            for pattern in patterns {
                for match in line.matches(of: pattern) {
                    mentions.append(Mention(line: index + 1, version: String(match.1)))
                }
            }
        }
        return mentions
    }

    // MARK: Reader

    @Test("The reader finds the container, the variable and the cache keys, with their lines")
    func readerFindsEachKind() {
        let text = """
        jobs:
          linux:
            container: swift:6.4.2
            steps:
              - with:
                  key: checker-linux-swift-6.4.1-${{ hashFiles('x') }}
                  restore-keys: checker-linux-swift-6.4.1-
          android:
            env:
              SWIFT_VERSION: "6.3"
        """

        #expect(Self.mentions(in: text) == [
            Mention(line: 3, version: "6.4.2"),
            Mention(line: 6, version: "6.4.1"),
            Mention(line: 7, version: "6.4.1"),
            Mention(line: 10, version: "6.3"),
        ])
    }

    @Test("A line that names no Swift version is not a mention", arguments: [
        "    container: ubuntu:24.04",
        "      SWIFT_TOOLCHAIN_SHA256: 0123abcd",
        "          key: swift-${{ env.SWIFT_VERSION }}-ubuntu24.04",
        "# swift 6.4.2 is the pinned one",
    ])
    func otherLinesAreNotMentions(line: String) {
        #expect(Self.mentions(in: line).isEmpty)
    }

    // MARK: Repository

    @Test(".swift-version holds one version such as 6.4.2, on one line")
    func pinIsOneVersion() throws {
        let text = try Repository.text(Self.pinFile)
        let lines = text.split(whereSeparator: \.isNewline)

        #expect(lines.count == 1, "\(Self.pinFile) has \(lines.count) lines")
        #expect(lines.first?.wholeMatch(of: /[0-9]+\.[0-9]+\.[0-9]+/) != nil, "\(Self.pinFile) holds \"\(text)\"")
    }

    @Test("Every Swift version the CI workflow names is the one .swift-version pins")
    func workflowFollowsThePin() throws {
        let pin = try Repository.text(Self.pinFile).trimmingCharacters(in: .whitespacesAndNewlines)
        let mentions = Self.mentions(in: try Repository.text(Self.workflow))

        // The Linux job's container, the checker's cache key and restore key, and the Android job's toolchain.
        #expect(mentions.count >= 4, "Found \(mentions) in \(Self.workflow): the workflow or the reader changed")
        for mention in mentions where mention.version != pin {
            Issue.record("\(Self.workflow) names Swift \(mention.version) at line \(mention.line), and \(Self.pinFile) pins \(pin)")
        }
    }
}
