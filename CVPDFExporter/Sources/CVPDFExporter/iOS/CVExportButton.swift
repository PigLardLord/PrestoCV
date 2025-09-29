#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// SwiftUI button for exporting CV with QuickLook preview
public struct CVExportButton: View {

    // MARK: - Properties

    let cvData: Any
    let templateId: String
    let customization: CustomizationOptions

    @State private var isExporting = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let exportManager = CVExportManager()

    // MARK: - Initialization

    public init(
        cvData: Any,
        templateId: String = "modern",
        customization: CustomizationOptions = CustomizationOptions()
    ) {
        self.cvData = cvData
        self.templateId = templateId
        self.customization = customization
    }

    // MARK: - Body

    public var body: some View {
        Button(action: exportCV) {
            HStack(spacing: 8) {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                }

                Text(isExporting ? "Exporting..." : "Export PDF")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
                    .opacity(isExporting ? 0.6 : 1.0)
            )
        }
        .disabled(isExporting)
        .alert("Export Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Actions

    private func exportCV() {
        guard !isExporting else { return }

        isExporting = true

        Task {
            do {
                // Get the current UIViewController
                guard let viewController = UIApplication.shared.currentKeyWindow?.rootViewController else {
                    throw CVExportError.noViewController
                }

                // Find the topmost presented controller
                var topController = viewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }

                try await exportManager.exportAndPreview(
                    cvData: cvData,
                    templateId: templateId,
                    customization: customization,
                    from: topController
                )

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }

            await MainActor.run {
                isExporting = false
            }
        }
    }
}

// MARK: - UIKit Integration Helper

public class CVExportViewController: UIViewController {

    private let exportManager = CVExportManager()

    /// Presents CV export with QuickLook preview
    public func exportCV(
        data: Any,
        templateId: String = "modern",
        customization: CustomizationOptions = CustomizationOptions()
    ) {
        Task {
            do {
                try await exportManager.exportAndPreview(
                    cvData: data,
                    templateId: templateId,
                    customization: customization,
                    from: self
                )
            } catch {
                showError(error)
            }
        }
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Export Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Errors

enum CVExportError: LocalizedError {
    case noViewController

    var errorDescription: String? {
        switch self {
        case .noViewController:
            return "Unable to find view controller for presentation"
        }
    }
}

// MARK: - UIApplication Extension

private extension UIApplication {
    var currentKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

#endif