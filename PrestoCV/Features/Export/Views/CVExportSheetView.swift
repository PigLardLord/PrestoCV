import SwiftUI
import WebKit
import Foundation
import PrestoCVCore
import CVPDFExporter

struct CVExportSheetView: View {
    @StateObject private var viewModel: CVExportSheetViewModel
    @StateObject private var previewCoordinator = HTMLPreviewCoordinator()
    /// The PDF in the share sheet, while the share sheet is open
    @State private var sharingPDF: ExportedPDF?
    /// VoiceOver's focus on the button that shows the full PDF, which is put back there when the full PDF is closed
    @AccessibilityFocusState private var fullPDFButtonHasFocus: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The room for the designs, fonts and colours grows with the text, so that their names are not cut, until the
    /// preview above them would be left with too little.
    @ScaledMetric(relativeTo: .footnote) private var optionsHeight: CGFloat = 300
    private let largestOptionsHeight: CGFloat = 420

    /// The view model is built once, when the sheet first appears, and survives every re-render of the screen under it.
    init(viewModel: @autoclosure @escaping () -> CVExportSheetViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
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

                        previewFooter
                    }

                    if let warning = viewModel.shareWarning {
                        Label(warning, systemImage: "exclamationmark.circle")
                            .typography(.footnote)
                            .foregroundColor(DesignTokens.Colors.secondary)
                            .multilineTextAlignment(.center)
                            // The sentence is shown whole, as the one below; the PDF is made all the same
                            .fixedSize(horizontal: false, vertical: true)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                            .padding(.horizontal, DesignTokens.Spacing.lg)
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

                    sendSection

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
                    BarButton(title: viewModel.closeButtonTitle, systemImage: "xmark", screenTextSize: dynamicTypeSize) {
                        dismiss()
                    }
                        .foregroundColor(DesignTokens.Colors.accent)
                }
            }
            .overlay {
                if viewModel.isLoadingTemplates {
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
                await viewModel.start()
            }
            .onChange(of: viewModel.shareConfirmationText) { _, confirmation in
                if let confirmation {
                    AccessibilityNotification.Announcement(confirmation).post()
                }
            }
            .onDisappear {
                viewModel.sheetDisappeared()
            }
        }
        // The PDF full screen covers the sheet without closing it: the PDF it shows is the one the button shares
        .fullScreenCover(item: Binding(
            get: { viewModel.fullPDF },
            set: { if $0 == nil { viewModel.closeFullPDF() } }
        ), onDismiss: {
            viewModel.fullPDFDidDismiss()
            fullPDFButtonHasFocus = true
        }) { pdf in
            FullPDFView(pdf: pdf) { viewModel.closeFullPDF() }
        }
        // Where the sheet does not fill the screen, as on iPad, it is as tall as a page: the preview keeps its room
        // above the language and the button
        .presentationSizing(.page)
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
                            pdfPreview(of: pdf)
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
            } else if viewModel.isPreviewLoading || viewModel.isLoadingTemplates {
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

    /// The pages of the rendered PDF in the preview, to scroll through. A tap on them shows the PDF full screen, and so
    /// does the button over their corner, which is how VoiceOver, a keyboard, a pointer, Switch Control and Voice Control
    /// get there: the pages themselves are for the eye and the finger.
    private func pdfPreview(of pdf: ExportedPDF) -> some View {
        PDFPreviewView(url: pdf.url, isForTheEyeOnly: true)
            .accessibilityHidden(true)
            .onTapGesture {
                viewModel.showFullPDF()
            }
            .overlay(alignment: .bottomTrailing) {
                showFullPDFButton
            }
    }

    /// Shows the PDF full screen; for VoiceOver it says how many pages the PDF has
    private var showFullPDFButton: some View {
        Button {
            viewModel.showFullPDF()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(DesignTokens.Typography.footnote.font)
                .foregroundColor(DesignTokens.Colors.primary)
                .padding(DesignTokens.Spacing.xs)
                .background(.regularMaterial, in: Circle())
                // The room around the sign is part of the button, up to what a finger can hit
                .frame(
                    minWidth: DesignTokens.InputSize.minimumTapTarget,
                    minHeight: DesignTokens.InputSize.minimumTapTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(viewModel.fullPDFAccessibilityLabel ?? "")
        .accessibilityFocused($fullPDFButtonHasFocus)
        // The sign stays small at the largest text sizes, where it would cover the page
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        // It lies on a page, which is on paper in a dark interface too: the sign and its material are light on it
        .environment(\.colorScheme, .light)
    }

    /// Under the preview: how many pages the PDF has, and the language of its headings with a way to change it. Side by
    /// side where they fit, one above the other where they do not.
    private var previewFooter: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.Spacing.md) {
                pageCountLabel
                documentLanguageMenu
            }

            VStack(spacing: DesignTokens.Spacing.xxs) {
                pageCountLabel
                documentLanguageMenu
            }
        }
        // The line stops short of the largest text sizes, so that the preview keeps its room
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }

    /// The language of the PDF's headings, "Headings in English", which opens the choice of the language
    private var documentLanguageMenu: some View {
        Menu {
            Picker(selection: $viewModel.documentLanguageChoice) {
                Text(viewModel.automaticDocumentLanguageTitle).tag(DocumentLanguage?.none)
                ForEach(DocumentLanguage.allCases) { language in
                    Text(language.nativeName).tag(Optional(language))
                }
            } label: {
                Text("field.document_language".localized)
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Image(systemName: "globe")
                    .accessibilityHidden(true)
                Text(viewModel.documentLanguageText)
                    .multilineTextAlignment(.center)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            .font(DesignTokens.Typography.footnote.font)
            .frame(minHeight: DesignTokens.InputSize.minimumTapTarget)
        }
        .buttonStyle(AccentTextButtonStyle())
        .accessibilityHint(Text("export.language.hint".localized))
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
                if viewModel.isLoadingTemplates {
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

    /// The main action of the sheet, under the preview: the PDF goes wherever the share sheet sends or saves it. The
    /// PDF is rendered once the preview has settled, so that this is one tap; until then the button waits, and says
    /// so. After a share that went through, a line says where the PDF went.
    private var sendSection: some View {
        let isPreparing = viewModel.isPreviewLoading || viewModel.isPreparingPDF
        return VStack(spacing: DesignTokens.Spacing.xs) {
            PrimaryButton.large(
                title: "export.share".localized,
                icon: "square.and.arrow.up",
                isLoading: isPreparing,
                isDisabled: viewModel.sharePDF == nil
            ) {
                sharingPDF = viewModel.sharePDF
            }
            .accessibilityValue(isPreparing ? "export.loading".localized : "")
            .shareSheet(for: $sharingPDF) { activityType, completed in
                viewModel.shareEnded(activityType: activityType, completed: completed)
            }

            if let confirmation = viewModel.shareConfirmationText {
                Label {
                    Text(confirmation)
                        .foregroundColor(DesignTokens.Colors.primary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignTokens.Colors.accent)
                }
                .font(DesignTokens.Typography.footnote.font)
            }
        }
        // The button keeps a readable size at the largest text sizes instead of taking the room of the preview
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(maxWidth: DesignTokens.Layout.readableContentWidth)
        .padding(.horizontal, DesignTokens.Spacing.lg)
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



#if DEBUG
#Preview("CV Export Sheet") {
    // Use the comprehensive sample CV from CVPDFExporter
    let adapter = CVDocumentAdapter()
    let mockCV = adapter.convertToCVModel(from: SampleCVData.complete)

    return CVExportSheetView(viewModel: PreviewDependencies.exportSheet(for: mockCV, sink: { _ in }))
}
#endif


