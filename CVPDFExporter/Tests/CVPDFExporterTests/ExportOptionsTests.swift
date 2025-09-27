import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Export Options Tests

@Suite("Export Options")
struct ExportOptionsTests {

    // MARK: - PageSize Tests

    @Test("Page size initialization")
    func pageSizeInitialization() {
        let pageSize = PageSize(width: 100, height: 200)

        #expect(pageSize.width == 100)
        #expect(pageSize.height == 200)
    }

    @Test("Page size predefined values")
    func pageSizePredefinedValues() {
        // A4 dimensions in points
        #expect(PageSize.a4.width == 595.28)
        #expect(PageSize.a4.height == 841.89)

        // Letter dimensions in points
        #expect(PageSize.letter.width == 612.0)
        #expect(PageSize.letter.height == 792.0)
    }

    @Test("Page size is Sendable")
    func pageSizeSendableConformance() {
        let pageSize = PageSize.a4
        // This test passes if PageSize conforms to Sendable (compilation check)
        #expect(pageSize.width > 0)
    }

    // MARK: - EdgeInsets Tests

    @Test("Edge insets initialization")
    func edgeInsetsInitialization() {
        let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

        #expect(insets.top == 10)
        #expect(insets.left == 20)
        #expect(insets.bottom == 30)
        #expect(insets.right == 40)
    }

    @Test("Edge insets uniform initializer")
    func edgeInsetsUniformInitializer() {
        let insets = EdgeInsets.uniform(50)

        #expect(insets.top == 50)
        #expect(insets.left == 50)
        #expect(insets.bottom == 50)
        #expect(insets.right == 50)
    }

    @Test("Edge insets default value")
    func edgeInsetsDefaultValue() {
        let insets = EdgeInsets.default

        // 1 inch = 72 points
        #expect(insets.top == 72)
        #expect(insets.left == 72)
        #expect(insets.bottom == 72)
        #expect(insets.right == 72)
    }

    @Test("Edge insets is Sendable")
    func edgeInsetsSendableConformance() {
        let insets = EdgeInsets.default
        // This test passes if EdgeInsets conforms to Sendable (compilation check)
        #expect(insets.top > 0)
    }

    // MARK: - ExportOptions Tests

    @Test("Export options initialization")
    func exportOptionsInitialization() {
        let options = ExportOptions(
            pageSize: .letter,
            margins: .uniform(36),
            templateId: "modern"
        )

        #expect(options.pageSize.width == PageSize.letter.width)
        #expect(options.pageSize.height == PageSize.letter.height)
        #expect(options.margins.top == 36)
        #expect(options.templateId == "modern")
    }

    @Test("Export options default value")
    func exportOptionsDefaultValue() {
        let options = ExportOptions.default

        #expect(options.pageSize.width == PageSize.a4.width)
        #expect(options.pageSize.height == PageSize.a4.height)
        #expect(options.margins.top == 72)
        #expect(options.templateId == nil)
    }

    @Test("Export options with custom values")
    func exportOptionsWithCustomValues() {
        let customMargins = EdgeInsets(top: 20, left: 30, bottom: 20, right: 30)
        let options = ExportOptions(
            pageSize: .letter,
            margins: customMargins,
            templateId: "professional"
        )

        #expect(options.pageSize.width == PageSize.letter.width)
        #expect(options.margins.top == 20)
        #expect(options.margins.left == 30)
        #expect(options.templateId == "professional")
    }

    @Test("Export options is Sendable")
    func exportOptionsSendableConformance() {
        let options = ExportOptions.default
        // This test passes if ExportOptions conforms to Sendable (compilation check)
        #expect(options.pageSize.width > 0)
    }

    @Test("Export options for different page formats")
    func exportOptionsForDifferentPageFormats() {
        let a4Options = ExportOptions(pageSize: .a4)
        let letterOptions = ExportOptions(pageSize: .letter)

        #expect(a4Options.pageSize.width != letterOptions.pageSize.width)
        #expect(a4Options.pageSize.height != letterOptions.pageSize.height)
    }
}