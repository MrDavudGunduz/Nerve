//
//  NerveApp.swift
//  Nerve
//
//  Created by Davud Gunduz on 25.03.2026.
//

import SwiftUI
import SwiftData

/// The main entry point for the Nerve application.
///
/// Nerve is a multiplatform app (iOS · macOS · visionOS) that provides
/// spatial news intelligence with on-device AI analysis.
@main
struct NerveApp: App {

    // MARK: - SwiftData Configuration

    /// Shared model container used across the entire application.
    ///
    /// Configured with persistent storage to enable offline-first functionality.
    /// All platform targets share the same schema and storage strategy.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
