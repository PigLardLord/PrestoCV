import CVDesignCatalog
import DiagnosticLogging

extension LogCategory {
    /// The designs a CV is exported with: the sync of the bundled designs at launch.
    static let designs = LogCategory("designs")
}

/// Brings the designs that ship with the app into the design store at launch (`SyncBundledDesigns`), then reads what the
/// export and the look picker need: the default design and the installed designs.
/// - A sync that fails other than by cancellation is tolerated while the store gives the default design: a design that is
///   rejected, not rendered or not saved is left out, and a bundle or a store that failed leaves the designs installed
///   before. What the sync did is logged as counts.
/// - With no default design to give, the launch fails: `designStoreUnavailable` when the store could not be read or could
///   not save the default design, `bundledDesignsUnavailable` when the bundle could not be read or its default design was
///   refused.
/// - A design the store lists but cannot read is left out (`designs.unreadable`), and the launch goes on with the others. A
///   default design the store cannot read fails the launch with `designStoreUnavailable`.
/// - A cancelled launch is `designSyncInterrupted`, even when the cancellation is seen only once a store step returns (the
///   file store's lock wait does not end early when its caller is cancelled). The designs saved before it stay saved, so
///   the next launch does not render them again.
struct DesignBootstrap: Sendable {
    /// The design a CV that keeps none exports with: the default of version 1, and the first bundled design.
    static let defaultDesign = "professional"

    /// What the launch reads from the store once the sync is over.
    struct Designs: Sendable {
        /// The installed designs, in the store's order
        let installed: [DesignManifest]
        let defaultDesign: DesignManifest
    }

    let store: any DesignStore
    let source: any BundledDesignSource
    let gate: any DesignRenderingGate
    let logger: any DiagnosticLogger
    /// The clock the time of the sync is measured on
    let clock: any Clock<Duration>

    func run() async throws(CompositionFailure) -> Designs {
        let stopwatch = Stopwatch(started: clock)
        let missing = try await sync(stopwatch)
        let defaultDesign: DesignManifest, listed: [DesignManifest]
        do {
            defaultDesign = try await GetDesign(store: store)(id: Self.defaultDesign).manifest
            listed = try await ListDesigns(store: store)()
        } catch {
            throw failure(error, missing, stopwatch)
        }
        let installed = try await readable(listed, defaultDesign: defaultDesign, stopwatch)
        guard !Task.isCancelled else { throw interrupted(stopwatch) }
        return Designs(installed: installed, defaultDesign: defaultDesign)
    }

    /// What a launch fails with when the store does not give the default design or the list of the installed designs.
    private func failure(_ error: any Error, _ missing: Missing, _ stopwatch: Stopwatch) -> CompositionFailure {
        if error is CancellationError || Task.isCancelled { return interrupted(stopwatch) }
        if case DesignCatalogError.unknownDesign = error { return unavailable(missing, stopwatch) }
        return unavailable(.store, stopwatch)
    }

    /// The listed designs the store can read, in the store's order. A design it cannot read is left out and counted in the
    /// log, so one damaged package does not stop the launch; the default design was read already.
    private func readable(
        _ listed: [DesignManifest], defaultDesign: DesignManifest, _ stopwatch: Stopwatch
    ) async throws(CompositionFailure) -> [DesignManifest] {
        var readable: [DesignManifest] = []
        for manifest in listed {
            guard manifest.id != defaultDesign.id else {
                readable.append(defaultDesign)
                continue
            }
            do {
                readable.append(try await GetDesign(store: store)(id: manifest.id).manifest)
            } catch {
                if error is CancellationError || Task.isCancelled { throw interrupted(stopwatch) }
            }
        }
        if readable.count < listed.count {
            logger.notice(.designs, "designs.unreadable",
                .count("leftOut", listed.count - readable.count), .duration("elapsed", stopwatch.elapsed))
        }
        return readable
    }

    /// Runs the sync and logs what it did. Returns what to blame if the store then has no default design.
    private func sync(_ stopwatch: Stopwatch) async throws(CompositionFailure) -> Missing {
        let report: SyncReport
        do {
            report = try await SyncBundledDesigns(source: source, validator: DesignPackageValidator(), gate: gate, store: store)()
        } catch let error where error is CancellationError || Task.isCancelled {
            throw interrupted(stopwatch)
        } catch DesignCatalogError.bundledDesignsUnavailable {
            return syncFailed(.bundle, stopwatch)
        } catch {
            return syncFailed(.store, stopwatch)
        }
        let leftOut = !(report.rejected.isEmpty && report.notRendered.isEmpty && report.failed.isEmpty && report.conflicts.isEmpty)
        logger.log(LogEntry(level: leftOut ? .notice : .info, category: .designs, event: "designs.synced", fields: [
            .count("installed", report.installed.count), .count("upgraded", report.upgraded.count),
            .count("unchanged", report.unchanged.count), .count("adopted", report.adopted.count),
            .count("rejected", report.rejected.count), .count("notRendered", report.notRendered.count),
            .count("failed", report.failed.count), .count("conflicts", report.conflicts.count),
            .duration("elapsed", stopwatch.elapsed),
        ]))
        guard !Task.isCancelled else { throw interrupted(stopwatch) }
        return report.failed.contains(Self.defaultDesign) ? .store : .bundle
    }

    private func syncFailed(_ missing: Missing, _ stopwatch: Stopwatch) -> Missing {
        logger.notice(.designs, "designs.syncFailed", .token("reason", missing.code), .duration("elapsed", stopwatch.elapsed))
        return missing
    }

    private func interrupted(_ stopwatch: Stopwatch) -> CompositionFailure {
        logger.info(.designs, "designs.interrupted", .duration("elapsed", stopwatch.elapsed))
        return .designSyncInterrupted
    }

    private func unavailable(_ missing: Missing, _ stopwatch: Stopwatch) -> CompositionFailure {
        logger.error(.designs, "designs.unavailable", .token("failure", missing.code), .duration("elapsed", stopwatch.elapsed))
        return missing.failure
    }

    /// What a launch blames when the store has no default design to give.
    private enum Missing {
        /// The bundle could not be read, or its default design was refused
        case bundle
        /// The store could not be read, or could not save the default design
        case store

        var failure: CompositionFailure {
            switch self {
            case .bundle: .bundledDesignsUnavailable
            case .store: .designStoreUnavailable
            }
        }

        var code: StaticString {
            switch self {
            case .bundle: "bundledDesignsUnavailable"
            case .store: "designStoreUnavailable"
            }
        }
    }
}
