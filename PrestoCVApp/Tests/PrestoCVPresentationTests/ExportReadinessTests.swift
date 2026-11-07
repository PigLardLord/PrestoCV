import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// What the CV lacks for an export, as the domain's `ExportReadiness` says, before the PDF is made.
@MainActor
@Suite("Export sheet readiness")
struct ExportReadinessTests {

    @Test("A CV without a name is not exported: the status says not ready and the name is the blocker")
    func noNameBlocksAndNothingStarts() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(fullName: "")
        let sheet = world.sheet()

        sheet.start()
        world.passThePause()
        await waitUntil("the sheet to read the CV") { sheet.status != .exporting }
        await settle()

        #expect(sheet.status == .notReady)
        #expect(world.exporter.calls == 0, "a PDF that does not say whose CV it is")
        #expect(sheet.missing.blockers == [.name])
        #expect(sheet.document == nil && sheet.suggestedFileName == nil)
    }

    @Test("A CV without an e-mail address or a phone number is exported, and the sheet still lists both")
    func missingEmailOrPhoneIsAWarningOnly() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(email: nil, phone: nil)
        let sheet = world.sheet()

        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the export to end") { sheet.status != .exporting }

        #expect(sheet.status == .done(pages: 1))
        #expect(sheet.missing.blockers.isEmpty)
        #expect(sheet.missing.warnings == [.email, .phone])
    }

    /// A CV of the sheet and what the domain's `ExportReadinessTests` say of the same fields (invented values).
    struct ReadinessRow: Sendable, CustomTestStringConvertible {
        let name: String
        let email: String?
        let phone: String?
        let blockers: [ExportMissing.Field]
        let warnings: [ExportMissing.Field]

        var testDescription: String { "name \(name.debugDescription), e-mail \(email ?? "none"), phone \(phone ?? "none")" }
    }

    nonisolated static let readinessRows = [
        ReadinessRow(name: "", email: "mara@example.com", phone: "+39 06 5550100", blockers: [.name], warnings: []),
        ReadinessRow(name: "  ", email: "mara@example.com", phone: "+39 06 5550100", blockers: [.name], warnings: []),
        ReadinessRow(name: "Mara Ellison", email: nil, phone: "+39 06 5550100", blockers: [], warnings: [.email]),
        ReadinessRow(name: "Mara Ellison", email: "mara@example.com", phone: nil, blockers: [], warnings: [.phone]),
        ReadinessRow(name: "", email: nil, phone: nil, blockers: [.name], warnings: [.email, .phone]),
        ReadinessRow(name: "Mara Ellison", email: "mara@example.com", phone: "+39 06 5550100", blockers: [], warnings: []),
    ]

    @Test("Blockers and warnings are the domain's: only the name blocks, white space is no name", arguments: readinessRows)
    func blockersAndWarningsFollowTheDomainRule(row: ReadinessRow) async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(fullName: row.name, email: row.email, phone: row.phone)
        let sheet = world.sheet()

        sheet.start()
        world.passThePause()
        await waitUntil("the sheet to read the CV") { sheet.status != .exporting }

        #expect(sheet.missing.blockers == row.blockers)
        #expect(sheet.missing.warnings == row.warnings)
    }
}
