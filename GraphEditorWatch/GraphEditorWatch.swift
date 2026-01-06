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
    @State private var crownPosition: Double = Double(AppConstants.crownZoomSteps) / 2.0
    var body: some Scene {
        WindowGroup {
            ContentLoaderView()
        }
    }
}

struct ContentLoaderView: View {
    @State private var viewModel: GraphViewModel?
    
    var body: some View {
        if let viewModel = viewModel {
            ContentView(
                viewModel: viewModel
            )
            .debugViewHierarchy()  
        } else {
            Text("Loading...")
                .task {
                    let screenBounds = WKInterfaceDevice.current().screenBounds.size
                    let physicsEngine = PhysicsEngine(simulationBounds: screenBounds)
                    let storage = PersistenceManager()
                    let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
                    
                    do {
                        try await model.loadGraph()  // Handle success path
                    } catch {
                        // Handle the error gracefully (e.g., log it, show a fallback UI, or initialize defaults)
                        print("Failed to load graph: \(error.localizedDescription)")
                        // Optional: Call your default initialization here if needed
                        await model.initializeDefaultGraph()  // Assuming you have this method from previous fixes
                    }
                    
                    model.nodes = model.nodes.map { anyNode in
                        let updated = anyNode.unwrapped.with(position: anyNode.position, velocity: CGPoint.zero)
                        return AnyNode(updated)
                    }
                    
                    let tempViewModel = GraphViewModel(model: model)
                    if let viewState = try? model.storage.loadViewState(for: model.currentGraphName) {
                        tempViewModel.offset = CGSize(width: viewState.offset.width, height: viewState.offset.height)
                        tempViewModel.zoomScale = viewState.zoomScale
                        tempViewModel.selectedNodeID = viewState.selectedNodeID
                        tempViewModel.selectedEdgeID = viewState.selectedEdgeID
                        print("Loaded view state for '\(model.currentGraphName)'")
                    }
                    self.viewModel = tempViewModel
                    await tempViewModel.model.startSimulation()
                }
        }
    }
}
