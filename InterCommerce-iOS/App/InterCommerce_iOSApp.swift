//
//  InterCommerce_iOSApp.swift
//  App · composition root
//

import SwiftData
import SwiftUI

@main
struct InterCommerce_iOSApp: App {

    /// Built **once**. Calling `.live` per environment value would create a second `CatalogStore`,
    /// each with its own subscribers, and half the screens would stop seeing writes made by the
    /// other half.
    ///
    /// Opening the store can fail, and the template's answer to that was `fatalError`. Crashing on
    /// launch is the worst possible handling of "your data might still be there": the failure is
    /// carried as state instead, so the app can say what happened.
    private let graph: Result<AppDependencies, any Error>

    init() {
        graph = Result { AppDependencies.live(container: try ModelContainerFactory.live()) }
    }

    var body: some Scene {
        WindowGroup {
            switch graph {
            case .success(let dependencies):
                // The container reaches the stores through this graph, not through the environment:
                // no view reads SwiftData directly (ADR §30), so `.modelContainer` would inject
                // something nothing consumes.
                RootView()
                    .environment(\.dependencies, dependencies)
                    .environment(\.loadImage, dependencies.loadImage)
            case .failure(let error):
                PersistenceUnavailableView(error: error)
            }
        }
    }
}
