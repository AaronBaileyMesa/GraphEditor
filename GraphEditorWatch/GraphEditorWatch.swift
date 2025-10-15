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
        } else {
            Text("Loading...")
                .task {
                    let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
                    let storage = PersistenceManager()
                    let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
                    await model.loadGraph()
                    
                    model.nodes = model.nodes.map { anyNode in
                        let updated = anyNode.unwrapped.with(position: anyNode.position, velocity: CGPoint.zero)
                        return AnyNode(updated)
                    }
                    
                    let tempViewModel = GraphViewModel(model: model)
                    if let viewState = try? model.storage.loadViewState(for: model.currentGraphName) {
                        tempViewModel.offset = viewState.offset
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
