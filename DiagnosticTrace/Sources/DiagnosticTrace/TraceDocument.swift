import Foundation

/// The stored form of a run: JSON, schema 1, keys sorted and one value per line, so that two runs diff line by line. The
/// shared file is these bytes, never encoded again.
extension TraceRun {
    public static let schema = 1

    /// The run as its stored document.
    public func document() throws -> Data {
        try TraceJSON.encoder.encode(RunDocument(self))
    }

    /// Reads a run from its stored document.
    public init(document: Data) throws {
        let read = try JSONDecoder().decode(RunDocument.self, from: document)
        guard read.schema == Self.schema, let started = UTCTime.date(read.started) else { throw TraceDocumentError.unreadable }
        self.init(
            id: read.id,
            kind: read.kind,
            started: started,
            build: TraceBuild(
                appVersion: read.build.appVersion, build: read.build.build, distribution: read.build.distribution,
                osVersion: read.build.osVersion, deviceModel: read.build.deviceModel
            ),
            steps: try read.steps.map { try $0.step() },
            outcome: try read.outcome.map { try $0.outcome() }
        )
    }

    /// The name of the run's files, without extension: `run-<UTC start>-<kind>-<first 8 of the id>`. The names of a store's
    /// runs sort by their start.
    public var fileStem: String {
        "run-\(UTCTime.compact(started))-\(kind.rawValue)-\(id.uuidString.prefix(8).lowercased())"
    }
}

/// A document that does not hold a run of this schema.
public enum TraceDocumentError: Error, Equatable {
    case unreadable
}

enum TraceJSON {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

// MARK: - Documents

private struct RunDocument: Codable {
    struct Build: Codable {
        let appVersion, build, distribution, osVersion, deviceModel: String
    }

    let schema: Int
    let id: UUID
    let kind: TraceKind
    let started: String
    let build: Build
    let steps: [StepDocument]
    let outcome: OutcomeDocument?

    init(_ run: TraceRun) {
        schema = TraceRun.schema
        id = run.id
        kind = run.kind
        started = UTCTime.extended(run.started)
        build = Build(
            appVersion: run.build.appVersion, build: run.build.build, distribution: run.build.distribution,
            osVersion: run.build.osVersion, deviceModel: run.build.deviceModel
        )
        steps = run.steps.map(StepDocument.init)
        outcome = run.outcome.map(OutcomeDocument.init)
    }
}

private struct StepDocument: Codable {
    let sequence: Int
    let seconds: Double
    let name: TraceStepName
    let fields: [FieldDocument]

    init(_ step: TraceStep) {
        sequence = step.sequence
        seconds = Seconds.of(step.elapsed)
        name = step.name
        fields = step.fields.map(FieldDocument.init)
    }

    func step() throws -> TraceStep {
        TraceStep(sequence: sequence, elapsed: Seconds.duration(seconds), name: name, fields: try fields.map { try $0.field() })
    }
}

/// A field, with the one member its kind uses.
private struct FieldDocument: Codable {
    let key: String
    var text: String?
    var truncated: Bool?
    var length: Int?
    var count: Int?
    var flag: Bool?
    var seconds: Double?
    var token: String?

    init(_ field: TraceField) {
        key = field.key
        switch field.value {
        case .text(let value):
            text = value.text
            truncated = value.truncated
            length = value.originalLength
        case .count(let value): count = value
        case .flag(let value): flag = value
        case .duration(let value): seconds = Seconds.of(value)
        case .token(let value): token = value
        }
    }

    func field() throws -> TraceField {
        if let text, let truncated, let length {
            return TraceField(key: key, value: .text(TraceText(text: text, truncated: truncated, originalLength: length)))
        }
        if let count { return TraceField(key: key, value: .count(count)) }
        if let flag { return TraceField(key: key, value: .flag(flag)) }
        if let seconds { return TraceField(key: key, value: .duration(Seconds.duration(seconds))) }
        if let token { return TraceField(key: key, value: .token(token)) }
        throw TraceDocumentError.unreadable
    }
}

private struct OutcomeDocument: Codable {
    let result: String
    var code: String?

    init(_ outcome: TraceOutcome) {
        switch outcome {
        case .finished: result = "finished"
        case .failed(let code):
            result = "failed"
            self.code = code
        case .cancelled: result = "cancelled"
        }
    }

    func outcome() throws -> TraceOutcome {
        switch (result, code) {
        case ("finished", _): .finished
        case ("failed", let code?): .failed(code: code)
        case ("cancelled", _): .cancelled
        default: throw TraceDocumentError.unreadable
        }
    }
}

enum Seconds {
    static func of(_ duration: Duration) -> Double {
        let (seconds, attoseconds) = duration.components
        return Double(seconds) + Double(attoseconds) / 1e18
    }

    /// Reads seconds back to the nanosecond, so that a duration written from whole milliseconds reads back equal.
    static func duration(_ seconds: Double) -> Duration {
        .nanoseconds(Int64((seconds * 1e9).rounded()))
    }
}

// MARK: - Time

/// UTC time to the millisecond, written without a formatter so that it reads the same on every platform.
enum UTCTime {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    /// `2026-10-28T12:00:00.125Z`
    static func extended(_ date: Date) -> String {
        let (parts, millisecond) = split(date)
        return "\(pad(parts.year, 4))-\(pad(parts.month, 2))-\(pad(parts.day, 2))T"
            + "\(pad(parts.hour, 2)):\(pad(parts.minute, 2)):\(pad(parts.second, 2)).\(pad(millisecond, 3))Z"
    }

    /// `20261028T120000.125Z`, for a file name.
    static func compact(_ date: Date) -> String {
        let (parts, millisecond) = split(date)
        return "\(pad(parts.year, 4))\(pad(parts.month, 2))\(pad(parts.day, 2))T"
            + "\(pad(parts.hour, 2))\(pad(parts.minute, 2))\(pad(parts.second, 2)).\(pad(millisecond, 3))Z"
    }

    /// Reads the extended form back.
    static func date(_ text: String) -> Date? {
        let digits = text.split { !$0.isNumber }.compactMap { Int($0) }
        guard digits.count == 7, text.hasSuffix("Z") else { return nil }
        let components = DateComponents(year: digits[0], month: digits[1], day: digits[2], hour: digits[3], minute: digits[4], second: digits[5])
        return calendar.date(from: components).map { $0.addingTimeInterval(Double(digits[6]) / 1_000) }
    }

    private static func split(_ date: Date) -> (DateComponents, Int) {
        // To the nearest millisecond, not down: a date read back from its text is a hair under its millisecond, and cutting it
        // would give it the millisecond before, so a run would not find its own files by the name it computes from the document.
        let milliseconds = Int((date.timeIntervalSince1970 * 1_000).rounded())
        let (seconds, millisecond) = milliseconds.quotientAndRemainder(dividingBy: 1_000)
        let whole = Date(timeIntervalSince1970: Double(millisecond < 0 ? seconds - 1 : seconds))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: whole)
        return (parts, millisecond < 0 ? millisecond + 1_000 : millisecond)
    }

    private static func pad(_ value: Int?, _ width: Int) -> String {
        let text = String(value ?? 0)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }
}
