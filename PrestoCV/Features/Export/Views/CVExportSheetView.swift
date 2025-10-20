import SwiftUI
import WebKit
import Foundation
import PrestoCVCore
import CVPDFExporter

struct CVExportSheetView: View {
    let cv: CVModel
    @StateObject private var viewModel: CVExportSheetViewModel
    @ObservedObject var previewCoordinator: HTMLPreviewCoordinator

    @Environment(\.dismiss) private var dismiss
    @State private var loadingTemplates = true
    
    // Convenience initializer with default dependencies
    init(cv: CVModel) {
        self.cv = cv
        self._viewModel = StateObject(wrappedValue: CVExportSheetViewModel())
        self.previewCoordinator = HTMLPreviewCoordinator()
    }
    
    // Main initializer with injected dependencies
    init(cv: CVModel, viewModel: CVExportSheetViewModel, previewCoordinator: HTMLPreviewCoordinator) {
        self.cv = cv
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.previewCoordinator = previewCoordinator
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background.ignoresSafeArea()

                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Preview section takes up remaining space with A4 aspect ratio
                    previewSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                    .frame(height: 300)
                }
                .padding(.top, DesignTokens.Spacing.lg)
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(String(localized: "export.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .foregroundColor(DesignTokens.Colors.accent)
                }

                ToolbarItem(placement: .primaryAction) {
                    nativeExportButton
                }
            }
            .overlay {
                if loadingTemplates {
                    LoadingView.fullscreen()
                } else if viewModel.isExporting {
                    LoadingView.fullscreen(message: String(localized: "export.loading").asLoclizedKey)
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
                await viewModel.loadTemplates()
                await viewModel.refreshPreview(for: cv)
                loadingTemplates = false
            }
            .sheet(item: $viewModel.previewItem) { item in
                DocumentPreview(url: item.url)
                    .onDisappear { viewModel.handlePreviewDismiss() }
            }
            .onChange(of: viewModel.selectedTemplateId) {
                Task { await viewModel.refreshPreview(for: cv) }
            }
            .onChange(of: viewModel.selectedColorPalette) {
                Task { await viewModel.refreshPreview(for: cv) }
            }
            .onChange(of: viewModel.selectedFontScheme) {
                Task { await viewModel.refreshPreview(for: cv) }
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        Group {
            if let html = viewModel.previewHTML {
                HTMLPreviewView(coordinator: previewCoordinator)
                    .aspectRatio(viewModel.aspectRatio, contentMode: .fit)
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
                        } catch is CancellationError {
                            // Ignore
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
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
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                    .fill(DesignTokens.Colors.backgroundSecondary)
                                    .aspectRatio(0.7, contentMode: .fit)
                                    .overlay(
                                        Image(systemName: "doc.text")
                                            .font(DesignTokens.IconSize.large.font)
                                            .foregroundColor(DesignTokens.Colors.secondary)
                                    )

                                Text(template.name)
                                    .typography(.footnote)
                                    .foregroundColor(DesignTokens.Colors.primary)
                                    .lineLimit(1)
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
                            Text("Aa")
                                .font(scheme.previewHeadingFont)
                                .foregroundColor(DesignTokens.Colors.primary)

                            Text("Maya Chen")
                                .font(scheme.previewBodyFont)
                                .foregroundColor(DesignTokens.Colors.secondary)

                            Text(scheme.localizedName)
                                .typography(.footnote)
                                .foregroundColor(DesignTokens.Colors.primary)
                                .lineLimit(1)
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

                            Text(palette.localizedName)
                                .typography(.footnote)
                                .foregroundColor(DesignTokens.Colors.primary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .accessibilityLabel(Text(palette.localizedName))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
    }

    private var nativeExportButton: some View {
        Button(action: {
            Task {
                await viewModel.export(cv: cv)
            }
        }) {
            if viewModel.isExporting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.Colors.accent))
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isExportDisabled ? DesignTokens.Colors.secondary : DesignTokens.Colors.accent)
            }
        }
        .disabled(isExportDisabled)
    }
    
    private var isExportDisabled: Bool {
        viewModel.selectedTemplateId == nil ||
        viewModel.previewHTML == nil ||
        previewCoordinator.isLoading ||
        viewModel.isPreviewLoading ||
        viewModel.isExporting
    }

    private struct OptionCarouselItem<Content: View>: View {
        let isSelected: Bool
        let isInteractive: Bool
        let action: () -> Void
        let content: Content
        let width: CGFloat

        init(
            isSelected: Bool,
            isInteractive: Bool = true,
            width: CGFloat = 150,
            action: @escaping () -> Void,
            @ViewBuilder content: () -> Content
        ) {
            self.isSelected = isSelected
            self.isInteractive = isInteractive
            self.action = action
            self.width = width
            self.content = content()
        }

        var body: some View {
            Button(action: action) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(DesignTokens.Spacing.md)
                    .frame(width: width, height: 160, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .fill(DesignTokens.Colors.backgroundSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                            .stroke(isSelected ? DesignTokens.Colors.accent : Color.clear, lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)
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


