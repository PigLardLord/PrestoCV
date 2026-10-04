import Foundation
import PrestoCVDomain

/// The stored form of an application, schema 1: a DTO separate from the domain (ADR 0009, ADR 0019, R12). The envelope is
/// frozen: `schemaVersion` is a top-level integer in every future version, and the revision and the times are stored once,
/// here, for the application and for the CV inside it. Decoding is strict, and every text must be in the canonical form the
/// domain produces from it. The CV has no envelope of its own, so `cv` holds its identity beside its content, which is the
/// same `CVContentV1` that `CVFileV1` writes.
struct ApplicationFileV1: Codable, Equatable {
    static let version = 1

    let schemaVersion: Int
    let id: UUID
    let revision: Int
    let createdAt: Date, updatedAt: Date
    let advert: AdvertV1
    let letter: LetterV1
    let provenance: ProvenanceV1
    let cv: TailoredCVV1

    struct AdvertV1: Codable, Equatable { let company: String, role: String, text: String }
    struct RecipientV1: Codable, Equatable {
        let company: String?, contactName: String?, formOfAddress: String, title: String?, surname: String?, role: String?, address: [String]
    }
    struct LetterV1: Codable, Equatable {
        let recipient: RecipientV1
        let reference: String?, position: String?, subject: String?, opening: String?, paragraphs: [String], closing: String?, attachments: [String]
    }
    struct TailoredCVV1: Codable, Equatable { let id: UUID, content: CVContentV1 }

    struct SnapshotExperienceV1: Codable, Equatable { let statements: [String] }
    struct ReportV1: Codable, Equatable { let argument: String, cut: [String], moved: [String], reworded: [String] }
    struct ScopeV1: Codable, Equatable { let kind: String, experience: Int?, field: String? }
    struct QuestionV1: Codable, Equatable { let code: String, values: [String], scope: ScopeV1, answer: String? }
    struct StatementPositionV1: Codable, Equatable { let experience: Int, line: Int }
    struct LineSourcesV1: Codable, Equatable { let experience: Int, line: Int, statements: [StatementPositionV1], answers: [Int] }
    struct ProvenanceV1: Codable, Equatable {
        let jobID: String
        let sourceCV: UUID
        let snapshot: [SnapshotExperienceV1]
        let report: ReportV1
        let questions: [QuestionV1]
        let letterOverride: LetterDefaultsContentV1, letterDefaults: LetterDefaultsContentV1
        let promptVersion: String, providerAlias: String, modelAlias: String
        let lineSources: [LineSourcesV1]
    }

    typealias Invalid = FileInvalid

    // MARK: Coding

    static func decode(_ data: Data) throws -> ApplicationFileV1 { try StoredJSON.decode(ApplicationFileV1.self, from: data) }

    func encoded() throws -> Data { try StoredJSON.encode(self) }

    /// The strict read of a stored application: the file must decode, and every value in it must be valid.
    static func read(_ data: Data) throws(Invalid) -> Application {
        let file: ApplicationFileV1
        do { file = try decode(data) } catch { throw Invalid(reason: "not an application file") }
        return try file.toDomain()
    }

    // MARK: From the domain

    init(_ application: Application, createdAt: Date, updatedAt: Date) {
        schemaVersion = Self.version; id = application.id.raw; revision = application.revision
        self.createdAt = createdAt; self.updatedAt = updatedAt
        let advert = application.advert
        self.advert = AdvertV1(company: advert.company, role: advert.role, text: advert.text)
        let letter = application.letter, recipient = letter.recipient
        self.letter = LetterV1(
            recipient: RecipientV1(company: recipient.company, contactName: recipient.contactName, formOfAddress: recipient.formOfAddress.rawValue,
                                   title: recipient.title, surname: recipient.surname, role: recipient.role, address: recipient.address),
            reference: letter.reference, position: letter.position, subject: letter.subject, opening: letter.opening,
            paragraphs: letter.paragraphs, closing: letter.closing, attachments: letter.attachments)
        provenance = Self.stored(application.provenance)
        cv = TailoredCVV1(id: application.cv.id.raw, content: CVContentV1(application.cv))
    }

    private static func stored(_ p: ApplicationProvenance) -> ProvenanceV1 {
        ProvenanceV1(
            jobID: p.jobID.raw, sourceCV: p.sourceCV.raw, snapshot: p.snapshot.map { SnapshotExperienceV1(statements: $0.statements) },
            report: ReportV1(argument: p.report.argument, cut: p.report.cut, moved: p.report.moved, reworded: p.report.reworded),
            questions: p.questions.map { QuestionV1(code: $0.code, values: $0.values, scope: stored($0.scope), answer: $0.answer) },
            letterOverride: LetterDefaultsContentV1(p.letterOverride), letterDefaults: LetterDefaultsContentV1(p.letterDefaults),
            promptVersion: p.promptVersion, providerAlias: p.providerAlias, modelAlias: p.modelAlias,
            lineSources: p.lineSources.map { sources in
                LineSourcesV1(experience: sources.experience, line: sources.line,
                              statements: sources.statements.map { StatementPositionV1(experience: $0.experience, line: $0.line) }, answers: sources.answers)
            })
    }

    private static func stored(_ scope: ApplicationProvenance.QuestionScope) -> ScopeV1 {
        switch scope {
        case .experience(let position): ScopeV1(kind: "experience", experience: position, field: nil)
        case .skills: ScopeV1(kind: "skills", experience: nil, field: nil)
        case .summary: ScopeV1(kind: "summary", experience: nil, field: nil)
        case .letterField(let field): ScopeV1(kind: "letterField", experience: nil, field: field.rawValue)
        }
    }

    // MARK: To the domain

    func toDomain() throws(Invalid) -> Application {
        guard schemaVersion == Self.version else { throw Invalid(reason: "version") }
        guard (1...Int(Int32.max)).contains(revision) else { throw Invalid(reason: "revision") }   // no overflow on +1
        let tailored = try cv.content.toCV(id: CVID(cv.id), revision: revision, createdAt: createdAt, updatedAt: updatedAt)
        // Codes are never defaulted: one that is not known is corrupt.
        guard let form = FormOfAddress(rawValue: letter.recipient.formOfAddress) else { throw Invalid(reason: "form of address") }
        var scopes: [ApplicationProvenance.QuestionScope] = []
        for question in provenance.questions { scopes.append(try Self.scope(question.scope)) }
        let override = try provenance.letterOverride.toDomain(), held = try provenance.letterDefaults.toDomain()
        let application = try Self.domain { () throws(ApplicationError) -> Application in
            try Application(id: ApplicationID(id), revision: revision, createdAt: createdAt, updatedAt: updatedAt, cv: tailored,
                            letter: letterToDomain(form), advert: Advert(company: advert.company, role: advert.role, text: advert.text),
                            provenance: provenanceToDomain(scopes: scopes, override: override, defaults: held))
        }
        // Every text of the application is exactly what the domain produces from it: trimmed, and an empty optional is absent.
        let canonical = ApplicationFileV1(application, createdAt: createdAt, updatedAt: updatedAt)
        guard canonical.advert == advert, canonical.letter == letter, canonical.provenance == provenance else { throw Invalid(reason: "not canonical") }
        return application
    }

    private static func domain<T>(_ make: () throws(ApplicationError) -> T) throws(Invalid) -> T {
        do { return try make() } catch { throw Invalid(reason: "\(error)") }
    }

    private static func scope(_ stored: ScopeV1) throws(Invalid) -> ApplicationProvenance.QuestionScope {
        switch (stored.kind, stored.experience, stored.field) {
        case ("experience", let position?, nil): return .experience(position)
        case ("skills", nil, nil): return .skills
        case ("summary", nil, nil): return .summary
        case ("letterField", nil, let name?):
            guard let field = LetterDefaults.Field(rawValue: name) else { throw Invalid(reason: "question scope") }
            return .letterField(field)
        default: throw Invalid(reason: "question scope")
        }
    }

    private func letterToDomain(_ form: FormOfAddress) throws(ApplicationError) -> CoverLetter {
        let r = letter.recipient
        let recipient = try LetterRecipient(company: r.company, contactName: r.contactName, formOfAddress: form, title: r.title, surname: r.surname,
                                            role: r.role, address: r.address)
        return try CoverLetter(recipient: recipient, reference: letter.reference, position: letter.position, subject: letter.subject,
                               opening: letter.opening, paragraphs: letter.paragraphs, closing: letter.closing, attachments: letter.attachments)
    }

    private func provenanceToDomain(scopes: [ApplicationProvenance.QuestionScope], override: LetterDefaults,
                                    defaults: LetterDefaults) throws(ApplicationError) -> ApplicationProvenance {
        typealias P = ApplicationProvenance
        let p = provenance
        var snapshot: [P.SourceExperience] = []
        for experience in p.snapshot { snapshot.append(try P.SourceExperience(statements: experience.statements)) }
        let report = try P.Report(argument: p.report.argument, cut: p.report.cut, moved: p.report.moved, reworded: p.report.reworded)
        var questions: [P.Question] = []
        for (question, scope) in zip(p.questions, scopes) {
            questions.append(try P.Question(code: question.code, values: question.values, scope: scope, answer: question.answer))
        }
        let sources = p.lineSources.map { s in
            P.LineSources(experience: s.experience, line: s.line, statements: s.statements.map { P.StatementPosition(experience: $0.experience, line: $0.line) },
                          answers: s.answers)
        }
        return try P(jobID: JobID(p.jobID), sourceCV: CVID(p.sourceCV), snapshot: snapshot, report: report, questions: questions, letterOverride: override,
                     letterDefaults: defaults, promptVersion: p.promptVersion, providerAlias: p.providerAlias, modelAlias: p.modelAlias, lineSources: sources)
    }
}
