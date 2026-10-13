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
    var body: some Scene {
        WindowGroup {
            AppLaunchView(makeDependencyContainer: { DependencyContainer() })
        }
    }
}
