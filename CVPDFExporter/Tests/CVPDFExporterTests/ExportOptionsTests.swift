import XCTest
@testable import CVPDFExporter

final class ExportOptionsTests: XCTestCase {

    // MARK: - PageSize Tests

    func testPageSizeInitialization() {
        let size = PageSize(width: 612, height: 792)
        XCTAssertEqual(size.width, 612)
        XCTAssertEqual(size.height, 792)
    }

    func testPageSizePredefinedValues() {
        // A4 size in points (210mm x 297mm)
        let a4 = PageSize.a4
        XCTAssertEqual(a4.width, 595, accuracy: 1)
        XCTAssertEqual(a4.height, 842, accuracy: 1)

        // US Letter size in points (8.5" x 11")
        let letter = PageSize.letter
        XCTAssertEqual(letter.width, 612)
        XCTAssertEqual(letter.height, 792)
    }

    func testPageSizeSendableConformance() {
        let size = PageSize(width: 100, height: 200)

        // Test that PageSize can be sent across actor boundaries
        Task { @MainActor in
            let copiedSize = size
            XCTAssertEqual(copiedSize.width, 100)
            XCTAssertEqual(copiedSize.height, 200)
        }
    }

    // MARK: - EdgeInsets Tests

    func testEdgeInsetsInitialization() {
        let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        XCTAssertEqual(insets.top, 10)
        XCTAssertEqual(insets.left, 20)
        XCTAssertEqual(insets.bottom, 30)
        XCTAssertEqual(insets.right, 40)
    }

    func testEdgeInsetsUniformInitializer() {
        let insets = EdgeInsets.uniform(15)
        XCTAssertEqual(insets.top, 15)
        XCTAssertEqual(insets.left, 15)
        XCTAssertEqual(insets.bottom, 15)
        XCTAssertEqual(insets.right, 15)
    }

    func testEdgeInsetsDefaultValue() {
        let defaultInsets = EdgeInsets.default
        XCTAssertEqual(defaultInsets.top, 72)
        XCTAssertEqual(defaultInsets.left, 72)
        XCTAssertEqual(defaultInsets.bottom, 72)
        XCTAssertEqual(defaultInsets.right, 72)
    }

    func testEdgeInsetsSendableConformance() {
        let insets = EdgeInsets(top: 1, left: 2, bottom: 3, right: 4)

        // Test that EdgeInsets can be sent across actor boundaries
        Task { @MainActor in
            let copiedInsets = insets
            XCTAssertEqual(copiedInsets.top, 1)
            XCTAssertEqual(copiedInsets.left, 2)
            XCTAssertEqual(copiedInsets.bottom, 3)
            XCTAssertEqual(copiedInsets.right, 4)
        }
    }

    // MARK: - ExportOptions Tests

    func testExportOptionsInitialization() {
        let options = ExportOptions(
            pageSize: .a4,
            margins: .uniform(50)
        )

        XCTAssertEqual(options.pageSize.width, PageSize.a4.width)
        XCTAssertEqual(options.pageSize.height, PageSize.a4.height)
        XCTAssertEqual(options.margins.top, 50)
        XCTAssertEqual(options.margins.left, 50)
    }

    func testExportOptionsDefaultValue() {
        let defaultOptions = ExportOptions.default

        XCTAssertEqual(defaultOptions.pageSize.width, PageSize.a4.width)
        XCTAssertEqual(defaultOptions.pageSize.height, PageSize.a4.height)
        XCTAssertEqual(defaultOptions.margins.top, 72)
        XCTAssertEqual(defaultOptions.margins.left, 72)
        XCTAssertEqual(defaultOptions.margins.bottom, 72)
        XCTAssertEqual(defaultOptions.margins.right, 72)
    }

    func testExportOptionsSendableConformance() {
        let options = ExportOptions(
            pageSize: .letter,
            margins: .uniform(25)
        )

        // Test that ExportOptions can be sent across actor boundaries
        Task { @MainActor in
            let copiedOptions = options
            XCTAssertEqual(copiedOptions.pageSize.width, PageSize.letter.width)
            XCTAssertEqual(copiedOptions.margins.top, 25)
        }
    }

    // MARK: - Integration Tests

    func testExportOptionsWithCustomValues() {
        let customSize = PageSize(width: 500, height: 700)
        let customMargins = EdgeInsets(top: 36, left: 36, bottom: 36, right: 36)

        let options = ExportOptions(
            pageSize: customSize,
            margins: customMargins
        )

        XCTAssertEqual(options.pageSize.width, 500)
        XCTAssertEqual(options.pageSize.height, 700)
        XCTAssertEqual(options.margins.top, 36)
    }

    func testExportOptionsForDifferentPageFormats() {
        // Test A4 with narrow margins
        let a4Options = ExportOptions(
            pageSize: .a4,
            margins: .uniform(36)
        )
        XCTAssertEqual(a4Options.pageSize.height, PageSize.a4.height)
        XCTAssertEqual(a4Options.margins.top, 36)

        // Test Letter with wide margins
        let letterOptions = ExportOptions(
            pageSize: .letter,
            margins: .uniform(108)
        )
        XCTAssertEqual(letterOptions.pageSize.width, PageSize.letter.width)
        XCTAssertEqual(letterOptions.margins.left, 108)
    }
}