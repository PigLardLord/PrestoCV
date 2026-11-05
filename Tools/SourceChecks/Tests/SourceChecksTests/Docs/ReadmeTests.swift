import Foundation
import Testing

// MARK: - Readme Tests

/// The README is where a visitor starts. Its "Where things are" table says what each part of the repository is, so a path it
/// names has to be there and a folder the repository has must be in it; and it links the files that make the project open
/// source, which have to exist and to be free of placeholders. How the text is read is in `ReadmeText`, which has its own tests;
/// these tests hold the repository to it.
@Suite("The README")
struct ReadmeTests {

    /// The files that make the project open source.
    static let openSourceFiles = ["LICENSE", "NOTICE", "CONTRIBUTING.md", "SECURITY.md", "CODE_OF_CONDUCT.md"]

    /// The paths the table names, in the order they are written.
    private static func tablePaths() throws -> [String] {
        ReadmeText.tablePaths(in: try Repository.text("README.md"))
    }

    /// Whether a file is the path or is under it.
    private static func isPresent(_ path: String, in files: [String]) -> Bool {
        files.contains { $0 == path || $0.hasPrefix(path + "/") }
    }

    @Test("The table names at least one path, so that the parser has found its rows")
    func tableHasRows() throws {
        let readme = try Repository.text("README.md")
        let paths = ReadmeText.tablePaths(in: readme)

        #expect(readme.contains(ReadmeText.tableHeading), "README.md has no line \"\(ReadmeText.tableHeading)\"")
        #expect(paths.count >= 10, "Found \(paths.count) paths in the table; README.md's table or ReadmeText.tablePaths changed")
        #expect(paths.contains("docs/architecture"))
    }

    @Test("Every path in the table is in the repository")
    func tablePathsExist() throws {
        let files = try Repository.presentFiles()

        for path in try Self.tablePaths() where !Self.isPresent(path, in: files) {
            Issue.record("README.md's table names \(path), which is not in the repository")
        }
    }

    @Test("Every top-level folder of the repository is in the table")
    func everyTopLevelFolderIsInTheTable() throws {
        let files = try Repository.presentFiles()
        let folders = Set(files.filter { $0.contains("/") }.map { String($0.prefix { $0 != "/" }) })
        let named = try Self.tablePaths().map { String($0.prefix { $0 != "/" }) }

        #expect(folders.count >= 10, "Found \(folders.count) top-level folders: the list of files is wrong")
        for folder in folders.sorted() where !named.contains(folder) {
            Issue.record("\(folder)/ is a folder of the repository that README.md's table \"\(ReadmeText.tableHeading.dropFirst(3))\" does not name")
        }
    }

    @Test("The open-source files exist, and the README links each of them", arguments: openSourceFiles)
    func openSourceFilesAreLinked(file: String) throws {
        let files = try Repository.presentFiles()
        let targets = MarkdownText.relativeLinkTargets(in: try Repository.text("README.md"))

        #expect(files.contains(file), "\(file) is not in the repository")
        #expect(targets.contains(file), "README.md does not link \(file)")
    }

    @Test("The README says that the name and the icon are not licensed")
    func readmeSaysTheNameAndIconAreNotLicensed() throws {
        let readme = try Repository.text("README.md")

        #expect(readme.contains("not licensed"), "README.md does not say that the name and the icon are not licensed")
    }

    @Test("The open-source files keep no placeholder")
    func openSourceFilesKeepNoPlaceholder() throws {
        for file in Self.openSourceFiles {
            let placeholders = ReadmeText.placeholders(in: try Repository.text(file))
            #expect(placeholders.isEmpty, "\(file) still holds \(placeholders.joined(separator: ", "))")
        }
    }

    /// Whether a Markdown document has a heading "Attribution", outside fenced code: the section where a text taken from
    /// another work names its source and licence.
    private static func hasAttributionHeading(_ markdown: String) -> Bool {
        let lines = MarkdownText.lines(of: markdown)
        return zip(lines, MarkdownText.fencedLines(in: lines)).contains { line, isFenced in
            guard !isFenced, let level = MarkdownText.headingLevel(of: line) else { return false }
            return line.drop { $0 == " " }.dropFirst(level).trimmingCharacters(in: .whitespaces) == "Attribution"
        }
    }

    @Test("A document with an Attribution section is named among NOTICE's third-party components")
    func attributedDocumentsAreNamedInNotice() throws {
        let sections = try Repository.text("NOTICE").components(separatedBy: "\nThird-party components\n")
        let attributed = try Repository.presentFiles().filter(MarkdownText.isMarkdown).filter {
            Self.hasAttributionHeading(try Repository.text($0))
        }

        try #require(sections.count == 2, "NOTICE has no heading \"Third-party components\"")
        #expect(attributed.contains("CODE_OF_CONDUCT.md"), "Found \(attributed): the code of conduct has no Attribution section")
        for file in attributed where !sections[1].contains(file) {
            Issue.record("\(file) has an Attribution section, so it comes from another work, and NOTICE's \"Third-party components\" does not name it")
        }
    }

    @Test("The contact address is filled in where the policies name it", arguments: ["SECURITY.md", "CODE_OF_CONDUCT.md"])
    func contactAddressIsFilledIn(file: String) throws {
        let text = try Repository.text(file)

        #expect(text.contains("support@prestocv.app"), "\(file) does not give support@prestocv.app as the contact")
    }

    @Test("The security policy says in one paragraph that private vulnerability reporting is the preferred channel")
    func securityPolicyPrefersPrivateReporting() throws {
        let policy = try Repository.text("SECURITY.md")

        #expect(
            ReadmeText.paragraphMentioning(["private vulnerability reporting", "preferred"], in: policy),
            "No paragraph of SECURITY.md names private vulnerability reporting and says that it is preferred"
        )
    }
}
