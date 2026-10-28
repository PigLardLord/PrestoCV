import Foundation

/// The plain text of a run, for a person to read: its header, then each step in order with its values. It is a function of
/// the run alone, so the stored summary and the preview are the same text.
public enum TraceSummary {
    /// The most characters of a text the summary shows; the document keeps the whole text.
    public static let textLimit = 300

    public static func text(of run: TraceRun) -> String {
        var lines = [
            "\(title(of: run.kind)) \(run.id.uuidString)",
            "Started: \(UTCTime.extended(run.started))",
            "App \(run.build.appVersion) (\(run.build.build)), \(run.build.distribution), \(run.build.osVersion), \(run.build.deviceModel)",
            "Outcome: \(describe(run.outcome))",
            "",
        ]
        for step in run.steps {
            lines.append("#\(step.sequence) +\(seconds(step.elapsed)) \(step.name.rawValue)")
            lines += step.fields.map { "  \($0.key): \(describe($0.value))" }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// The name of a kind of run, in the report's own language, English.
    public static func title(of kind: TraceKind) -> String {
        switch kind {
        case .aiDraft: "AI draft"
        case .textImport: "Text import"
        }
    }

    private static func describe(_ outcome: TraceOutcome?) -> String {
        switch outcome {
        case .finished: "finished"
        case .failed(let code): "failed (\(code))"
        case .cancelled: "cancelled"
        case nil: "open"
        }
    }

    private static func describe(_ value: TraceValue) -> String {
        switch value {
        case .text(let text):
            let cut = text.text.count > textLimit
            let shown = (cut ? String(text.text.prefix(textLimit)) + "…" : text.text).split(separator: "\n", omittingEmptySubsequences: false)
                .joined(separator: "\\n")
            return "\"\(shown)\"" + (cut || text.truncated ? " (\(text.originalLength) bytes)" : "")
        case .count(let count): return String(count)
        case .flag(let flag): return flag ? "true" : "false"
        case .duration(let duration): return seconds(duration)
        case .token(let token): return token
        }
    }

    /// Seconds with three decimals: `1.250s`.
    private static func seconds(_ duration: Duration) -> String {
        let milliseconds = Int((Seconds.of(duration) * 1_000).rounded())
        let (whole, part) = milliseconds.quotientAndRemainder(dividingBy: 1_000)
        let digits = String(abs(part))
        return "\(whole).\(String(repeating: "0", count: 3 - digits.count))\(digits)s"
    }
}

/// Which runs a store keeps: the newest ones, by the names of their files, which sort by start time.
public enum TraceRetention {
    public static let kept = 10

    /// The stems of the runs to remove, newest first.
    public static func expired(_ stems: [String]) -> [String] {
        Array(stems.sorted(by: >).dropFirst(kept))
    }
}

/// The log entries that came when no run of their kind was open: the last 200, kept across launches.
public enum TraceSessionLog {
    public static let kept = 200
    public static let fileName = "session-events.json"

    public static func appending(_ events: [TraceSessionEvent], to existing: [TraceSessionEvent]) -> [TraceSessionEvent] {
        Array((existing + events).suffix(kept))
    }

    public static func document(_ events: [TraceSessionEvent]) throws -> Data {
        try TraceJSON.encoder.encode(SessionDocument(schema: TraceRun.schema, events: events.map(EventDocument.init)))
    }

    public static func events(document: Data) throws -> [TraceSessionEvent] {
        let read = try JSONDecoder().decode(SessionDocument.self, from: document)
        guard read.schema == TraceRun.schema else { throw TraceDocumentError.unreadable }
        return try read.events.map { event in
            guard let time = UTCTime.date(event.time) else { throw TraceDocumentError.unreadable }
            return TraceSessionEvent(time: time, category: event.category, level: event.level, line: event.line)
        }
    }

    private struct SessionDocument: Codable {
        let schema: Int
        let events: [EventDocument]
    }

    private struct EventDocument: Codable {
        let time, category, level, line: String

        init(_ event: TraceSessionEvent) {
            time = UTCTime.extended(event.time)
            category = event.category
            level = event.level
            line = event.line
        }
    }
}
