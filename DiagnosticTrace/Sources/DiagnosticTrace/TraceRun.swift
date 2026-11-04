import Foundation

/// What a run traces: one AI draft, or one import of pasted text.
public enum TraceKind: String, Sendable, Codable, CaseIterable {
    case aiDraft, textImport
}

/// The name of a step, from a closed set, so that a script can compare runs and no stage is added without a name.
public enum TraceStepName: String, Sendable, Codable, CaseIterable {
    /// What the person gave: the description, or the pasted text.
    case input
    /// Whether the model can answer, and why not.
    case availability
    /// The language of the input, and whether the device has its data.
    case languageData
    /// What was sent to the model.
    case request
    /// What the model answered, as it answered it.
    case response
    /// A check and its verdicts, such as the claim check of a batch, or a section the import read.
    case check
    /// What a stage removed or changed, or what the import left out.
    case removal
    /// The time a stage took.
    case timing
    /// The draft the person sees.
    case finalDraft
    /// A log entry, mirrored into the run (ADR 0030 events).
    case event
    /// An error, with the text the framework gave.
    case failure
    /// The run reached its size cap: the steps after it are counted, not kept.
    case truncated
}

/// A text of a step, cut at 32 KB of UTF-8 on a character boundary, with its original length.
public struct TraceText: Sendable, Equatable {
    /// The most bytes of UTF-8 a text keeps.
    public static let limit = 32 * 1024

    public let text: String
    /// Whether the text was cut.
    public let truncated: Bool
    /// The length of the original text, in bytes of UTF-8.
    public let originalLength: Int

    public init(text: String, truncated: Bool, originalLength: Int) {
        self.text = text
        self.truncated = truncated
        self.originalLength = originalLength
    }

    /// The text, cut at the limit when it is longer.
    public init(_ text: String) {
        let length = text.utf8.count
        guard length > Self.limit else {
            self.init(text: text, truncated: false, originalLength: length)
            return
        }
        var used = 0
        var end = text.startIndex
        for character in text {
            let size = character.utf8.count
            guard used + size <= Self.limit else { break }
            used += size
            end = text.index(after: end)
        }
        self.init(text: String(text[..<end]), truncated: true, originalLength: length)
    }
}

/// A value of a step. Unlike a log field, it may hold text: the trace exists to show what the person typed and what the
/// app made of it (ADR 0032).
public enum TraceValue: Sendable, Equatable {
    case text(TraceText)
    case count(Int)
    case flag(Bool)
    case duration(Duration)
    /// A word chosen in code, such as a case name.
    case token(String)
}

/// One value of a step, under a key chosen in code.
public struct TraceField: Sendable, Equatable {
    public let key: String
    public let value: TraceValue

    init(key: String, value: TraceValue) {
        self.key = key
        self.value = value
    }

    public static func text(_ key: StaticString, _ value: String) -> TraceField {
        TraceField(key: key.description, value: .text(TraceText(value)))
    }

    public static func count(_ key: StaticString, _ value: Int) -> TraceField {
        TraceField(key: key.description, value: .count(value))
    }

    public static func flag(_ key: StaticString, _ value: Bool) -> TraceField {
        TraceField(key: key.description, value: .flag(value))
    }

    public static func duration(_ key: StaticString, _ value: Duration) -> TraceField {
        TraceField(key: key.description, value: .duration(value))
    }

    public static func token(_ key: StaticString, _ value: String) -> TraceField {
        TraceField(key: key.description, value: .token(value))
    }
}

/// One step of a run: its number in the run, the time since the run began, its name and its values in order.
public struct TraceStep: Sendable, Equatable {
    public let sequence: Int
    public let elapsed: Duration
    public let name: TraceStepName
    public let fields: [TraceField]

    public init(sequence: Int, elapsed: Duration, name: TraceStepName, fields: [TraceField]) {
        self.sequence = sequence
        self.elapsed = elapsed
        self.name = name
        self.fields = fields
    }
}

/// How a run ended.
public enum TraceOutcome: Sendable, Equatable {
    case finished
    /// Stopped by an error, with a word chosen in code that says where.
    case failed(code: String)
    case cancelled
}

/// The build that made a run, so that a report says which app and which device it comes from.
public struct TraceBuild: Sendable, Equatable {
    public let appVersion: String
    public let build: String
    /// How the app was installed, as the distribution answered: `sandbox` for TestFlight, `debug` for a Debug build.
    public let distribution: String
    /// The system and its version, such as `iOS 26.5`.
    public let osVersion: String
    /// The model identifier, such as `iPhone17,1`.
    public let deviceModel: String

    public init(appVersion: String, build: String, distribution: String, osVersion: String, deviceModel: String) {
        self.appVersion = appVersion
        self.build = build
        self.distribution = distribution
        self.osVersion = osVersion
        self.deviceModel = deviceModel
    }
}

/// One AI draft or one import, step by step.
public struct TraceRun: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let kind: TraceKind
    public let started: Date
    public let build: TraceBuild
    public var steps: [TraceStep]
    /// How the run ended; nil while it is open.
    public var outcome: TraceOutcome?

    public init(id: UUID, kind: TraceKind, started: Date, build: TraceBuild, steps: [TraceStep], outcome: TraceOutcome?) {
        self.id = id
        self.kind = kind
        self.started = started
        self.build = build
        self.steps = steps
        self.outcome = outcome
    }
}

/// A log entry, as the tracing logger hands it to the tracer: its line carries no CV content (ADR 0030).
public struct TraceEvent: Sendable, Equatable {
    /// The kind of run the entry's category belongs to, or nil when it belongs to none.
    public let kind: TraceKind?
    public let category: String
    public let level: String
    public let line: String

    public init(kind: TraceKind?, category: String, level: String, line: String) {
        self.kind = kind
        self.category = category
        self.level = level
        self.line = line
    }
}

/// A log entry that came when no run of its kind was open, kept in the session's events with its time.
public struct TraceSessionEvent: Sendable, Equatable {
    public let time: Date
    public let category: String
    public let level: String
    public let line: String

    public init(time: Date, category: String, level: String, line: String) {
        self.time = time
        self.category = category
        self.level = level
        self.line = line
    }
}
