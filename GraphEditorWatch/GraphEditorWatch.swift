//
//  GraphEditorWatch.swift
//  GraphEditorWatch Watch App
//
//  Created by handcart on 8/1/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared

// In GraphEditorWatch.swift
@main
struct GraphEditorWatch: App {
    var body: some Scene {
        WindowGroup {
            let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))  // Mock bounds; adjust as needed
            let model = GraphModel(storage: PersistenceManager(), physicsEngine: physicsEngine)
            let viewModel = GraphViewModel(model: model)  // Create viewModel here
            ContentView(viewModel: viewModel)  // <-- Pass viewModel to ContentView init
        }
    }
}
