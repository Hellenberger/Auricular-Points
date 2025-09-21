//
//  Auricular_PointsApp.swift
//  Auricular Points
//
//  Created by Howard Ellenberger on 9/20/25.
//

import SwiftUI

// MARK: - UI

@main
struct AuricularPointsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 960, height: 720)
        #endif
    }
}
