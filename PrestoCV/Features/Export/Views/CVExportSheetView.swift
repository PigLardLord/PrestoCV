import SwiftUI
import WebKit
import Foundation
import PrestoCVCore
import CVPDFExporter

struct CVExportSheetView: View {
    let cv: CVModel
    @StateObject private var viewModel = CVExportSheetViewModel()
    @StateObject private var previewCoordinator = HTMLPreviewCoordinator()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var loadingTemplates = true
    /// The room for the designs, fonts and colours grows with the text, so that their names are not cut, until the
    /// preview above them would be left with too little.
    @ScaledMetric(relativeTo: .footnote) private var optionsHeight: CGFloat = 300
    private let largestOptionsHeight: CGFloat = 420

    init(cv: CVModel) {
        self.cv = cv
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background.ignoresSafeArea()

                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Preview section takes up remaining space with A4 aspect ratio
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        previewSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        pageCountLabel
                    }

                    if let blocker = viewModel.shareBlocker {
                        Label(blocker, systemImage: "info.circle")
                            .typography(.footnote)
                            .foregroundColor(DesignTokens.Colors.secondary)
                            .multilineTextAlignment(.center)
                            // The sentence says why the PDF cannot be shared: it is shown whole, and the preview
                            // gives up the room. Its size stops short of the largest, so that the preview stays.
                            .fixedSize(horizontal: false, vertical: true)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                            .padding(.horizontal, DesignTokens.Spacing.lg)
                    }

                    // Fixed height section for options with native TabView
                    TabView {
                        templateCarousel
                            .tabItem {
                                Label(String(localized: "export.templates.tab"), systemImage: "doc.text")
                            }

                        fontCarousel
                            .tabItem {
                                Label(String(localized: "export.fonts.tab"), systemImage: "textformat")
                            }

                        colorCarousel
                            .tabItem {
                                Label(String(localized: "export.colors.tab"), systemImage: "paintpalette")
                            }
                    }
                    .frame(height: min(optionsHeight, largestOptionsHeight))
                }
                .padding(.top, DesignTokens.Spacing.lg)
                .ignoresSafeArea(edges: .bottom)
            }
            .screenTitle(String(localized: "export.sheet.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BarButton(title: String(localized: "common.cancel"), systemImage: "xmark", screenTextSize: dynamicTypeSize) {
                        dismiss()
                    }
                        .foregroundColor(DesignTokens.Colors.accent)
                }

                ToolbarItem(placement: .primaryAction) {
                    shareButton
                }
            }
            .overlay {
                if loadingTemplates {
                    LoadingView.fullscreen()
                }
            }
            .alert(String(localized: "common.error"), isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.dismissError() }
            ), actions: {
                Button(String(localized: "common.ok")) { viewModel.dismissError() }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
            .task {
                // Loading the templates sets the selection, which starts the first preview
                await viewModel.loadTemplates()
                loadingTemplates = false
            }
            .onChange(of: viewModel.selection) {
                viewModel.requestPreview(for: cv)
            }
            .onDisappear {
                viewModel.stop()
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        Group {
            if let html = viewModel.previewHTML {
                HTMLPreviewView(coordinator: previewCoordinator)
                    .aspectRatio(viewModel.aspectRatio, contentMode: .fit)
                    .accessibilityHidden(viewModel.sharePDF != nil)
                    .overlay {
                        // Once the PDF is rendered, its pages replace the first page of the preview
                        if let pdf = viewModel.sharePDF {
                            PDFPreviewView(url: pdf.url)
                        }
                    }
                    .padding(8) // Add padding around WebView for the white border
                    .background(Color.white) // White background for the margin simulation
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
                    .shadow(color: DesignTokens.Colors.shadow, radius: 12, x: 0, y: 8)
                    .overlay {
                        if previewCoordinator.isLoading || viewModel.isPreviewLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.08))
                        }
                    }
                    .task(id: html) {
                        do {
                            try await previewCoordinator.load(html: html)
                        } catch {
                            viewModel.reportPreviewLoadFailure(error)
                        }
                    }
            } else if viewModel.isPreviewLoading || loadingTemplates {
                ProgressView()
                    .aspectRatio(viewModel.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(DesignTokens.Colors.backgroundSecondary)
                    .aspectRatio(viewModel.aspectRatio, contentMode: .fit)
                    .overlay(
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(DesignTokens.IconSize.hero.font)
                            .foregroundColor(DesignTokens.Colors.secondary)
                    )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .animation(DesignTokens.Animations.fastEaseInOut, value: viewModel.previewHTML)
    }

    /// How many pages the PDF has, under the preview and not over a page of it. The line is there while the PDF is
    /// still rendering, so that the preview does not move when the count appears.
    private var pageCountLabel: some View {
        Text(viewModel.pageCountText ?? " ")
            .font(DesignTokens.Typography.footnote.font)
            .foregroundColor(DesignTokens.Colors.primary)
            // The sheet's own background, stated, so that the contrast of the text can be measured against it
            .background(DesignTokens.Colors.background)
            .accessibilityHidden(viewModel.pageCountText == nil)
    }

    private var templateCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.md) {
                if loadingTemplates {
                    OptionCarouselItem(isSelected: false, isInteractive: false, action: {}) {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else if viewModel.templates.isEmpty {
                    OptionCarouselItem(isSelected: false, isInteractive: false, action: {}) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(DesignTokens.IconSize.large.font)
                            .foregroundColor(DesignTokens.Colors.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ForEach(viewModel.templates, id: \.id) { template in
                        OptionCarouselItem(
                            isSelected: viewModel.selectedTemplateId == template.id,
                            action: { viewModel.selectedTemplateId = template.id }
                        ) {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                // Template preview image
                                if let thumbnailURL = template.thumbnailURL {
                                    AsyncImage(url: thumbnailURL) { phase in
                                        switch phase {
                                        case .empty:
                                            // Loading placeholder
                                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                                .fill(DesignTokens.Colors.backgroundSecondary)
                                                .aspectRatio(0.7, contentMode: .fit)
                                                .overlay(
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle())
                                                )
                                        case .success(let image):
                                            // Successfully loaded image
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(maxWidth: .infinity)
                                                .aspectRatio(0.7, contentMode: .fit)
                                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
                                        case .failure:
                                            // Failed to load - show fallback icon
                                            fallbackTemplatePreview
                                        @unknown default:
                                            fallbackTemplatePreview
                                        }
                                    }
                                } else {
                                    // No preview URL - show fallback icon
                                    fallbackTemplatePreview
                                }

                                WholeWordsText(template.name)
                                    .typography(.footnote)
                                    .foregroundColor(DesignTokens.Colors.primary)
                                    .lineLimit(2)
                            }
                        }
                        .accessibilityLabel(Text(template.name))
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
    }

    private var fontCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ForEach(FontScheme.allCases, id: \.self) { scheme in
                    OptionCarouselItem(
                        isSelected: viewModel.selectedFontScheme == scheme,
                        action: { viewModel.selectedFontScheme = scheme }
                    ) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("export.font_preview_sample".localized)
                                .font(scheme.previewHeadingFont)
                                .foregroundColor(DesignTokens.Colors.primary)

                            Text("export.font_preview_name".localized)
                                .font(scheme.previewBodyFont)
                                .foregroundColor(DesignTokens.Colors.secondary)

                            WholeWordsText(scheme.localizedName)
                                .typography(.footnote)
                                .foregroundColor(DesignTokens.Colors.primary)
                                .lineLimit(2)
                        }
                    }
                    .accessibilityLabel(Text(scheme.localizedName))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
    }

    private var colorCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ForEach(ColorPalette.allCases, id: \.self) { palette in
                    OptionCarouselItem(
                        isSelected: viewModel.selectedColorPalette == palette,
                        action: { viewModel.selectedColorPalette = palette }
                    ) {
                        VStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                            VStack(spacing: DesignTokens.Spacing.xs) {
                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    ForEach(palette.swatchHexValues.prefix(2), id: \.self) { hex in
                                        Circle()
                                            .fill(Color.fromHex(hex))
                                            .frame(width: 28, height: 28)
                                    }
                                }

                                HStack(spacing: DesignTokens.Spacing.xs) {
                                    ForEach(palette.swatchHexValues.suffix(2), id: \.self) { hex in
                                        Circle()
                                            .fill(Color.fromHex(hex))
                                            .frame(width: 28, height: 28)
                                    }
                                }
                            }

                            WholeWordsText(palette.localizedName)
                                .typography(.footnote)
                                .foregroundColor(DesignTokens.Colors.primary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .accessibilityLabel(Text(palette.localizedName))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
    }

    /// The PDF is rendered once the preview has settled, so sharing it is one tap; until then the button waits.
    @ViewBuilder
    private var shareButton: some View {
        if let pdf = viewModel.sharePDF {
            shareLink(for: pdf)
                .foregroundColor(DesignTokens.Colors.accent)
        } else if viewModel.isPreviewLoading || viewModel.isPreparingPDF {
            ProgressView()
                .accessibilityLabel(Text("export.loading".localized))
        } else {
            Button {} label: {
                shareLabel
            }
            .disabled(true)
        }
    }

    /// The share sheet shows the first page next to the file name, where it would otherwise show a generic icon
    @ViewBuilder
    private func shareLink(for pdf: ExportedPDF) -> some View {
        if let thumbnail = pdf.thumbnail.flatMap(UIImage.init(data:)) {
            ShareLink(item: pdf.url, preview: SharePreview(pdf.fileName, image: Image(uiImage: thumbnail))) {
                shareLabel
            }
        } else {
            ShareLink(item: pdf.url, preview: SharePreview(pdf.fileName)) {
                shareLabel
            }
        }
    }

    private var shareLabel: some View {
        Label("export.share".localized, systemImage: "square.and.arrow.up")
            .labelStyle(.titleAndIcon)
    }

    private var fallbackTemplatePreview: some View {
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
            .fill(DesignTokens.Colors.backgroundSecondary)
            .aspectRatio(0.7, contentMode: .fit)
            .overlay(
                Image(systemName: "doc.text")
                    .font(DesignTokens.IconSize.large.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
            )
    }

    private struct OptionCarouselItem<Content: View>: View {
        let isSelected: Bool
        let isInteractive: Bool
        let action: () -> Void
        let content: Content

        /// An item grows with the text, as far as it still leaves the next one in view: its name is shown whole
        @ScaledMetric(relativeTo: .footnote) private var width: CGFloat = 150
        @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 160
        private let largestWidth: CGFloat = 300
        private let largestHeight: CGFloat = 220

        init(
            isSelected: Bool,
            isInteractive: Bool = true,
            action: @escaping () -> Void,
            @ViewBuilder content: () -> Content
        ) {
            self.isSelected = isSelected
            self.isInteractive = isInteractive
            self.action = action
            self.content = content()
        }

        var body: some View {
            Button(action: action) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.md)
                    .frame(width: min(width, largestWidth), height: min(height, largestHeight), alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .fill(DesignTokens.Colors.backgroundSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .stroke(isSelected ? DesignTokens.Colors.accent : Color.clear, lineWidth: 2)
                    )
            }
            .buttonStyle(CardButtonStyle())
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .disabled(!isInteractive)
            .opacity(isInteractive ? 1 : DesignTokens.Opacity.medium)
        }
    }
}

private extension ColorPalette {
    var localizedName: String {
        switch self {
        case .professional:
            return String(localized: "export.color.professional")
        case .modern:
            return String(localized: "export.color.modern")
        case .minimal:
            return String(localized: "export.color.minimal")
        case .creative:
            return String(localized: "export.color.creative")
        }
    }

    var swatchHexValues: [String] {
        let paletteColors = colors
        return [
            paletteColors.primary,
            paletteColors.accent,
            paletteColors.background,
            paletteColors.secondary
        ]
    }
}

private extension FontScheme {
    var localizedName: String {
        switch self {
        case .classic:
            return String(localized: "export.font.classic")
        case .modern:
            return String(localized: "export.font.modern")
        case .serif:
            return String(localized: "export.font.serif")
        }
    }

    var previewHeadingFont: Font {
        switch self {
        case .classic:
            return .system(size: 36, weight: .bold, design: .default)
        case .modern:
            return .system(size: 36, weight: .semibold, design: .rounded)
        case .serif:
            return .system(size: 36, weight: .bold, design: .serif)
        }
    }

    var previewBodyFont: Font {
        switch self {
        case .classic:
            return .system(size: 18, weight: .medium, design: .default)
        case .modern:
            return .system(size: 18, weight: .medium, design: .rounded)
        case .serif:
            return .system(size: 18, weight: .medium, design: .serif)
        }
    }

    var previewBodyFontSmall: Font {
        switch self {
        case .classic:
            return .system(size: 14, weight: .regular, design: .default)
        case .modern:
            return .system(size: 14, weight: .regular, design: .rounded)
        case .serif:
            return .system(size: 14, weight: .regular, design: .serif)
        }
    }
}

private extension Color {
    static func fromHex(_ hex: String) -> Color {
        var sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if sanitized.count == 3 {
            sanitized = sanitized.reduce(into: "") { result, character in
                result.append(String(repeating: character, count: 2))
            }
        }

        guard sanitized.count == 6,
              let value = UInt64(sanitized, radix: 16) else {
            return DesignTokens.Colors.backgroundSecondary
        }

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255

        return Color(red: red, green: green, blue: blue)
    }
}



#Preview("CV Export Sheet") {
    // Use the comprehensive sample CV from CVPDFExporter
    let adapter = CVDocumentAdapter()
    let mockCV = adapter.convertToCVModel(from: SampleCVData.complete)

    return CVExportSheetView(cv: mockCV)
}


