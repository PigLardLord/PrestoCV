import SwiftUI
import PrestoCVCore
import CVPDFExporter
import QuickLook

struct CVExportSheetView: View {
    let cv: CVModel

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CVExportSheetViewModel()
    @State private var loadingTemplates = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    templateSection
                    customizationSection
                    infoSection
                    exportButton
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Colors.background.ignoresSafeArea())
            .navigationTitle(String(localized: "export.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .foregroundColor(DesignTokens.Colors.accent)
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
                loadingTemplates = false
            }
            .sheet(item: $viewModel.previewItem) { item in
                QuickLookPreview(url: item.url)
                    .ignoresSafeArea()
                    .onDisappear { viewModel.handlePreviewDismiss() }
            }
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            SectionHeaderView(
                title: String(localized: "export.templates.title"),
                subtitle: String(localized: "export.templates.subtitle"),
                titleStyle: .title2,
                subtitleStyle: .body
            )

            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(viewModel.templates, id: \.id) { template in
                    Button(action: { viewModel.selectedTemplateId = template.id }) {
                        CardView(padding: DesignTokens.Spacing.sm) {
                            HStack(spacing: DesignTokens.Spacing.md) {
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                                    .fill(DesignTokens.Colors.backgroundSecondary)
                                    .frame(width: 56, height: 80)
                                    .overlay(
                                        Image(systemName: "doc.text")
                                            .foregroundColor(DesignTokens.Colors.secondary)
                                    )

                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                    Text(template.name)
                                        .typography(.headline)
                                        .foregroundColor(DesignTokens.Colors.primary)
                                    if !template.description.isEmpty {
                                        Text(template.description)
                                            .typography(.caption1)
                                            .foregroundColor(DesignTokens.Colors.secondary)
                                    }
                                }

                                Spacer(minLength: 0)

                                if viewModel.selectedTemplateId == template.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(DesignTokens.IconSize.medium.font)
                                        .foregroundColor(DesignTokens.Colors.accent)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(template.name))
                }
            }
        }
    }

    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            SectionHeaderView(
                title: String(localized: "export.customization.title"),
                subtitle: String(localized: "export.customization.subtitle"),
                titleStyle: .title2,
                subtitleStyle: .body
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(String(localized: "export.color.section"))
                    .typography(.subheadline)
                    .foregroundColor(DesignTokens.Colors.primary)
                Picker("", selection: $viewModel.selectedColorPalette) {
                    ForEach(ColorPalette.allCases, id: \.self) { palette in
                        Text(palette.localizedName).tag(palette)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(String(localized: "export.font.section"))
                    .typography(.subheadline)
                    .foregroundColor(DesignTokens.Colors.primary)
                Picker("", selection: $viewModel.selectedFontScheme) {
                    ForEach(FontScheme.allCases, id: \.self) { scheme in
                        Text(scheme.localizedName).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var infoSection: some View {
        CardView(padding: DesignTokens.Spacing.md) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(DesignTokens.IconSize.large.font)
                    .foregroundColor(DesignTokens.Colors.accent)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(String(localized: "export.preview.title"))
                        .typography(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)

                    Text(String(localized: "export.preview.message"))
                        .typography(.caption1)
                        .foregroundColor(DesignTokens.Colors.secondary)
                }
            }
        }
    }

    private var exportButton: some View {
        PrimaryButton.large(
            title: String(localized: "export.button.title"),
            icon: "square.and.arrow.up",
            isLoading: viewModel.isExporting,
            isDisabled: viewModel.selectedTemplateId == nil
        ) {
            Task { await viewModel.export(cv: cv) }
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
}

#if canImport(QuickLook) && canImport(UIKit)
private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
    }

    static func dismantleUIViewController(_ controller: QLPreviewController, coordinator: Coordinator) {
        controller.dataSource = nil
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
#else
private struct QuickLookPreview: View {
    let url: URL

    var body: some View {
        Text(url.lastPathComponent)
    }
}
#endif
