import DiagnosticTrace
import Foundation

/// The steps of one text import in the trace of a test build (ADR 0032): the text it read, what each section's rule kept
/// and dropped, the time it took and the CV it gave. Unlike `ImportLog`, it holds the text of the CV: the trace stays on
/// the device, and a closed gate keeps none of it.
struct ImportTrace {
    let run: any TraceRunRecording

    init(tracer: any DiagnosticTracer) {
        run = tracer.begin(.textImport)
    }

    func input(_ text: String) {
        guard run.isRecording else { return }
        run.record(.input, .token("source", "text"), .count("characters", text.unicodeScalars.count), .text("text", text))
    }

    /// One `check` step per section, one `removal` step per piece dropped, then the time and the final draft.
    func finished(_ reading: CVReader.Reading, elapsed: Duration) {
        // The section and removal analysis and the JSON are costly: a run that records nothing builds none of them
        guard run.isRecording else { return }
        let result = reading.result
        for step in Self.sectionSteps(reading) { run.record(.check, step) }
        for step in Self.removalSteps(result) { run.record(.removal, step) }
        run.record(.timing, .duration("elapsed", elapsed))
        run.record(
            .finalDraft, .text("cv", Self.json(result.cv.fields)), .token("language", result.language?.rawValue ?? "none"),
            .count("unplaced", result.unplaced.count), .count("leftOut", result.leftOut.count), .count("ungrounded", result.ungrounded.count)
        )
        run.finish(.finished)
    }

    /// The failure with its code, and the bound it reached; a cancellation as such.
    func failed(_ error: any Error, elapsed: Duration) {
        guard run.isRecording else { return }
        if error is CancellationError {
            run.record(.failure, .token("error", "cancelled"))
            run.record(.timing, .duration("elapsed", elapsed))
            run.finish(.cancelled)
            return
        }
        let code: String
        var fields: [TraceField] = []
        if let reached = error as? LimitReached {
            code = "\(reached.importError.logCode)"
            fields = [.token("error", code), .token("limit", "\(reached.logName)")]
        } else if let failure = error as? ImportError {
            code = "\(failure.logCode)"
            fields = [.token("error", code)]
        } else {
            code = "\(type(of: error))"
            fields = [.token("error", code), .text("description", String(describing: error))]
        }
        run.record(.failure, fields)
        run.record(.timing, .duration("elapsed", elapsed))
        run.finish(.failed(code: code))
    }

    // MARK: The steps

    /// Per section: its kind, its heading, its lines, the rule that read it, the values whose first span is in it and the
    /// text left unplaced in it. The values in no section, if any, come last.
    static func sectionSteps(_ reading: CVReader.Reading) -> [[TraceField]] {
        let document = reading.result.document
        var fields = reading.result.cv.fields.filter { !$0.spans.isEmpty }
        var steps: [[TraceField]] = []
        for section in reading.sections {
            let bounds = Self.bounds(of: section)
            let kept = fields.filter { field in bounds.map { $0.contains(field.spans[0].lowerBound) } ?? false }
            fields.removeAll { field in kept.contains(field) }
            let unplaced = reading.result.unplaced.count { unplaced in bounds.map { $0.contains(unplaced.span.lowerBound) } ?? false }
            var step: [TraceField] = [.token("section", section.kind.rawValue)]
            if let heading = section.headingSpan { step.append(.text("heading", document.text(of: heading))) }
            step += [
                .count("lineCount", section.blocks.count),
                .text("lines", section.blocks.map { document.text(of: $0.span) }.joined(separator: "\n")),
                .token("reader", CVReader.readerName(of: section.kind)),
                .count("values", kept.count),
            ]
            step += kept.map { .text("kept", describe($0)) }
            step.append(.count("unplaced", unplaced))
            steps.append(step)
        }
        if !fields.isEmpty {
            steps.append([.token("section", "none"), .count("values", fields.count)] + fields.map { .text("kept", describe($0)) })
        }
        return steps
    }

    /// The noise left out with its reason, the text no rule placed with its section, and the values the final gate refused.
    static func removalSteps(_ result: ImportResult) -> [[TraceField]] {
        var steps: [[TraceField]] = result.leftOut.map { piece in
            [.token("what", "leftOut"), .token("reason", piece.reason.rawValue), .text("text", piece.text)]
                + (piece.span.map { [.token("span", spanText($0))] } ?? [])
        }
        steps += result.unplaced.map { piece in
            [.token("what", "unplaced"), .token("section", piece.section.rawValue)]
                + (piece.heading.map { [.text("heading", $0)] } ?? [])
                + [.text("text", piece.text), .token("span", spanText(piece.span))]
        }
        steps += result.ungrounded.map { [.token("what", "ungrounded"), .text("text", $0)] }
        return steps
    }

    /// The scalars a section covers, from its heading to its last block.
    private static func bounds(of section: Section) -> Range<Int>? {
        let spans = ([section.heading?.span] + section.blocks.map(\.span)).compactMap { $0 }
        guard let lower = spans.map(\.lowerBound).min(), let upper = spans.map(\.upperBound).max() else { return nil }
        return lower..<Swift.max(upper, lower + 1)
    }

    /// `experience[0].employer: Ospedale Esempio @120-136`, with the check when there is one.
    private static func describe(_ field: ImportedField) -> String {
        var text = "\(field.path): \(field.value) @" + field.spans.map(spanText).joined(separator: ",")
        if let reading = field.reading { text += " reading=\(reading.rawValue)" }
        if let check = field.check { text += " check=\(check.rawValue)" }
        return text
    }

    private static func spanText(_ span: SourceSpan) -> String { "\(span.lowerBound)-\(span.upperBound)" }

    // MARK: The final draft

    private struct FieldDocument: Encodable {
        let path: String
        let value: String
        let spans: [[Int]]
        let reading: String?
        let check: String?
    }

    /// Every field of the CV as a JSON array, keys sorted, for a script to compare two runs. It is compact: the `kept`
    /// values of the sections are the readable form.
    static func json(_ fields: [ImportedField]) -> String {
        let documents = fields.map { field in
            FieldDocument(
                path: field.path, value: field.value, spans: field.spans.map { [$0.lowerBound, $0.upperBound] },
                reading: field.reading?.rawValue, check: field.check?.rawValue
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return String(decoding: try encoder.encode(documents), as: UTF8.self)
        } catch {
            // Strings and numbers always encode: this marks a defect, not a CV
            return "unencodable: \(type(of: error))"
        }
    }
}
