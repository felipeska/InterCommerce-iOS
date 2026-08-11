//
//  AppEnvironment.swift
//  App · composition root
//
//  How the graph reaches the views.
//

import SwiftUI

extension EnvironmentValues {
    /// The dependency graph. Screens read it to *build* their model; models never read it.
    @Entry var dependencies: AppDependencies = .preview
}
