import SwiftUI
import WebKit
import Foundation
import PrestoCVCore
import CVPDFExporter

struct CVExportSheetView: View {
    let cv: CVModel
    @StateObject private var viewModel: CVExportSheetViewModel
    let previewCoordinator: HTMLPreviewCoordinator

    @Environment(\.dismiss) private var dismiss
    @State private var loadingTemplates = true
    @State private var selectedCategory: OptionCategory = .templates
    
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

                GeometryReader { geometry in
                    contentLayout(in: geometry)
                }
            }
            .navigationTitle(String(localized: "export.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .foregroundColor(DesignTokens.Colors.accent)
                }

                ToolbarItem(placement: .primaryAction) {
                    exportButton
                        .frame(maxWidth: 180)
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

    private enum OptionCategory: CaseIterable {
        case templates
        case fonts
        case colors

        var systemImageName: String {
            switch self {
            case .templates:
                return "doc.text"
            case .fonts:
                return "textformat"
            case .colors:
                return "paintpalette"
            }
        }

        var accessibilityLabel: LocalizedStringKey {
            switch self {
            case .templates:
                return "export.templates.title"
            case .fonts:
                return "export.font.section"
            case .colors:
                return "export.color.section"
            }
        }
    }
    private func contentLayout(in geometry: GeometryProxy) -> some View {
        let rawWidth = geometry.size.width - DesignTokens.Spacing.lg * 2
        let rawHeight = geometry.size.height - DesignTokens.Spacing.xl * 2
        let width = max(rawWidth, 180)
        let availableHeight = max(rawHeight, 320)
        let previewHeight = max(availableHeight * 0.55, 220)
        let tabHeight = max(availableHeight * 0.28, 150)

        return VStack(spacing: DesignTokens.Spacing.lg) {
            previewSection(availableWidth: width, maxHeight: previewHeight)
                .frame(maxWidth: .infinity)
                .frame(height: previewHeight, alignment: .center)

            TabView(selection: $selectedCategory) {
                templateCarousel
                    .tag(OptionCategory.templates)

                fontCarousel
                    .tag(OptionCategory.fonts)

                colorCarousel
                    .tag(OptionCategory.colors)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: tabHeight)

            categorySelector
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.top, DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func previewSection(availableWidth: CGFloat, maxHeight: CGFloat) -> some View {
        let options = viewModel.previewOptions ?? viewModel.currentExportOptions()
        let pageSize = options.pageSize
        let pageWidth = CGFloat(pageSize.width)
        let pageHeight = CGFloat(pageSize.height)
        let aspectRatio = pageWidth / pageHeight
        let maxPreviewWidth = min(pageWidth, max(1, availableWidth))

        Group {
            if let html = viewModel.previewHTML {
                HTMLPreviewView(coordinator: previewCoordinator)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(maxWidth: maxPreviewWidth)
                    .frame(maxHeight: maxHeight)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg))
                    .shadow(color: DesignTokens.Colors.shadow, radius: 12, x: 0, y: 8)
                    .overlay {
                        if previewCoordinator.isLoading {
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
                    .frame(maxWidth: .infinity, maxHeight: maxHeight)
            } else {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(DesignTokens.Colors.backgroundSecondary)
                    .overlay(
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(DesignTokens.IconSize.hero.font)
                            .foregroundColor(DesignTokens.Colors.secondary)
                    )
                    .frame(maxWidth: maxPreviewWidth)
                    .frame(maxHeight: maxHeight)
            }
        }
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
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            HStack(spacing: DesignTokens.Spacing.xs) {
                                ForEach(palette.swatchHexValues, id: \.self) { hex in
                                    Circle()
                                        .fill(Color.fromHex(hex))
                                        .frame(width: 28, height: 28)
                                }
                            }

                            Text(palette.localizedName)
                                .typography(.footnote)
                                .foregroundColor(DesignTokens.Colors.primary)
                                .lineLimit(1)
                        }
                    }
                    .accessibilityLabel(Text(palette.localizedName))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
    }

    private var categorySelector: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ForEach(OptionCategory.allCases, id: \.self) { category in
                Button(action: {
                    withAnimation(DesignTokens.Animations.fastEaseInOut) {
                        selectedCategory = category
                    }
                }) {
                    Image(systemName: category.systemImageName)
                        .font(DesignTokens.IconSize.medium.font)
                        .foregroundColor(category == selectedCategory ? DesignTokens.Colors.accent : DesignTokens.Colors.secondary)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                .fill(category == selectedCategory ? DesignTokens.Colors.accent.opacity(0.15) : DesignTokens.Colors.backgroundSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                .stroke(category == selectedCategory ? DesignTokens.Colors.accent : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(category.accessibilityLabel))
            }
        }
    }

    private var exportButton: some View {
        PrimaryButton.small(
            title: String(localized: "export.button.title"),
            icon: "square.and.arrow.up",
            isLoading: viewModel.isExporting,
            isDisabled: viewModel.selectedTemplateId == nil || viewModel.previewHTML == nil || previewCoordinator.isLoading || viewModel.isPreviewLoading
        ) {
            Task {
                await viewModel.export(cv: cv)
            }
        }
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

// SwiftUI-native document preview
private struct DocumentPreview: View {
    let url: URL
    @State private var isLoading = true
    @State private var loadError: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                WebViewRepresentable(url: url, isLoading: $isLoading, loadError: $loadError)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.05))
                }
                
                if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Unable to preview document")
                            .font(.headline)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            loadError = nil
                            isLoading = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                }
            }
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// SwiftUI-native WKWebView wrapper
private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebViewRepresentable
        
        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }
    }
}
