import Foundation

/// What an import of leftover edits did.
public struct LeftoverEditsImportReport: Equatable, Sendable {
    /// Leftovers whose edits the CVs hold now, and which were removed.
    public var imported = 0
    /// Leftovers that could not be stored or removed: they stay, for the next launch.
    public var kept = 0
    /// Whether the leftovers could not even be listed.
    public var unreadable = false

    public init(imported: Int = 0, kept: Int = 0, unreadable: Bool = false) {
        self.imported = imported
        self.kept = kept
        self.unreadable = unreadable
    }
}

/// Brings into the CVs what earlier versions of the app kept of editor work nobody saved.
///
/// The editor saves by itself, so nothing is kept on the side any more. Edits an earlier version left behind are stored
/// at the next launch, once and without a question, as their restore plan says, and then removed: nobody loses them,
/// and no second copy of a CV is left on the device.
public protocol LeftoverEditsImportProtocol: Sendable {
    func importLeftovers() async -> LeftoverEditsImportReport
}

public struct LeftoverEditsImport: LeftoverEditsImportProtocol {
    private let leftovers: UnsavedEditsRepositoryProtocol
    private let cvs: CVManagementUseCaseProtocol
    private let recoveredName: @Sendable (CVModel) -> String

    /// - Parameters:
    ///   - leftovers: The edits earlier versions kept.
    ///   - cvs: The CVs the edits go into.
    ///   - recoveredName: The name of the copy made when the stored CV changed after the edits were made on it.
    public init(
        leftovers: UnsavedEditsRepositoryProtocol,
        cvs: CVManagementUseCaseProtocol,
        recoveredName: @escaping @Sendable (CVModel) -> String
    ) {
        self.leftovers = leftovers
        self.cvs = cvs
        self.recoveredName = recoveredName
    }

    /// Stores each leftover, the oldest first, so that later edits of the same CV are applied after earlier ones.
    public func importLeftovers() async -> LeftoverEditsImportReport {
        let all: [UnsavedEdits]
        do {
            all = try await leftovers.allKept()
        } catch {
            return LeftoverEditsImportReport(unreadable: true)
        }
        var report = LeftoverEditsImportReport()
        for edits in all.sorted(by: { ($0.keptAt, $0.id.uuidString) < ($1.keptAt, $1.id.uuidString) }) {
            do {
                try await store(edits)
                try await leftovers.discard(editing: edits.id)
                report.imported += 1
            } catch {
                report.kept += 1
            }
        }
        return report
    }

    // MARK: - Private Methods

    private func store(_ edits: UnsavedEdits) async throws {
        let stored = try await cvs.getCV(by: edits.cv.id)
        let storedCopy = try await cvs.getCV(by: edits.copyID)
        switch edits.restorePlan(over: stored, copy: storedCopy) {
        case .restoredAsCopy, .alreadySaved:
            return
        case .update:
            _ = try await cvs.updateCV(edits.cv)
        case .create:
            _ = try await cvs.storeNewCV(edits.cv)
        case .copy:
            let copy = edits.cv.copy(newId: edits.copyID, nameModifier: { _ in recoveredName(edits.cv) })
            _ = try await cvs.storeNewCV(copy)
        }
    }
}
