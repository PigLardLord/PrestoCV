import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// A PDF that a share sheet may be reading stays until that share ends, whatever the export sheet does in the meantime:
/// closing, being torn down, making a new PDF. A share that is not open on the file changes nothing.
///
/// A test keeps its share in use up to the check of the file, so that it is not released early: a share that is dropped
/// ends (`aDroppedShareEnds`). A test that tears the sheet down proves with a weak reference that the view model is gone,
/// and waits a bounded time for a removal that must not come: without the proof it could pass with the sheet still alive.
@MainActor
@Suite("CVExportSheetViewModel Tests - a share holds the PDF")
struct CVExportSheetShareHoldTests {

    private let rendered = URL(fileURLWithPath: "/tmp/test.pdf")

    private func makeViewModel(_ service: MockCVExportService) -> CVExportSheetViewModel {
        let viewModel = CVExportSheetViewModel(
            cv: .exportable,
            exportService: service,
            preferencesStore: InMemoryExportPreferencesStore(),
            documentLanguageSink: { _ in },
            lookSink: { _ in },
            exportPolicy: .standard,
            documentLanguageDetector: englishDocumentLanguageDetector,
            appLocale: Locale(identifier: "en"),
            previewDebounce: .zero
        )
        viewModel.selectedTemplateId = "modern"
        return viewModel
    }

    // MARK: - Beginning a share

    @Test("There is nothing to share before the PDF is rendered")
    func noShareBeforeThePDF() {
        let viewModel = makeViewModel(MockCVExportService())

        #expect(viewModel.beginShare() == nil)
    }

    @Test("A share is on the PDF of the sheet")
    func shareIsOnThePDFOfTheSheet() async throws {
        let viewModel = makeViewModel(MockCVExportService())
        await viewModel.requestPreview().value

        let share = try #require(viewModel.beginShare())

        #expect(share.pdf == viewModel.sharePDF)
        share.end()
    }

    // MARK: - The sheet going away during a share

    @Test("The sheet closing during a share keeps the file until the share ends, and then removes it")
    func closingDuringAShareKeepsTheFile() async throws {
        let service = MockCVExportService()
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value
        let share = try #require(viewModel.beginShare())

        await viewModel.stop().value

        #expect(viewModel.sharePDF == nil, "the sheet is closed")
        #expect(await service.cleanedUpURLs.isEmpty, "the share sheet may still read the file")
        await share.end().value
        #expect(await service.cleanedUpURLs == [rendered], "the file goes with the share")
    }

    @Test("The sheet torn down during a share keeps the file until the share ends, and then removes it")
    func tearDownDuringAShareKeepsTheFile() async throws {
        let service = MockCVExportService()
        var viewModel: CVExportSheetViewModel? = makeViewModel(service)
        weak var weakViewModel = viewModel
        await viewModel?.requestPreview().value
        let share = try #require(viewModel?.beginShare())

        viewModel = nil
        let gone = weakViewModel == nil
        let removedEarly = await finishes(within: .milliseconds(300)) { await service.waitUntilCleanedUp() }

        #expect(gone, "the sheet is torn down: nothing else holds its view model")
        #expect(!removedEarly, "the share sheet may still read the file, with the sheet gone")
        await share.end().value
        #expect(await service.cleanedUpURLs == [rendered], "the file goes with the share")
    }

    @Test("A new PDF made during a share leaves the first file to the share, and removes it when the share ends")
    func newPDFDuringAShareKeepsTheFirstFile() async throws {
        let service = MockCVExportService()
        let first = URL(fileURLWithPath: "/tmp/first.pdf")
        let second = URL(fileURLWithPath: "/tmp/second.pdf")
        await service.enqueueExport(.success(first))
        await service.enqueueExport(.success(second))
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value
        let share = try #require(viewModel.beginShare())
        #expect(share.pdf.url == first)

        await viewModel.requestPreview().value

        #expect(viewModel.sharePDF?.url == second, "the sheet moves on to the new PDF")
        #expect(await service.cleanedUpURLs.isEmpty, "the share sheet may still read the first file")
        await share.end().value
        #expect(await service.cleanedUpURLs == [first], "the first file goes with the share, the second stays with the sheet")
    }

    // MARK: - The shares of one file

    @Test("Two shares on one file keep it until both have ended")
    func twoSharesKeepTheFileUntilBothEnd() async throws {
        let service = MockCVExportService()
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value
        let first = try #require(viewModel.beginShare())
        let second = try #require(viewModel.beginShare())
        await viewModel.stop().value

        await first.end().value

        #expect(await service.cleanedUpURLs.isEmpty, "the second share is still open")
        await second.end().value
        #expect(await service.cleanedUpURLs == [rendered])
    }

    @Test("Ending a share twice ends it once: another share on the file is still open")
    func endingTwiceEndsOnce() async throws {
        let service = MockCVExportService()
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value
        let share = try #require(viewModel.beginShare())
        let other = try #require(viewModel.beginShare())
        await viewModel.stop().value

        await share.end().value
        await share.end().value

        #expect(await service.cleanedUpURLs.isEmpty, "the other share is still open")
        await other.end().value
        #expect(await service.cleanedUpURLs == [rendered])
    }

    @Test("A share that was dropped without ending ends with the drop")
    func aDroppedShareEnds() async throws {
        let service = MockCVExportService()
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value
        var share: PDFShare? = try #require(viewModel.beginShare())
        #expect(share?.pdf.url == rendered)
        await viewModel.stop().value
        #expect(await service.cleanedUpURLs.isEmpty, "the share is still held")

        share = nil

        #expect(await finishes { await service.waitUntilCleanedUp() }, "the file is removed once nothing holds the share")
        #expect(await service.cleanedUpURLs == [rendered])
    }

    // MARK: - Guards: a share that is not open changes nothing

    @Test("A share that has ended leaves the file to the sheet, which removes it as it closes")
    func endedShareLeavesTheFileToTheSheet() async throws {
        let service = MockCVExportService()
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value
        let share = try #require(viewModel.beginShare())

        await share.end().value

        #expect(viewModel.sharePDF != nil, "the sheet is open and still has its PDF")
        #expect(await service.cleanedUpURLs.isEmpty, "the file is not the share's to remove")
        await viewModel.stop().value
        #expect(await service.cleanedUpURLs == [rendered])
    }

    @Test("Without a share the sheet closing removes the file at once")
    func closingWithoutAShareRemovesTheFile() async {
        let service = MockCVExportService()
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value

        await viewModel.stop().value

        #expect(await service.cleanedUpURLs == [rendered])
    }
}
