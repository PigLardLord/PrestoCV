import Testing
import Foundation
import CVRendering
import CVRenderingTestSupport

@Suite("#558 · a print compared with the layout reference of its device and system version")
struct LayoutReferenceStoreTests {
    static let page = PDFBox(x: 0, y: 0, width: 595, height: 842)

    static func layout(y: Double = 700, page pageIndex: Int = 0) -> PDFLayout {
        PDFLayout(pages: [page], lines: [
            PDFTextLine(pageIndex: pageIndex, text: "Ada Lovelace", box: PDFBox(x: 36, y: 780, width: 200, height: 12),
                        glyphHeight: 10),
            PDFTextLine(pageIndex: pageIndex, text: "Profile", box: PDFBox(x: 36, y: y, width: 100, height: 12),
                        glyphHeight: 10),
        ])
    }

    static func reference(_ kind: DeviceKind, _ version: OSVersion, y: Double = 700) -> LayoutReference {
        LayoutReference(kind: kind, osVersion: version, design: "minimal", document: .contractFixture, layout: layout(y: y))
    }

    /// A folder holding `references`, written as `LayoutReference.json()` does.
    static func store(_ references: [LayoutReference]) throws -> LayoutReferenceStore {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("layout-references-\(UUID().uuidString)", isDirectory: true)
        for reference in references {
            let file = folder.appendingPathComponent(reference.path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(reference.json().utf8).write(to: file)
        }
        return LayoutReferenceStore(folder: folder)
    }

    static let v270 = OSVersion(major: 27, minor: 0)
    static let v271 = OSVersion(major: 27, minor: 1)
    static let v272 = OSVersion(major: 27, minor: 2)

    @Test("a print equal to the reference of its kind and version matches")
    func matches() throws {
        let store = try Self.store([Self.reference(.iphone, Self.v270)])
        #expect(try store.verdict(of: Self.reference(.iphone, Self.v270)) == .matches)
    }

    @Test("a print half a point from the reference matches, and further from it fails, naming the line and how far it moved")
    func tolerance() throws {
        let store = try Self.store([Self.reference(.ipad, Self.v270)])
        #expect(try store.verdict(of: Self.reference(.ipad, Self.v270, y: 699.5)) == .matches)
        let verdict = try store.verdict(of: Self.reference(.ipad, Self.v270, y: 698.9))
        guard case .differs(let kind, let version, let path, let differences) = verdict else {
            Issue.record("\(verdict)")
            return
        }
        #expect(kind == .ipad && version == Self.v270 && path == "ipad-27.0/minimal-contract-fixture.json")
        #expect(differences.count == 1)
        guard case .moved(let page, let text, _, let dy, _, _) = differences[0] else {
            Issue.record("\(differences)")
            return
        }
        #expect(page == 0 && text == "Profile" && abs(dy + 1.1) < 0.001)
        #expect(verdict.description.contains("ipad 27.0"))
        #expect(verdict.description.contains("\"Profile\" moved by x +0.00, y -1.10"))
    }

    @Test("a line on another page fails whatever the tolerance")
    func otherPage() throws {
        let store = try Self.store([Self.reference(.mac, Self.v272)])
        var found = Self.reference(.mac, Self.v272)
        found.layout = Self.layout(page: 1)
        let verdict = try store.verdict(of: found, tolerance: 100)
        #expect(verdict.description.contains("is on page 2, on page 1 in the reference"))
    }

    @Test("a version with no folder reads the closest lower one, and the failure names that reference's kind and version")
    func closestLower() throws {
        let store = try Self.store([
            Self.reference(.iphone, Self.v270), Self.reference(.iphone, Self.v272), Self.reference(.mac, Self.v270),
        ])
        #expect(try store.verdict(of: Self.reference(.iphone, Self.v271)) == .matches)
        let verdict = try store.verdict(of: Self.reference(.iphone, Self.v271, y: 650))
        guard case .differs(let kind, let version, _, _) = verdict else { Issue.record("\(verdict)"); return }
        #expect(kind == .iphone && version == Self.v270)
    }

    @Test("a kind with no reference at or below the running version says how to record one")
    func noReference() throws {
        let store = try Self.store([Self.reference(.iphone, Self.v272), Self.reference(.mac, Self.v270)])
        for found in [Self.reference(.iphone, Self.v271), Self.reference(.ipad, Self.v272)] {
            guard case .noReference(let message) = try store.verdict(of: found) else { Issue.record("no message"); return }
            let missing = "no layout reference for \(found.kind.rawValue) \(found.osVersion) or an earlier version"
            #expect(message.hasPrefix(missing))
            #expect(message.contains("RECORD_LAYOUTS"))
        }
    }

    @Test("a design or document missing from the version's folder says which file is missing")
    func noFile() throws {
        let store = try Self.store([Self.reference(.mac, Self.v270)])
        var found = Self.reference(.mac, Self.v270)
        found.document = .pageBreaks
        guard case .noReference(let message) = try store.verdict(of: found) else { Issue.record("no message"); return }
        #expect(message.hasPrefix("no layout reference mac-27.0/minimal-page-breaks.json"))
    }

    @Test("a folder that does not exist holds no reference")
    func missingFolder() throws {
        let store = LayoutReferenceStore(folder: URL(fileURLWithPath: "/nonexistent/layout-references"))
        #expect(try store.names().isEmpty)
        #expect(try !store.hasReferences())
    }

    @Test("a folder that exists and cannot be read is an error, never an empty store")
    func unreadableFolder() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("layout-references-\(UUID().uuidString)")
        try Data("not a folder".utf8).write(to: file)
        defer { _ = try? FileManager.default.removeItem(at: file) }
        let store = LayoutReferenceStore(folder: file)
        #expect(throws: (any Error).self) { try store.names() }
        #expect(throws: (any Error).self) { try store.hasReferences() }
        #expect(throws: (any Error).self) { try store.verdict(of: Self.reference(.iphone, Self.v270)) }
    }

    @Test("a recorded reference that cannot be decoded is an error, never a missing reference")
    func undecodableReference() throws {
        let store = try Self.store([Self.reference(.iphone, Self.v270)])
        let found = Self.reference(.iphone, Self.v270)
        try Data("{ not json".utf8).write(to: store.folder.appendingPathComponent(found.path))
        #expect(throws: (any Error).self) { try store.verdict(of: found) }
    }

    @Test("the newest references of each kind are read back")
    func newest() throws {
        let store = try Self.store([
            Self.reference(.iphone, Self.v270), Self.reference(.iphone, Self.v272), Self.reference(.mac, Self.v271),
        ])
        let newest = try LayoutParity.newest(in: store)
        #expect(newest[.iphone]?.map(\.osVersion) == [Self.v272])
        #expect(newest[.mac]?.map(\.osVersion) == [Self.v271])
        #expect(newest[.ipad] == nil)
    }
}
