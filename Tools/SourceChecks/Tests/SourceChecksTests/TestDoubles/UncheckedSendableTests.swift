import Testing
import Foundation

/// R10 (docs/architecture/rules.md): test doubles use `Mutex`, not `@unchecked Sendable`. A `Mutex` makes the compiler check
/// what `@unchecked Sendable` and a lock leave to the author, and a double written with it needs no promise that it is safe.
///
/// The tests that were written before the rule still have some. They are listed, and the list only shrinks: a new double has
/// a `Mutex`, and a file that drops its last `@unchecked Sendable` leaves the list.
@Suite("Test doubles - a Mutex, not @unchecked Sendable")
struct UncheckedSendableTests {

    // MARK: - Helpers

    /// The files of the app's tests that still declare a type `@unchecked Sendable`, from the root of the repository
    private static let legacy: Set<String> = [
        "PrestoCVTests/Features/CVEditor/ElementBindingTests.swift",
        "PrestoCVTests/Features/CVList/CVListRowTextTests.swift",
        "PrestoCVTests/Features/CVList/CVListViewModelUnreadableTests.swift",
        "PrestoCVTests/Features/Import/ImportViewModelTests.swift",
    ]

    private static let unchecked = try! NSRegularExpression(pattern: #"@unchecked\s+Sendable\b"#)

    /// The files of the app's tests that name `@unchecked Sendable` in their code, not in a comment
    private static func declaring() throws -> Set<String> {
        let files = try RepositorySources.swiftFiles(in: "PrestoCVTests")
        try #require(!files.isEmpty, "The sources of the app's tests are in the repository")
        return Set(files.filter { !SwiftCode($0.text).lines(matching: unchecked).isEmpty }.map(\.path))
    }

    // MARK: - Tests

    @Test("No new test double is @unchecked Sendable: it keeps what it shares in a Mutex")
    func noNewDoubleIsUnchecked() throws {
        let new = try Self.declaring().subtracting(Self.legacy).sorted()

        #expect(new.isEmpty, "R10: use a Mutex from Synchronization, as AppLaunchViewModelTests does, in \(new)")
    }

    @Test("A file of the list still declares one: when it does not, it leaves the list")
    func theListHoldsOnlyWhatIsStillThere() throws {
        let stale = Self.legacy.subtracting(try Self.declaring()).sorted()

        #expect(stale.isEmpty, "These files no longer declare @unchecked Sendable: take them out of the list, which only shrinks: \(stale)")
    }
}
