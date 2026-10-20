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
                                recoveredName: Self.recoveredName
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

    /// What a copy made of leftover edits is called: the name of the CV they were made on, or of the person, marked as
    /// recovered.
    nonisolated private static func recoveredName(of cv: CVModel) -> String {
        let names = [cv.name, cv.personalInfo.name].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let name = names.first { !$0.isEmpty } ?? String(localized: "cv.untitled")
        let recovered = String(localized: "unsaved_edits.recovered_suffix")
        return "\(name) \(recovered)"
    }
}
