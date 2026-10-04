import Foundation
import PrestoCVDomain

/// A stored file that the strict decoder of its schema refuses, with the reason: the file is corrupt (R12).
struct FileInvalid: Error, Equatable { let reason: String }

extension FileInvalid {
    /// The reason a stored file is corrupt when the domain refuses a value in it: a stable code, the error's case and the field it
    /// is about (`tooLong.subject`), never printed text. It is what the store reports, and a person can quote it.
    init(_ error: ApplicationError) { self.init(reason: Self.code(error)) }

    private static func code(_ error: ApplicationError) -> String {
        switch error {
        case .empty(let field): "empty." + code(field)
        case .tooLong(let field): "tooLong." + code(field)
        case .tooMany(let field): "tooMany." + code(field)
        case .forbiddenCharacters(let field): "forbiddenCharacters." + code(field)
        case .invalidReference(let field): "invalidReference." + code(field)
        case .overrideNotApplied(let field): "overrideNotApplied." + field.rawValue
        case .cvCannotBeSaved: "cvCannotBeSaved"
        case .cvIdentityChanged: "cvIdentityChanged"
        }
    }

    private static func code(_ field: ApplicationField) -> String {
        switch field {
        case .letterDefault(let field): field.rawValue
        case .recipientCompany: "recipientCompany"
        case .recipientContactName: "recipientContactName"
        case .recipientTitle: "recipientTitle"
        case .recipientSurname: "recipientSurname"
        case .recipientRole: "recipientRole"
        case .recipientAddress: "recipientAddress"
        case .reference: "reference"
        case .position: "position"
        case .subject: "subject"
        case .opening: "opening"
        case .paragraph: "paragraph"
        case .closing: "closing"
        case .attachment: "attachment"
        case .jobID: "jobID"
        case .promptVersion: "promptVersion"
        case .providerAlias: "providerAlias"
        case .modelAlias: "modelAlias"
        case .snapshot: "snapshot"
        case .statement: "statement"
        case .reportArgument: "reportArgument"
        case .reportEntry: "reportEntry"
        case .questions: "questions"
        case .questionCode: "questionCode"
        case .questionValue: "questionValue"
        case .answer: "answer"
        case .lineSources: "lineSources"
        case .statementReference: "statementReference"
        case .answerReference: "answerReference"
        case .advertCompany: "advertCompany"
        case .advertRole: "advertRole"
        case .advertText: "advertText"
        }
    }
}
