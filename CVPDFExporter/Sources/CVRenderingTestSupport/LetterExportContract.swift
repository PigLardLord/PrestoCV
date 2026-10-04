import Foundation
import CVDocumentModel
import CVRendering

public enum LetterExportContractFailure: Error, Equatable, Sendable {
    case notOnePage(language: String, pages: Int?), overlongLetterAccepted(language: String)
}

/// Contract every `PDFRendering` adapter must pass for the cover letter (R10, ADR 0019), on its real platform. In each of the
/// six languages a letter that fits is exported as one page that holds every text node, and a letter that cannot fit is a typed
/// error. The export itself reads the PDF through the inspector, so what is checked is what the PDF contains.
public enum LetterExportContract {
    public static func verify(_ renderer: some PDFRendering, inspector: some PDFInspecting) async throws {
        let export = LetterPDFExport(renderer: renderer, inspector: inspector)
        for language in LetterDocument.supportedLanguages {
            let pdf = try await export.export(ContractFixture.letter(language: language))
            guard inspector.pageCount(of: pdf) == 1 else { throw LetterExportContractFailure.notOnePage(language: language, pages: inspector.pageCount(of: pdf)) }
            do {
                _ = try await export.export(ContractFixture.overlongLetter(language: language))
                throw LetterExportContractFailure.overlongLetterAccepted(language: language)
            } catch LetterPDFExport.Failure.doesNotFitOnOnePage { continue }
        }
    }
}
