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
                let physicsEngine = PhysicsEngine(simulationBounds: screenBounds)
                let storage: any GraphStorage = MockGraphStorage()
                let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
                let viewModel = GraphViewModel(model: model)
                ContentView(viewModel: viewModel)
                    .debugViewHierarchy()
                    .onAppear {
                        print("[GraphEditorWatch] UI Test mode - ContentView appeared directly")
                    }
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
            .onAppear {
                print("[ContentLoaderView] ContentView appeared!")
            }
        } else {
            Text("Loading...")
                .accessibilityIdentifier("LoadingView")
                .onAppear {
                    print("[ContentLoaderView] onAppear called!")
                    Task {
                    await MainActor.run {
                        print("[ContentLoaderView] Task started on MainActor")
                    }
                    
                    let isUITest = CommandLine.arguments.contains("--uitest-mock-storage")
                    let skipLoading = CommandLine.arguments.contains("--uitest-skip-loading")
                    print("[ContentLoaderView] isUITest=\(isUITest), skipLoading=\(skipLoading)")

                    let screenBounds = WKInterfaceDevice.current().screenBounds.size
                    print("[ContentLoaderView] Screen bounds: \(screenBounds)")
                    let physicsEngine = PhysicsEngine(simulationBounds: screenBounds)
                    print("[ContentLoaderView] PhysicsEngine created")

                    // MODIFIED: Conditional storage
                    let storage: any GraphStorage = isUITest ? MockGraphStorage() : PersistenceManager()
                    print("[ContentLoaderView] Storage created: \(type(of: storage))")

                    let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
                    print("[ContentLoaderView] GraphModel created")

                    if isUITest && skipLoading {
                        print("[ContentLoaderView] Taking fast path (skip loading)")
                        await MainActor.run {
                            self.viewModel = GraphViewModel(model: model)
                            print("[ContentLoaderView] ViewModel set on MainActor: \(self.viewModel != nil)")
                        }
                    } else {
                        // Existing if-else for load/skip – unchanged, now nested
                        if isUITest {
                            await model.initializeDefaultGraph()
                        } else {
                            do {
                                try await model.loadGraph()
                            } catch {
                                print("Failed to load graph: \(error.localizedDescription)")
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
                            print("Loaded view state for '\(model.currentGraphName)'")
                        }
                        await MainActor.run {
                            self.viewModel = tempViewModel
                            print("[ContentLoaderView] ViewModel set (slow path) on MainActor: \(self.viewModel != nil)")
                        }
                        // FIXED: Start simulation paused to allow gesture recognition to work
                        // The constant 30fps recomputation was blocking tap detection
                        // User can enable simulation from the menu if needed
                        if !CommandLine.arguments.contains("--uitest-no-simulation") {
                            // Simulation will auto-start when user interacts, but don't start it immediately
                            // await tempViewModel.model.startSimulation()
                            print("[ContentLoaderView] Simulation paused on launch to enable gesture recognition")
                        }
                    }
                    print("[ContentLoaderView] Task completed")
                    }
                }
        }
    }
}

