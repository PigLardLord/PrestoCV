import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

@Suite("use cases · size limits")
struct SaveLimitsTests {
    @Test("a text at the limit is saved; one byte more is refused with its field and nothing is stored", arguments: textFields)
    func textLimit(_ field: TextFieldSpec) async throws {
        var draft = TextDraft(FixtureCV.full())
        draft[keyPath: field.key] = text(bytes: CVLimits.maxTextBytes)
        let fits = InMemoryCVRepository()
        _ = try await SaveCV(repository: fits)(TextEntry.initialiser.cv(from: draft))
        #expect(try await fits.list().cvs.count == 1)

        draft[keyPath: field.key] = text(bytes: CVLimits.maxTextBytes + 1)
        let over = InMemoryCVRepository()
        await #expect(throws: AuthoringError.exceedsLimits(.textTooLong(field.reported))) {
            _ = try await SaveCV(repository: over)(TextEntry.initialiser.cv(from: draft))
        }
        #expect(try await over.list().cvs.isEmpty)
    }

    @Test("a section of 200 entries is saved; one more is refused with its section and nothing is stored", arguments: allSections)
    func entryLimit(_ section: CVSection) async throws {
        _ = try await SaveCV(repository: InMemoryCVRepository())(limitCV(sections: entries(in: [section], count: CVLimits.maxEntriesPerSection)))
        let over = InMemoryCVRepository()
        await #expect(throws: AuthoringError.exceedsLimits(.tooManyEntries(section))) {
            _ = try await SaveCV(repository: over)(limitCV(sections: entries(in: [section], count: CVLimits.maxEntriesPerSection + 1)))
        }
        #expect(try await over.list().cvs.isEmpty)
    }

    @Test("texts that each fit are saved up to the total; one byte more is refused and nothing is stored")
    func totalLimit() async throws {
        _ = try await SaveCV(repository: InMemoryCVRepository())(limitCV(totalling: CVLimits.maxTotalTextBytes))
        let over = InMemoryCVRepository()
        await #expect(throws: AuthoringError.exceedsLimits(.tooMuchText)) {
            _ = try await SaveCV(repository: over)(limitCV(totalling: CVLimits.maxTotalTextBytes + 1))
        }
        #expect(try await over.list().cvs.isEmpty)
    }

    @Test("a CV without a name is refused for that first, whatever else is wrong with it")
    func nameComesFirst() async {
        let anonymous = limitCV(PersonalDetails(summary: text(bytes: CVLimits.maxTextBytes + 1)), sections: entries(in: [.skills], count: 201))
        await #expect(throws: AuthoringError.notEnoughContent) { _ = try await SaveCV(repository: InMemoryCVRepository())(anonymous) }
    }

    @Test("an edit that passes a limit is refused and the stored CV stays as it was")
    func updateRefused() async throws {
        let r = InMemoryCVRepository()
        let saved = try await SaveCV(repository: r)(FixtureCV.full())
        var edit = saved
        edit.setPersonalDetails(PersonalDetails(fullName: "Ada", summary: text(bytes: CVLimits.maxTextBytes + 1)))
        await #expect(throws: AuthoringError.exceedsLimits(.textTooLong(.summary))) { _ = try await SaveCV(repository: r)(edit) }
        #expect(try await LoadCV(repository: r)(saved.id) == saved)
    }

    @Test("renaming to a title that is too long is refused and the stored title stays")
    func renameRefused() async throws {
        let r = InMemoryCVRepository()
        let saved = try await SaveCV(repository: r)(FixtureCV.full())
        await #expect(throws: AuthoringError.exceedsLimits(.textTooLong(.title))) {
            _ = try await RenameCV(repository: r)(saved, to: text(bytes: CVLimits.maxTextBytes + 1))
        }
        let renamed = try await RenameCV(repository: r)(saved, to: text(bytes: CVLimits.maxTextBytes))
        #expect(renamed.revision == 2 && renamed.title.utf8.count == CVLimits.maxTextBytes)
    }

    @Test("a copy is refused when its title is too long, or when the CV it copies is over a limit; nothing is stored")
    func duplicateRefused() async throws {
        let r = InMemoryCVRepository()
        let saved = try await SaveCV(repository: r)(FixtureCV.full())
        await #expect(throws: AuthoringError.exceedsLimits(.textTooLong(.title))) {
            _ = try await DuplicateCV(repository: r, ids: SequentialIDGenerator())(saved, title: text(bytes: CVLimits.maxTextBytes + 1))
        }
        let heavy = limitCV(sections: entries(in: [.skills], count: 201))
        let stored = try await r.create(heavy.duplicated(as: CVID(UUID(uuidString: "33333333-3333-3333-3333-333333333333")!), title: "Heavy"))
        await #expect(throws: AuthoringError.exceedsLimits(.tooManyEntries(.skills))) {
            _ = try await DuplicateCV(repository: r, ids: SequentialIDGenerator())(stored, title: "Copy")
        }
        #expect(try await r.list().cvs.count == 2)
    }
}
