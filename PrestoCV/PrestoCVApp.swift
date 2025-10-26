//
//  PrestoCVApp.swift
//  PrestoCV
//
//  Created by Giovanni Trovato on 30/11/21.
//

import SwiftUI
import PrestoCVCore
import CVPDFExporter

@main
struct PrestoCVApp: App {
    private let dependencyContainer = DependencyContainer()

    init() {
        // Bootstrap bundled templates on app launch
        Task {
            await bootstrapBundledTemplates()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencyContainer: dependencyContainer)
        }
    }

    // MARK: - Private Methods

    /// Bootstraps bundled templates by synchronizing with registry
    /// Runs asynchronously on background queue to avoid blocking UI
    private func bootstrapBundledTemplates() async {
        do {
            let bootstrapService = try TemplateBootstrapService()
            try await bootstrapService.syncBundledTemplates()
        } catch {
            // Log error but don't crash app - templates can still work from existing registry
            print("⚠️ Template bootstrap failed: \(error.localizedDescription)")
        }
    }
}
