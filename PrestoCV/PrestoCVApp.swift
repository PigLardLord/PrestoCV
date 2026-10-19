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
    private static let storage = LaunchEnvironment.storage()
    /// The unsaved edits of the whole app, made once and shared by every window, so that each set of edits has one
    /// holder at a time, and is never offered while an editor holds it.
    private static let unsavedEdits = Result {
        try DependencyContainer.makeUnsavedEditsUseCase(in: storage.unsavedEdits())
    }

    var body: some Scene {
        WindowGroup {
            AppLaunchView(
                makeDependencyContainer: { DependencyContainer(storageDirectory: Self.storage.cvs) },
                makeUnsavedEdits: { try Self.unsavedEdits.get() }
            )
        }
    }
}
