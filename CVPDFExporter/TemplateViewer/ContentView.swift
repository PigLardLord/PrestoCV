import SwiftUI
import WebKit
import CVPDFExporter

struct ContentView: View {
    @StateObject private var viewModel = TemplateViewerViewModel()

    var body: some View {
        HSplitView {
            // Left sidebar - Controls
            VStack(alignment: .leading, spacing: 20) {
                Text("CV Template Viewer")
                    .font(.title)
                    .fontWeight(.bold)

                Divider()

                // Template Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Template")
                        .font(.headline)

                    if viewModel.templates.isEmpty {
                        ProgressView()
                    } else {
                        Picker("", selection: $viewModel.selectedTemplateId) {
                            ForEach(viewModel.templates, id: \.id) { template in
                                VStack(alignment: .leading) {
                                    Text(template.name)
                                        .font(.body)
                                    Text(template.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(template.id as String?)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.radioGroup)
                    }
                }

                Divider()

                // Color Palette Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color Palette")
                        .font(.headline)

                    Picker("", selection: $viewModel.selectedColorPalette) {
                        ForEach([ColorPalette.professional, .modern, .minimal, .creative], id: \.self) { palette in
                            HStack {
                                Circle()
                                    .fill(Color.fromHex(palette.colors.primary))
                                    .frame(width: 12, height: 12)
                                Text(palette.displayName)
                            }
                            .tag(palette)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }

                Divider()

                // Font Scheme Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Scheme")
                        .font(.headline)

                    Picker("", selection: $viewModel.selectedFontScheme) {
                        ForEach([FontScheme.classic, .modern, .serif], id: \.self) { scheme in
                            Text(scheme.displayName)
                                .tag(scheme)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await viewModel.refreshPreview()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Preview")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        viewModel.exportHTML()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Export HTML")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .frame(width: 300)

            // Right side - Preview
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                        Text("Generating preview...")
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                } else if let html = viewModel.previewHTML {
                    WebView(html: html)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("No preview available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Select a template to see the preview")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
        .task {
            await viewModel.loadTemplates()
        }
        .onChange(of: viewModel.selectedTemplateId) { _ in
            Task { await viewModel.refreshPreview() }
        }
        .onChange(of: viewModel.selectedColorPalette) { _ in
            Task { await viewModel.refreshPreview() }
        }
        .onChange(of: viewModel.selectedFontScheme) { _ in
            Task { await viewModel.refreshPreview() }
        }
        .alert("Export Successful", isPresented: $viewModel.showingExportSuccess) {
            Button("OK") { }
        } message: {
            if let path = viewModel.exportedPath {
                Text("HTML exported to:\n\(path)")
            }
        }
    }
}

// MARK: - WebView

struct WebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - Extensions

extension ColorPalette {
    var displayName: String {
        switch self {
        case .professional: return "Professional"
        case .modern: return "Modern"
        case .minimal: return "Minimal"
        case .creative: return "Creative"
        }
    }
}

extension FontScheme {
    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .modern: return "Modern"
        case .serif: return "Serif"
        }
    }
}

extension Color {
    static func fromHex(_ hex: String) -> Color {
        var sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if sanitized.count == 3 {
            sanitized = sanitized.reduce(into: "") { result, character in
                result.append(String(repeating: character, count: 2))
            }
        }

        guard sanitized.count == 6,
              let value = UInt64(sanitized, radix: 16) else {
            return Color.gray
        }

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255

        return Color(red: red, green: green, blue: blue)
    }
}
