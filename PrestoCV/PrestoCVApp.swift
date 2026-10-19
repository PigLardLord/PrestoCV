//
//  PrestoCVApp.swift
//  PrestoCV
//
//  Created by Giovanni Trovato on 30/11/21.
//

import SwiftUI
import PrestoCVCore
import CVPDFExporter
import os

private let launchLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "launch")

/// The entry point, and the composition root of the app: the only place that reads the device and makes the real
/// services, which the view model factory then hands out.
@main
struct PrestoCVApp: App {
    private static let environment = AppEnvironment.device()
    private static let storage = LaunchEnvironment.storage(arguments: environment.arguments)
    /// The unsaved edits of the whole app, made once and shared by every window, so that each set of edits has one
    /// holder at a time, and is never offered while an editor holds it.
    private static let unsavedEdits = Result {
        try DependencyContainer.makeUnsavedEditsUseCase(in: storage.unsavedEdits())
    }

    var body: some Scene {
        WindowGroup {
            AppLaunchView(
                viewModel: AppLaunchViewModel(
                    makeDependencyContainer: { DependencyContainer(storageDirectory: Self.storage.cvs) },
                    makeUnsavedEdits: { try Self.unsavedEdits.get() },
                    environment: Self.environment,
                    bootstrapTemplates: { await Self.installBundledTemplates() }
                )
            )
        }
    }

    /// Installs the templates that ship with the app. A failure is logged and does not block the launch.
    nonisolated private static func installBundledTemplates() async {
        do {
            let bootstrapService = try TemplateBootstrapService()
            try await bootstrapService.syncBundledTemplates()
        } catch {
            launchLogger.error("Bundled templates were not installed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
