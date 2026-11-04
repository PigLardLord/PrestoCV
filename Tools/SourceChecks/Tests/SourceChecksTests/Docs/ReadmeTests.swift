import Foundation
import Testing

// MARK: - Readme Tests

/// The README is where a visitor starts. Its "Where things are" table says what each part of the repository is, so a path it
/// names has to be there and a folder the repository has must be in it; and it links the files that make the project open
/// source, which have to exist.
@Suite("The README")
struct ReadmeTests {

    private static let tableHeading = "## Where things are"

    /// The files that make the project open source.
    static let openSourceFiles = ["LICENSE", "NOTICE", "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md"]

    /// The paths in the first cell of each row of the table, in the order they are written, without a trailing slash.
    private static func tablePaths() throws -> [String] {
        let lines = try Repository.text("README.md").split(separator: "\n", omittingEmptySubsequences: false)
        let start = try #require(lines.firstIndex { $0 == tableHeading }, "README.md has no line \"\(tableHeading)\"")
        let rest = lines[(start + 1)...]
        let end = rest.firstIndex { $0.hasPrefix("## ") } ?? rest.endIndex
        let rows = rest[..<end].filter { $0.hasPrefix("| ") && !$0.hasPrefix("| Path ") && !$0.hasPrefix("|---") }
        return rows.flatMap { row -> [String] in
            let cell = row.split(separator: "|", omittingEmptySubsequences: false).dropFirst().first ?? ""
            return cell.matches(of: /`([^`]+)`/).map { match in
                var path = String(match.output.1)
                while path.hasSuffix("/") { path.removeLast() }
                return path
            }
        }
    }

    /// Whether a tracked file is the path or is under it.
    private static func isTracked(_ path: String, in tracked: [String]) -> Bool {
        tracked.contains { $0 == path || $0.hasPrefix(path + "/") }
    }

    @Test("The table names at least one path, so that the parser has found its rows")
    func tableHasRows() throws {
        let paths = try Self.tablePaths()

        #expect(paths.count >= 10, "Found \(paths.count) paths in the table; README.md's table or this parser changed")
        #expect(paths.contains("docs/architecture"))
    }

    @Test("Every path in the table is in the repository")
    func tablePathsExist() throws {
        let tracked = try Repository.trackedFiles()

        for path in try Self.tablePaths() where !Self.isTracked(path, in: tracked) {
            Issue.record(Comment(rawValue: "README.md's table names \(path), which is not in the repository"))
        }
    }

    @Test("Every top-level folder of the repository is in the table")
    func everyTopLevelFolderIsInTheTable() throws {
        let tracked = try Repository.trackedFiles()
        let folders = Set(tracked.filter { $0.contains("/") }.map { String($0.prefix { $0 != "/" }) })
        let named = try Self.tablePaths().map { String($0.prefix { $0 != "/" }) }

        #expect(folders.count >= 10, "Found \(folders.count) top-level folders: the list of tracked files is wrong")
        for folder in folders.sorted() where !named.contains(folder) {
            Issue.record(Comment(rawValue: "\(folder)/ is a folder of the repository that README.md's table \"\(Self.tableHeading.dropFirst(3))\" does not name"))
        }
    }

    @Test("The open-source files exist, and the README links each of them", arguments: openSourceFiles)
    func openSourceFilesAreLinked(file: String) throws {
        let tracked = try Repository.trackedFiles()
        let readme = try Repository.text("README.md")

        #expect(tracked.contains(file), "\(file) is not in the repository")
        #expect(readme.contains("](\(file))") || readme.contains("](\(file)#"), "README.md does not link \(file)")
    }

    @Test("The README says that the name and the icon are not licensed")
    func readmeSaysTheNameAndIconAreNotLicensed() throws {
        let readme = try Repository.text("README.md")

        #expect(readme.contains("not licensed"), "README.md does not say that the name and the icon are not licensed")
    }

    @Test("The contact address is filled in where the policies name it", arguments: ["SECURITY.md", "CODE_OF_CONDUCT.md"])
    func contactAddressIsFilledIn(file: String) throws {
        let text = try Repository.text(file)

        #expect(!text.contains("CONTACT_EMAIL"), "\(file) still holds the placeholder CONTACT_EMAIL")
        #expect(text.contains("support@prestocv.app"), "\(file) does not give support@prestocv.app as the contact")
    }

    @Test("The security policy names GitHub's private vulnerability reporting as the preferred channel")
    func securityPolicyNamesPrivateReporting() throws {
        let policy = try Repository.text("SECURITY.md")

        #expect(policy.contains("private vulnerability reporting"), "SECURITY.md does not name private vulnerability reporting")
        #expect(policy.contains("preferred"), "SECURITY.md does not say which channel is preferred")
    }
}
