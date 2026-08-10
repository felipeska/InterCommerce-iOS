//
//  ModelContainerFactory.swift
//  Data · Persistence
//
//  Where the store lives, and what happens when it cannot be opened.
//

import Foundation
import SwiftData

nonisolated enum ModelContainerFactory {

    /// The on-disk container.
    ///
    /// - Note: it never falls back to recreating the store. Wiping a corrupt database would take
    ///   the user's cart with it — the one thing this app promises to keep. A failure here is
    ///   surfaced, not papered over.
    static func live() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(
                schema: Schema(versionedSchema: SchemaV1.self),
                isStoredInMemoryOnly: false
            )
        )
    }

    /// A throwaway container for tests: no file, no state carried between runs.
    static func inMemory() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV1.self),
            migrationPlan: AppMigrationPlan.self,
            configurations: ModelConfiguration(
                schema: Schema(versionedSchema: SchemaV1.self),
                isStoredInMemoryOnly: true
            )
        )
    }
}
