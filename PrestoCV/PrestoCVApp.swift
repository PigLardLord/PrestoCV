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
    private let storageDirectory = LaunchEnvironment.storageDirectory()

    var body: some Scene {
        WindowGroup {
            AppLaunchView(makeDependencyContainer: { [storageDirectory] in DependencyContainer(storageDirectory: storageDirectory) })
        }
    }
}
