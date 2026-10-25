import DiagnosticLogging

// MARK: - What the import logs (ADR 0030)

extension LogCategory {
    /// The import of a CV, from a PDF or a pasted text.
    static let importing = LogCategory("import")
}

/// A bound of `ImportLimits` that the reading reached. The reading stops there; the use case logs which bound it was,
/// then throws the `ImportError` that the app words.
struct LimitReached: Error, Equatable {
    enum Limit: Equatable {
        case bytes, pages, characters, words, lines, cells, steps
    }

    let limit: Limit

    init(_ limit: Limit) {
        self.limit = limit
    }

    /// The failure the person is told about: too many pages, or too large for any other bound.
    var importError: ImportError { limit == .pages ? .tooManyPages : .tooLarge }

    var logName: StaticString {
        switch limit {
        case .bytes: "bytes"
        case .pages: "pages"
        case .characters: "characters"
        case .words: "words"
        case .lines: "lines"
        case .cells: "cells"
        case .steps: "steps"
        }
    }
}

extension ImportError: LoggableError {
    public var logCode: StaticString {
        switch self {
        case .empty: "empty"
        case .tooLarge: "tooLarge"
        case .tooManyPages: "tooManyPages"
        case .encrypted: "encrypted"
        case .unreadable: "unreadable"
        case .noText: "noText"
        }
    }
}

extension SectionKind {
    /// The key of the kind in the log, which takes only static text.
    var logKey: StaticString {
        switch self {
        case .header: "header"
        case .personal: "personal"
        case .summary: "summary"
        case .experience: "experience"
        case .education: "education"
        case .skills: "skills"
        case .languages: "languages"
        case .certifications: "certifications"
        case .interests: "interests"
        case .projects: "projects"
        case .volunteering: "volunteering"
        case .references: "references"
        case .drivingLicence: "drivingLicence"
        case .additional: "additional"
        case .unknown: "unknown"
        }
    }
}

/// The entries of one import: what it read, what it could not place, and how it failed. Counts, kinds and times only:
/// no text of the CV, which stays on the device and out of the log.
struct ImportLog {
    /// What the person gave: a PDF or a pasted text.
    enum Source {
        case pdf, text

        var logName: StaticString {
            switch self {
            case .pdf: "pdf"
            case .text: "text"
            }
        }
    }

    let logger: any DiagnosticLogger
    let source: Source

    /// The sections recognised by kind, the headings and the text the rules could not place, then the size of what was
    /// read and the time it took.
    func finished(_ reading: CVReader.Reading, pages: Int?, elapsed: Duration) {
        let kinds = SectionKind.allCases.compactMap { kind -> LogField? in
            let count = reading.sections.count { $0.kind == kind }
            return count > 0 ? .count(kind.logKey, count) : nil
        }
        logger.log(LogEntry(level: .info, category: .importing, event: "import.sections", fields: kinds))
        let unknownHeadings = reading.sections.count { $0.kind == .unknown && $0.heading != nil }
        let unplaced = reading.result.unplaced.count
        if unknownHeadings > 0 || unplaced > 0 {
            logger.notice(.importing, "import.unrecognised", .count("headings", unknownHeadings), .count("unplaced", unplaced))
        }
        var fields: [LogField] = [.token("kind", source.logName)]
        if let pages { fields.append(.count("pages", pages)) }
        fields += [
            .count("characters", reading.result.document.scalarCount), .count("sections", reading.sections.count),
            .duration("elapsed", elapsed),
        ]
        logger.log(LogEntry(level: .info, category: .importing, event: "import.finished", fields: fields))
    }

    /// Logs a failure and gives the error to throw: a reached limit becomes the `ImportError` the app words, and a
    /// cancellation passes as it is.
    func failed(_ error: any Error, elapsed: Duration) -> any Error {
        if error is CancellationError {
            logger.info(.importing, "import.cancelled", .token("kind", source.logName), .duration("elapsed", elapsed))
            return error
        }
        var fields: [LogField] = [.token("kind", source.logName)]
        let thrown: any Error
        if let reached = error as? LimitReached {
            thrown = reached.importError
            fields += [.error(reached.importError), .token("limit", reached.logName)]
        } else {
            thrown = error
            fields.append(.error(error))
        }
        fields.append(.duration("elapsed", elapsed))
        logger.log(LogEntry(level: .error, category: .importing, event: "import.failed", fields: fields))
        return thrown
    }
}
