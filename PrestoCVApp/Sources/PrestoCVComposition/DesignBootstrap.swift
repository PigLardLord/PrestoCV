import CVDesignCatalog
import DiagnosticLogging
import PrestoCVIntegration

extension LogCategory {
    /// The designs a CV is exported with: the check of the bundled designs once the app is open.
    static let designs = LogCategory("designs")
}

/// The check of the designs that ship with the app (#566), over the design store, the bundled designs and the rendering
/// gate: `CheckedDesigns` runs it in the background once the app is open, so the launch never waits for it and never fails
/// because of it.
/// - `installed()` gives the designs the store holds before the check: they are offered at once. A design the store lists
///   but cannot read is left out (`designs.unreadable`); a store that cannot be read gives none.
/// - `check(decided:)` brings the bundled designs into the store (`SyncBundledDesigns`), the default design first, and tells
///   each one once the store holds its verdict, with the design the store then holds. A design that is rejected, not
///   rendered or not saved is told without a design, unless the store still holds one of that identifier from before. What
///   the sync did is logged as counts.
/// - A bundled design the store lists but cannot read is written again by the sync (`repaired`), after the bundled package
///   validates and renders. A design the person installed is never replaced.
/// - When the store then gives no default design, the check logs why (`designs.unavailable`): the export offers to try
///   again, and writing goes on.
/// - A cancelled check is `designs.interrupted`, even when the cancellation is seen only once a store step returns (the
///   file store's lock wait does not end early when its caller is cancelled). The designs saved before it stay saved, so
///   the next launch offers them at once and does not render them again.
struct DesignBootstrap: DesignChecking {
    /// The design a CV that keeps none exports with: the default of version 1, and the first bundled design checked.
    static let defaultDesign = "professional"

    let store: any DesignStore
    let source: any BundledDesignSource
    let gate: any DesignRenderingGate
    let logger: any DiagnosticLogger
    /// The clock the time of the check is measured on
    let clock: any Clock<Duration>

    @concurrent func installed() async -> [ValidatedDesign] {
        let stopwatch = Stopwatch(started: clock)
        let listed: [DesignManifest]
        do {
            listed = try await ListDesigns(store: store)()
        } catch {
            return []
        }
        var readable: [ValidatedDesign] = [], leftOut = 0
        for manifest in listed {
            switch await read(manifest.id) {
            case .held(let design): readable.append(design)
            case .unreadable: leftOut += 1
            case .absent: continue
            }
        }
        if leftOut > 0 { unreadable(leftOut, stopwatch) }
        return readable
    }

    @concurrent func check(decided: @Sendable (_ id: String, _ design: ValidatedDesign?) async -> Void) async {
        let stopwatch = Stopwatch(started: clock)
        var leftOut = 0
        let missing: Missing
        do {
            let report = try await SyncBundledDesigns(source: source, validator: DesignPackageValidator(), gate: gate, store: store)(
                first: Self.defaultDesign
            ) { id in
                let read = await read(id)
                if case .unreadable = read { leftOut += 1 }
                await decided(id, read.design)
            }
            synced(report, stopwatch)
            missing = report.failed.contains(Self.defaultDesign) ? .store : .bundle
        } catch let error where error is CancellationError || Task.isCancelled {
            interrupted(stopwatch)
            return
        } catch DesignCatalogError.bundledDesignsUnavailable {
            missing = syncFailed(.bundle, stopwatch)
        } catch {
            missing = syncFailed(.store, stopwatch)
        }
        if leftOut > 0 { unreadable(leftOut, stopwatch) }
        guard !Task.isCancelled else {
            interrupted(stopwatch)
            return
        }
        await checkDefaultDesign(missing, stopwatch)
    }

    /// Logs why the store gives no default design once the sync is over, if it gives none.
    @concurrent private func checkDefaultDesign(_ missing: Missing, _ stopwatch: Stopwatch) async {
        do {
            _ = try await GetDesign(store: store)(id: Self.defaultDesign)
        } catch let error where error is CancellationError || Task.isCancelled {
            interrupted(stopwatch)
        } catch DesignCatalogError.unknownDesign {
            unavailable(missing, stopwatch)
        } catch {
            unavailable(.store, stopwatch)
        }
    }

    /// The design the store holds under the identifier, read as the export reads it.
    @concurrent private func read(_ id: String) async -> Read {
        do {
            return .held(try await GetDesign(store: store)(id: id))
        } catch let error where error is CancellationError || Task.isCancelled {
            return .absent
        } catch DesignCatalogError.unknownDesign {
            return .absent
        } catch {
            return .unreadable
        }
    }

    private func synced(_ report: SyncReport, _ stopwatch: Stopwatch) {
        let leftOut = !(report.rejected.isEmpty && report.notRendered.isEmpty && report.failed.isEmpty && report.conflicts.isEmpty)
        logger.log(LogEntry(level: leftOut ? .notice : .info, category: .designs, event: "designs.synced", fields: [
            .count("installed", report.installed.count), .count("upgraded", report.upgraded.count),
            .count("unchanged", report.unchanged.count), .count("adopted", report.adopted.count),
            .count("repaired", report.repaired.count),
            .count("rejected", report.rejected.count), .count("notRendered", report.notRendered.count),
            .count("failed", report.failed.count), .count("conflicts", report.conflicts.count),
            .duration("elapsed", stopwatch.elapsed),
        ]))
    }

    private func syncFailed(_ missing: Missing, _ stopwatch: Stopwatch) -> Missing {
        logger.notice(.designs, "designs.syncFailed", .token("reason", missing.code), .duration("elapsed", stopwatch.elapsed))
        return missing
    }

    private func unreadable(_ leftOut: Int, _ stopwatch: Stopwatch) {
        logger.notice(.designs, "designs.unreadable", .count("leftOut", leftOut), .duration("elapsed", stopwatch.elapsed))
    }

    private func interrupted(_ stopwatch: Stopwatch) {
        logger.info(.designs, "designs.interrupted", .duration("elapsed", stopwatch.elapsed))
    }

    private func unavailable(_ missing: Missing, _ stopwatch: Stopwatch) {
        logger.error(.designs, "designs.unavailable", .token("failure", missing.code), .duration("elapsed", stopwatch.elapsed))
    }

    /// What the store gave for one identifier.
    private enum Read {
        case held(ValidatedDesign)
        /// The store holds no design of that identifier, or the read was cancelled
        case absent
        /// The store lists the design but cannot read it
        case unreadable

        var design: ValidatedDesign? {
            guard case .held(let design) = self else { return nil }
            return design
        }
    }

    /// What the check blames when the store gives no default design.
    private enum Missing {
        /// The bundle could not be read, or its default design was refused
        case bundle
        /// The store could not be read, or could not save the default design
        case store

        var code: StaticString {
            switch self {
            case .bundle: "bundledDesignsUnavailable"
            case .store: "designStoreUnavailable"
            }
        }
    }
}
