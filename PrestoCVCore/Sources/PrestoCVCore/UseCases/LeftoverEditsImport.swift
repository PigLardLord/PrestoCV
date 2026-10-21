import Foundation

/// What an import of leftover edits did.
public struct LeftoverEditsImportReport: Equatable, Sendable {
    /// The step of the import that failed.
    public enum Step: Equatable, Sendable {
        /// The folder of the leftovers could not be listed.
        case listing
        /// The edits of a leftover could not be stored.
        case storing
        /// The edits of a leftover are stored, and the file could not be removed.
        case removing
        /// The files that could not be read could not be marked as seen.
        case acknowledging
    }

    /// A step that failed, and why: the launch log tells a full disk from a locked file.
    public struct Failure: Equatable, Sendable {
        public let step: Step
        public let cause: AppError

        public init(step: Step, cause: AppError) {
            self.step = step
            self.cause = cause
        }
    }

    /// Leftovers whose edits the CVs hold now, and which were removed.
    public var imported = 0
    /// The steps that failed, in order. A leftover that could not be stored or removed stays for the next launch.
    public var failures: [Failure] = []
    /// Files of the folder that could not be read as edits. None of them is deleted: each stays where it is, to be
    /// read again, or is set aside, and is counted here once.
    public var unreadableFiles = 0

    /// Leftovers that stay for the next launch.
    public var keptCount: Int {
        failures.filter { $0.step == .storing || $0.step == .removing }.count
    }

    public init(imported: Int = 0, failures: [Failure] = [], unreadableFiles: Int = 0) {
        self.imported = imported
        self.failures = failures
        self.unreadableFiles = unreadableFiles
    }
}

/// Brings into the CVs what earlier versions of the app kept of editor work nobody saved.
///
/// The editor saves by itself, so nothing is kept on the side any more. Edits an earlier version left behind are stored
/// at the next launch, once and without a question, as their restore plan says, and then removed: nobody loses them,
/// and no second copy of a CV is left on the device.
public protocol LeftoverEditsImportProtocol: Sendable {
    /// - Throws: `CancellationError`, unchanged, when the import is cancelled: what is not stored stays for the next
    ///   launch.
    func importLeftovers() async throws(CancellationError) -> LeftoverEditsImportReport
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
    public func importLeftovers() async throws(CancellationError) -> LeftoverEditsImportReport {
        var report = LeftoverEditsImportReport()
        let listing: StorageLoadReport<UnsavedEdits>
        do {
            listing = try await leftovers.allKept()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            report.failures.append(.init(step: .listing, cause: Self.cause(of: error)))
            return report
        }
        report.unreadableFiles = listing.unreadableCount
        for edits in listing.items.sorted(by: { ($0.keptAt, $0.id.uuidString) < ($1.keptAt, $1.id.uuidString) }) {
            do {
                try await store(edits)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                report.failures.append(.init(step: .storing, cause: Self.cause(of: error)))
                continue
            }
            do {
                try await leftovers.discard(editing: edits.id)
                report.imported += 1
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                report.failures.append(.init(step: .removing, cause: Self.cause(of: error)))
            }
        }
        if listing.unreadableCount > 0 {
            // The people who read the log have been told once; the files stay where they were set aside
            do {
                try await leftovers.acknowledgeUnreadable()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                report.failures.append(.init(step: .acknowledging, cause: Self.cause(of: error)))
            }
        }
        return report
    }

    // MARK: - Private Methods

    private static func cause(of error: any Error) -> AppError {
        error as? AppError ?? .unknown(error.localizedDescription)
    }

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
