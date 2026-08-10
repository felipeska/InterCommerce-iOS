//
//  InterCommerce_iOSApp.swift
//  App · composition root
//

import SwiftData
import SwiftUI

@main
struct InterCommerce_iOSApp: App {

    /// Opening the store can fail, and the template's answer to that was `fatalError`. Crashing on
    /// launch is the worst possible handling of "your data might still be there": the user gets a
    /// dead app and no way to report it. The failure is carried as state instead, so the app can
    /// say what happened.
    private let container: Result<ModelContainer, any Error>

    init() {
        container = Result { try ModelContainerFactory.live() }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success:
                // The container is handed to the stores through the dependency graph, not through
                // the environment: no view reads SwiftData directly (ADR §30), so `.modelContainer`
                // would inject something nothing consumes.
                RootView()
            case .failure(let error):
                PersistenceUnavailableView(error: error)
            }
        }
    }
}
