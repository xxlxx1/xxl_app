//
//  xxl_appApp.swift
//  xxl_app
//
//  Created by xxl on 2026/2/13.
//

import SwiftUI
import SwiftData

@main
struct xxl_appApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            CalendarPhotoView()
        }
        .modelContainer(sharedModelContainer)
    }
}
