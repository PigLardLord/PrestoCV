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

    var body: some Scene {
        WindowGroup {
            if LaunchEnvironment.hostsUnitTests(arguments: Self.environment.arguments) {
                EmptyView()
            } else {
                AppLaunchView(
                    viewModel: AppLaunchViewModel(
                        makeDependencyContainer: { DependencyContainer(storageDirectory: Self.storage.cvs) },
                        makeLeftoverEdits: { cvs in
                            try DependencyContainer.makeLeftoverEditsImport(
                                in: Self.storage.unsavedEdits(),
                                cvs: cvs,
                                recoveredName: { $0.recoveredCopyName }
                            )
                        },
                        environment: Self.environment,
                        bootstrapTemplates: { await Self.installBundledTemplates() }
                    )
                )
            }
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
