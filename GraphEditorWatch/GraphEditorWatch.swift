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
            // For UI tests, create ViewModel immediately; otherwise use loader
            if CommandLine.arguments.contains("--uitest-skip-loading") {
                let screenBounds = WKInterfaceDevice.current().screenBounds.size
                // Use larger simulation bounds (4x screen size) to avoid boundary constraints
                let simulationBounds = CGSize(width: screenBounds.width * 4, height: screenBounds.height * 4)
                let physicsEngine = PhysicsEngine(simulationBounds: simulationBounds)
                let storage: any GraphStorage = MockGraphStorage()
                let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
                let viewModel = GraphViewModel(model: model)
                ContentView(viewModel: viewModel)
                    .debugViewHierarchy()
            } else {
                ContentLoaderView(initialViewModel: nil)
            }
        }
    }
}

struct ContentLoaderView: View {
    @State private var viewModel: GraphViewModel?
    let initialViewModel: GraphViewModel?
    
    init(initialViewModel: GraphViewModel? = nil) {
        self.initialViewModel = initialViewModel
        if let initial = initialViewModel {
            _viewModel = State(initialValue: initial)
        }
    }
    
    var body: some View {
        if let viewModel = viewModel {
            ContentView(
                viewModel: viewModel
            )
            .debugViewHierarchy()
        } else {
            Text("Loading...")
                .accessibilityIdentifier("LoadingView")
                .onAppear {
                    Task {
                    let isUITest = CommandLine.arguments.contains("--uitest-mock-storage")
                    let skipLoading = CommandLine.arguments.contains("--uitest-skip-loading")

                    let screenBounds = WKInterfaceDevice.current().screenBounds.size
                    // Use larger simulation bounds (4x screen size) to avoid boundary constraints
                    let simulationBounds = CGSize(width: screenBounds.width * 4, height: screenBounds.height * 4)
                    let physicsEngine = PhysicsEngine(simulationBounds: simulationBounds)

                    // MODIFIED: Conditional storage
                    let storage: any GraphStorage = isUITest ? MockGraphStorage() : PersistenceManager()

                    let model = GraphModel(storage: storage, physicsEngine: physicsEngine)

                    if isUITest && skipLoading {
                        await MainActor.run {
                            self.viewModel = GraphViewModel(model: model)
                        }
                    } else {
                        // Existing if-else for load/skip – unchanged, now nested
                        if isUITest {
                            await model.initializeDefaultGraph()
                        } else {
                            do {
                                try await model.loadGraph()
                            } catch {
                                #if DEBUG
                                print("Failed to load graph: \(error.localizedDescription)")
                                #endif
                                await model.initializeDefaultGraph()
                            }
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
                        }
                        await MainActor.run {
                            self.viewModel = tempViewModel
                        }
                        // FIXED: Start simulation paused to allow gesture recognition to work
                        // The constant 30fps recomputation was blocking tap detection
                        // User can enable simulation from the menu if needed
                    }
                    }
                }
        }
    }
}
