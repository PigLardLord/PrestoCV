import Testing
import Foundation
import PDFKit
import UIKit
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter
import struct PrestoCVDomain.ExportPolicy

// MARK: - CVExportService Tests

extension RealRendererSuites {
    /// Exports with the real renderer: WebKit and the print system produce the PDF, and PDFKit reads it back
    @Suite("CVExportService Tests")
    struct CVExportServiceTests {

        private static let cv = CVDocumentAdapter().convertToCVModel(from: SampleCVData.complete)

        private func options(templateId: String, maxPages: Int = ExportPolicy.standard.maxPages) -> ExportOptions {
            ExportOptions(templateId: templateId, maxPages: maxPages)
        }

        // MARK: - Export

        @Test("each bundled template exports a PDF that has pages and readable text",
              .timeLimit(.minutes(2)),
              arguments: ["professional", "modern", "minimal"])
        func exportsReadablePDF(templateId: String) async throws {
            // Given
            let environment = try await ExportTestEnvironment.make()
            defer { environment.cleanUp() }

            // When
            let exported = try await environment.makeService().export(
                cv: Self.cv,
                templateId: templateId,
                options: options(templateId: templateId)
            )

            // Then
            let document = try #require(PDFDocument(url: exported.url))
            #expect(document.pageCount >= 1)
            #expect(document.pageCount <= ExportPolicy.standard.maxPages)
            // A template may set its text in capitals, and a long line wraps: compare words, ignoring case
            let words = (document.string ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
            #expect(words.localizedCaseInsensitiveContains("Maya Chen"))
            #expect(words.localizedCaseInsensitiveContains("Senior UX/UI Designer"))
            #expect(words.localizedCaseInsensitiveContains("DesignForward Agency"))
        }

        @Test("the export reports the page count of the PDF and a picture of its first page",
              .timeLimit(.minutes(2)),
              arguments: ["professional", "modern", "minimal"])
        func reportsPageCountAndThumbnail(templateId: String) async throws {
            // Given
            let environment = try await ExportTestEnvironment.make()
            defer { environment.cleanUp() }

            // When
            let exported = try await environment.makeService().export(
                cv: Self.cv,
                templateId: templateId,
                options: options(templateId: templateId)
            )

            // Then
            let document = try #require(PDFDocument(url: exported.url))
            #expect(exported.pageCount == document.pageCount)
            let thumbnail = try #require(exported.thumbnail.flatMap(UIImage.init(data:)))
            #expect(max(thumbnail.size.width, thumbnail.size.height) * thumbnail.scale == PDFThumbnail.longerSide)
            let page = try #require(document.page(at: 0)).bounds(for: .mediaBox)
            #expect(abs(thumbnail.size.width / thumbnail.size.height - page.width / page.height) < 0.01)
        }

        @Test("the PDF is named after the person, in a folder of its own, with the title and author set",
              .timeLimit(.minutes(2)))
        func namesTheFileAndSetsDocumentProperties() async throws {
            // Given
            let environment = try await ExportTestEnvironment.make()
            defer { environment.cleanUp() }

            // When
            let url = try await environment.makeService().export(
                cv: Self.cv,
                templateId: "professional",
                options: options(templateId: "professional")
            ).url

            // Then
            #expect(url.lastPathComponent == "Maya Chen – CV.pdf")
            let folder = url.deletingLastPathComponent()
            #expect(UUID(uuidString: folder.lastPathComponent) != nil)
            #expect(folder.deletingLastPathComponent().standardizedFileURL == environment.exportsDirectory.standardizedFileURL)

            let attributes = PDFDocument(url: url)?.documentAttributes
            #expect(attributes?[PDFDocumentAttribute.titleAttribute] as? String == "Maya Chen – CV")
            #expect(attributes?[PDFDocumentAttribute.authorAttribute] as? String == "Maya Chen")
        }

        @Test("two exports of the same CV do not overwrite each other", .timeLimit(.minutes(2)))
        func exportsGetFoldersOfTheirOwn() async throws {
            // Given
            let environment = try await ExportTestEnvironment.make()
            defer { environment.cleanUp() }
            let service = environment.makeService()

            // When
            let first = try await service.export(cv: Self.cv, templateId: "modern", options: options(templateId: "modern")).url
            let second = try await service.export(cv: Self.cv, templateId: "modern", options: options(templateId: "modern")).url

            // Then
            #expect(first != second)
            #expect(first.lastPathComponent == second.lastPathComponent)
            #expect(FileManager.default.fileExists(atPath: first.path))
            #expect(FileManager.default.fileExists(atPath: second.path))
        }

        @Test("a CV that needs more pages than allowed is refused, not cut", .timeLimit(.minutes(2)))
        func refusesCVOverThePageLimit() async throws {
            // Given
            let environment = try await ExportTestEnvironment.make()
            defer { environment.cleanUp() }

            // When/Then
            do {
                _ = try await environment.makeService().export(
                    cv: Self.cv,
                    templateId: "professional",
                    options: options(templateId: "professional", maxPages: 1)
                )
                Issue.record("Expected tooManyPages")
            } catch PDFExportError.tooManyPages(let count, let limit) {
                #expect(count > 1)
                #expect(limit == 1)
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: environment.exportsDirectory.path).isEmpty)
        }

        @Test("an unknown template is reported as not found", .timeLimit(.minutes(2)))
        func unknownTemplateIsNotFound() async throws {
            // Given
            let environment = try await ExportTestEnvironment.make()
            defer { environment.cleanUp() }

            // When/Then
            await #expect(throws: TemplateError.self) {
                _ = try await environment.makeService().export(
                    cv: Self.cv,
                    templateId: "does-not-exist",
                    options: options(templateId: "does-not-exist")
                )
            }
        }

        // MARK: - Cleanup

        @Test("cleanup removes the exported file together with its folder", .timeLimit(.minutes(2)))
        func cleanupRemovesTheExportFolder() async throws {
            // Given
            let environment = try await ExportTestEnvironment.make()
            defer { environment.cleanUp() }
            let service = environment.makeService()
            let url = try await service.export(cv: Self.cv, templateId: "minimal", options: options(templateId: "minimal")).url

            // When
            await service.cleanupTempFile(at: url)

            // Then
            #expect(!FileManager.default.fileExists(atPath: url.path))
            #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
            #expect(FileManager.default.fileExists(atPath: environment.exportsDirectory.path))
        }

        @Test("cleanup of a file that is not in an export folder removes only that file")
        func cleanupLeavesOtherFilesAlone() async throws {
            // Given
            let environment = try await ExportTestEnvironment.make()
            defer { environment.cleanUp() }
            let strayFile = environment.exportsDirectory.appendingPathComponent("stray.pdf")
            let neighbour = environment.exportsDirectory.appendingPathComponent("neighbour.pdf")
            try Data("stray".utf8).write(to: strayFile)
            try Data("neighbour".utf8).write(to: neighbour)

            // When
            await environment.makeService().cleanupTempFile(at: strayFile)

            // Then: the folder that holds it is not an export folder, so it stays with its other files
            #expect(!FileManager.default.fileExists(atPath: strayFile.path))
            #expect(FileManager.default.fileExists(atPath: neighbour.path))
        }

        // MARK: - Designs

        @Test("the designs on offer are the ones that ship with the app", .timeLimit(.minutes(2)))
        func offersTheBundledDesigns() async throws {
            let environment = try await ExportTestEnvironment.make()
            defer { environment.cleanUp() }

            let designs = try await environment.makeService().availableTemplates()

            #expect(Set(designs.map(\.id)) == ["professional", "modern", "minimal"])
        }
    }
}
