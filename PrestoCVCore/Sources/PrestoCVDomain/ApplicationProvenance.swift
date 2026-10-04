import Foundation

/// The opaque identifier of the job that ran a tailoring. It is the one provenance value that a repository reads: it
/// checks it under its lock, so that creating an application is idempotent per job (#188). The domain does not interpret it.
public struct JobID: Hashable, Sendable {
    public static let maxBytes = 256
    public let raw: String
    public init(_ raw: String) throws(ApplicationError) { self.raw = try ApplicationTextRule.required(raw, .jobID, maxBytes: Self.maxBytes) }
}

/// Where an application came from, as plain values that Authoring stores, bounds and gives back, and does not interpret
/// (ADR 0019). It never holds Tailoring's types (R1): `PrestoCVIntegration` maps them. It describes the result as the
/// tailoring produced it, not the CV after the user's edits.
///
/// The one thing it checks beyond bounds is that its positions point inside what they point into: a statement of the stored
/// snapshot, a question and its answer. The positions of a tailored line are the tailored CV's as produced, and the user's
/// edits can move them, so they are only required to be non-negative.
public struct ApplicationProvenance: Hashable, Sendable {
    public enum Limits {
        public static let items = 500, lineSources = 40_000, sourcesPerLine = 200, questionValues = 20
        public static let statementBytes = 40_000, reportBytes = 10_000, answerBytes = 4_000, valueBytes = 10_000, identifierBytes = 64
    }

    /// The statements of one experience of the source CV, in order. A statement is one line of the experience's description,
    /// as written, without its leading bullet.
    public struct SourceExperience: Hashable, Sendable {
        public let statements: [String]
        public init(statements: [String]) throws(ApplicationError) {
            self.statements = try ApplicationTextRule.list(statements, .statement, maxCount: Limits.items, maxBytes: Limits.statementBytes)
        }
    }

    /// A statement of the stored snapshot: experience *n*, line *m*.
    public struct StatementPosition: Hashable, Sendable {
        public let experience: Int, line: Int
        public init(experience: Int, line: Int) { self.experience = experience; self.line = line }
    }

    /// What the tailoring reports: the one argument the CV makes, and what it cut, moved and reworded.
    public struct Report: Hashable, Sendable {
        public let argument: String
        public let cut: [String], moved: [String], reworded: [String]
        public init(argument: String, cut: [String] = [], moved: [String] = [], reworded: [String] = []) throws(ApplicationError) {
            self.argument = try ApplicationTextRule.trimmed(argument, .reportArgument, maxBytes: Limits.reportBytes, multiline: true)
            func entries(_ texts: [String]) throws(ApplicationError) -> [String] {
                try ApplicationTextRule.list(texts, .reportEntry, maxCount: Limits.items, maxBytes: Limits.reportBytes, multiline: true)
            }
            self.cut = try entries(cut); self.moved = try entries(moved); self.reworded = try entries(reworded)
        }
    }

    /// What a question is about: an experience of the snapshot, the skills, the summary or a letter field.
    public enum QuestionScope: Hashable, Sendable { case experience(Int), skills, summary, letterField(LetterDefaults.Field) }

    /// A question that the tailoring asked, as the code and the values Tailoring gives, which the app words (R13), and the
    /// user's answer. A skipped question has no answer and stays a gap.
    public struct Question: Hashable, Sendable {
        public let code: String
        public let values: [String]
        public let scope: QuestionScope
        public let answer: String?
        public init(code: String, values: [String] = [], scope: QuestionScope, answer: String? = nil) throws(ApplicationError) {
            self.code = try ApplicationTextRule.required(code, .questionCode, maxBytes: Limits.identifierBytes)
            self.values = try ApplicationTextRule.list(values, .questionValue, maxCount: Limits.questionValues, maxBytes: Limits.valueBytes)
            self.scope = scope
            self.answer = try ApplicationTextRule.optional(answer, .answer, maxBytes: Limits.answerBytes, multiline: true)
        }
    }

    /// What one line of the tailored CV, as produced, names as its sources: statements of the snapshot, and answers.
    public struct LineSources: Hashable, Sendable {
        public let experience: Int, line: Int
        public let statements: [StatementPosition]
        /// Positions into `questions`.
        public let answers: [Int]
        public init(experience: Int, line: Int, statements: [StatementPosition] = [], answers: [Int] = []) {
            self.experience = experience; self.line = line; self.statements = statements; self.answers = answers
        }
    }

    public let jobID: JobID
    /// The CV the tailoring started from.
    public let sourceCV: CVID
    /// The snapshot the tailoring used, as its statements: the positions of `lineSources` point into it.
    public let snapshot: [SourceExperience]
    public let report: Report
    public let questions: [Question]
    /// The override of the letter defaults that the tailoring was made with, and the defaults as the snapshot held them,
    /// after the override: so a kept application says what its letter was held to, whatever the person's defaults become.
    public let letterOverride: LetterDefaults, letterDefaults: LetterDefaults
    public let promptVersion: String
    /// The aliases of the attempt that passed, never the names of a provider or a model (ADR 0015).
    public let providerAlias: String, modelAlias: String
    public let lineSources: [LineSources]

    public init(jobID: JobID, sourceCV: CVID, snapshot: [SourceExperience], report: Report, questions: [Question], letterOverride: LetterDefaults,
                letterDefaults: LetterDefaults, promptVersion: String, providerAlias: String, modelAlias: String,
                lineSources: [LineSources]) throws(ApplicationError) {
        guard snapshot.count <= Limits.items else { throw .tooMany(.snapshot) }
        guard questions.count <= Limits.items else { throw .tooMany(.questions) }
        guard lineSources.count <= Limits.lineSources else { throw .tooMany(.lineSources) }
        for field in LetterDefaults.Field.allCases where !letterOverride.value(of: field).isEmpty {
            guard letterDefaults.value(of: field) == letterOverride.value(of: field) else { throw .overrideNotApplied(field) }
        }
        for question in questions {
            if case .experience(let position) = question.scope, !snapshot.indices.contains(position) { throw .invalidReference(.questions) }
        }
        for sources in lineSources {
            guard sources.experience >= 0, sources.line >= 0 else { throw .invalidReference(.lineSources) }
            guard sources.statements.count <= Limits.sourcesPerLine else { throw .tooMany(.statementReference) }
            guard sources.answers.count <= Limits.sourcesPerLine else { throw .tooMany(.answerReference) }
            for p in sources.statements where !(snapshot.indices.contains(p.experience) && snapshot[p.experience].statements.indices.contains(p.line)) {
                throw .invalidReference(.statementReference)
            }
            for a in sources.answers where !(questions.indices.contains(a) && questions[a].answer != nil) { throw .invalidReference(.answerReference) }
        }
        self.jobID = jobID; self.sourceCV = sourceCV; self.snapshot = snapshot; self.report = report; self.questions = questions
        self.letterOverride = letterOverride; self.letterDefaults = letterDefaults
        self.promptVersion = try ApplicationTextRule.required(promptVersion, .promptVersion, maxBytes: Limits.identifierBytes)
        self.providerAlias = try ApplicationTextRule.required(providerAlias, .providerAlias, maxBytes: Limits.identifierBytes)
        self.modelAlias = try ApplicationTextRule.required(modelAlias, .modelAlias, maxBytes: Limits.identifierBytes)
        self.lineSources = lineSources
    }
}
