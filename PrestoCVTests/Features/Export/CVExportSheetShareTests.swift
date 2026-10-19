import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// After the share sheet: a share that went through is confirmed, with where the PDF went, and the sheet can be closed
/// with Done; a cancelled share changes nothing.
@MainActor
@Suite("CVExportSheetViewModel Tests - after the share sheet")
struct CVExportSheetShareTests {

    private func makeViewModel() async -> CVExportSheetViewModel {
        let viewModel = CVExportSheetViewModel(
            cv: .exportable,
            exportService: MockCVExportService(),
            preferencesStore: InMemoryExportPreferencesStore(),
            previewDebounce: .zero
        )
        viewModel.selectedTemplateId = "modern"
        await viewModel.requestPreview().value
        return viewModel
    }

    @Test("Before any share there is nothing to confirm, and the sheet closes with Cancel")
    func nothingToConfirmAtFirst() async {
        let viewModel = await makeViewModel()

        #expect(viewModel.shareConfirmationText == nil)
        #expect(viewModel.closeButtonTitle == String(localized: "common.cancel"))
    }

    @Test("A PDF saved to Files is confirmed as saved, and the sheet closes with Done")
    func savedToFilesIsConfirmed() async {
        let viewModel = await makeViewModel()

        viewModel.shareEnded(activityType: CVExportSheetViewModel.saveToFilesActivity, completed: true)

        #expect(viewModel.shareOutcome == .saved)
        #expect(viewModel.shareConfirmationText == String(localized: "export.confirmation.saved"))
        #expect(viewModel.closeButtonTitle == String(localized: "common.done"))
    }

    @Test("A PDF sent anywhere else is confirmed as sent", arguments: [
        "com.apple.UIKit.activity.Mail", "com.apple.UIKit.activity.AirDrop", "com.apple.UIKit.activity.Print", nil,
    ])
    func sentIsConfirmed(activityType: String?) async {
        let viewModel = await makeViewModel()

        viewModel.shareEnded(activityType: activityType, completed: true)

        #expect(viewModel.shareOutcome == .sent)
        #expect(viewModel.shareConfirmationText == String(localized: "export.confirmation.sent"))
    }

    @Test("A cancelled share confirms nothing")
    func cancelledShareConfirmsNothing() async {
        let viewModel = await makeViewModel()

        viewModel.shareEnded(activityType: CVExportSheetViewModel.saveToFilesActivity, completed: false)

        #expect(viewModel.shareOutcome == nil)
        #expect(viewModel.closeButtonTitle == String(localized: "common.cancel"))
    }

    @Test("A cancelled share keeps the confirmation of the one before")
    func cancelledShareKeepsTheEarlierConfirmation() async {
        let viewModel = await makeViewModel()
        viewModel.shareEnded(activityType: "com.apple.UIKit.activity.Mail", completed: true)

        viewModel.shareEnded(activityType: nil, completed: false)

        #expect(viewModel.shareOutcome == .sent)
    }

    @Test("A new PDF forgets the confirmation of the old one")
    func newPDFForgetsTheConfirmation() async {
        let viewModel = await makeViewModel()
        viewModel.shareEnded(activityType: CVExportSheetViewModel.saveToFilesActivity, completed: true)

        viewModel.selectedColorPalette = .minimal
        await viewModel.requestPreview().value

        #expect(viewModel.shareConfirmationText == nil)
        #expect(viewModel.closeButtonTitle == String(localized: "common.cancel"))
    }
}
