import Testing
import PrestoCVDomain
import PrestoCVCoreTestSupport
import PrestoCVIntegration
import CVDocumentModel

/// R10, "Mapper completeness": every populated field of a `CV` reaches the `CVDocument`. The leaves of the CV are walked
/// with Mirror, so a field added to the CV fails these tests until it is mapped or listed as not printed.
@Suite("Mapper completeness (#88)")
struct MapperCompletenessTests {
    /// The fields of `CV` that are not printed: identity, revision and dates of storage belong to the repository, the
    /// title is the user's name for the CV in the list, the design goes to the renderer as a stylesheet, and the language
    /// of the document is the one the export asks for.
    static let notPrinted: Set<String> = ["id", "revision", "createdAt", "updatedAt", "title", "design", "language"]

    /// The only leaves whose name differs between the two contexts.
    static let translations = ["current": "present", "unknown": "unspecified"]

    let mapper = CVToDocumentMapper()

    /// `FieldLeaves.of(_:skipping:)` skips by label at every depth, so skipping "language" would also drop the name of
    /// each language skill. The fields that are not printed are skipped here, at the top level of the CV only.
    static func printedLeaves(of cv: CV) -> [String] {
        Mirror(reflecting: cv).children.filter { !notPrinted.contains($0.label ?? "") }.flatMap { FieldLeaves.of($0.value) }
    }

    /// The envelope of the document (version and language) is left out: it is not a field of the CV.
    static func leaves(of document: CVDocument) -> [String] {
        FieldLeaves.of(document.person) + FieldLeaves.of(document.sections)
    }

    @Test("the fixture populates every printed field")
    func fixtureIsFull() {
        let leaves = Self.printedLeaves(of: FixtureCV.full())

        #expect(!leaves.isEmpty)
        #expect(!leaves.contains(FieldLeaves.missing), "a printed field of the fixture is nil")
        #expect(!leaves.contains(FieldLeaves.empty), "a printed collection of the fixture is empty")
    }

    @Test("every printed leaf reaches the document as many times as it occurs in the CV", arguments: Subject.allCases)
    func everyLeafReachesTheDocument(subject: Subject) throws {
        let cv = try subject.cv()
        var expected = Self.printedLeaves(of: cv).map { Self.translations[$0] ?? $0 }
        // CVDocument version 1 holds only the year of a certification, so the months of `issued` are the one thing that
        // cannot arrive. They are computed from the CV, and removed from the expectation one occurrence each.
        for month in cv.sections.certifications.compactMap({ $0.issued?.month }) {
            let leaf = String(month)
            let index = try #require(expected.firstIndex(of: leaf), "the month \(leaf) of a certification is not among the leaves")
            expected.remove(at: index)
        }
        let document = mapper.map(cv, language: try documentLanguage("it"))

        let wanted = Dictionary(expected.map { ($0, 1) }, uniquingKeysWith: +)
        let got = Dictionary(Self.leaves(of: document).map { ($0, 1) }, uniquingKeysWith: +)
        for (leaf, count) in wanted.sorted(by: { $0.key < $1.key }) {
            #expect((got[leaf] ?? 0) >= count, "\"\(leaf)\" occurs \(count) time(s) in the CV and \(got[leaf] ?? 0) in the document")
        }
    }

    /// What the completeness test maps: the fixture, and the fixture with an entry whose end date is unknown, which the
    /// fixture itself does not have.
    enum Subject: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case fixture = "the fixture"
        case withUnknownEnd = "the fixture and an entry that ended on an unknown date"

        var testDescription: String { rawValue }

        func cv() throws -> CV {
            var cv = FixtureCV.full()
            switch self {
            case .fixture:
                break
            case .withUnknownEnd:
                var sections = cv.sections
                let period = try #require(Period(start: try partialDate(2008, 4), end: .unknown))
                sections.experiences.append(Experience(role: "Clerk", company: "Old Firm", location: "Bath", period: period, description: "Ledgers"))
                cv.setSections(sections)
            }
            return cv
        }
    }
}
