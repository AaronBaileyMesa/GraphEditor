//
//  ContentView.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//

// Views/ContentView.swift
import SwiftUI
import WatchKit
import GraphEditorShared
import Foundation

struct ContentView: View {
    @StateObject var viewModel: GraphViewModel
    @State private var zoomScale: CGFloat = 1.0
    @State private var minZoom: CGFloat = 0.2
    @State private var maxZoom: CGFloat = 5.0
    @State private var crownPosition: Double = 2.5
    @State private var viewSize: CGSize = .zero
    @State private var offset: CGSize = .zero
    @State private var panStartOffset: CGSize?
    @State private var draggedNode: (any NodeProtocol)? = nil  // Updated to existential for polymorphism
    @State private var dragOffset: CGPoint = .zero
    @State private var potentialEdgeTarget: (any NodeProtocol)? = nil  // Updated to existential
    @State private var ignoreNextCrownChange: Bool = false
    @State private var selectedNodeID: NodeID? = nil
    @State private var showMenu = false
    @State private var isZooming: Bool = false  // Track active zoom for pausing simulation
    @State private var selectedEdgeID: UUID? = nil  // New state
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousCrownPosition: Double = 2.5
    
    
    // New: Timer for debouncing simulation resume
    @State private var resumeTimer: Timer? = nil
    
    @State private var logOffsetChanges = true  // Toggle for console logs
    
    @State private var isPanning: Bool = false  // New: Track panning to pause clamping/simulation
    
    @State private var showOverlays: Bool = true  // New: Toggle for overlays (can bind to menu later)
    
    init(storage: GraphStorage = PersistenceManager(),
         physicsEngine: PhysicsEngine = PhysicsEngine(simulationBounds: WKInterfaceDevice.current().screenBounds.size)) {
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        _viewModel = StateObject(wrappedValue: GraphViewModel(model: model))
    }
    
    // Updated: Always recenter after updates unless panning
    private var onUpdateZoomRanges: () -> Void {
        return {
            self.updateZoomRanges()
            if !self.isPanning {
                self.clampOffset()
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {  // New: Use ZStack for overlays
                graphCanvasView(geo: geo)
                
                // New: Overlays (conditional on showOverlays)
                if showOverlays {
                    // Zoom level text at top-center
                    Text("Zoom: \(zoomScale, specifier: "%.1f")x")
                        .font(.caption2)  // Small font for Watch
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5))  // Semi-transparent bg for readability
                        .position(x: geo.size.width / 2, y: 20)  // Top-center

                }
                
            }
        }
        .ignoresSafeArea()  // New: Ignore safe area insets to fill screen top/bottom
        .sheet(isPresented: $showMenu) {
            menuView
        }
        .focusable()
        .digitalCrownRotation($crownPosition, from: 0.0, through: Double(AppConstants.numZoomLevels - 1), sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        
        .onChange(of: crownPosition) { newValue in
            if ignoreNextCrownChange {
                ignoreNextCrownChange = false
                previousCrownPosition = newValue
                return
            }
            
            let oldOffset = offset
            print("Crown changed from \(previousCrownPosition) to \(newValue), pausing simulation")
            isZooming = true
            resumeTimer?.invalidate()
            viewModel.model.pauseSimulation()
            resumeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                print("Resuming simulation after delay")
                isZooming = false
                viewModel.model.resumeSimulation()
            }
            
            updateZoomScale(oldCrown: previousCrownPosition)  // Simplified call
            previousCrownPosition = newValue
            clampOffset()
            
            let newOffset = offset
            if newOffset != oldOffset && logOffsetChanges {
                print("Offset changed during zoom: from \(oldOffset) to \(newOffset)")
            }
        }
        .onReceive(viewModel.model.$nodes) { _ in
            onUpdateZoomRanges()
        }
        .onChange(of: panStartOffset) { newValue in
            isPanning = newValue != nil
            if isPanning {
                viewModel.model.stopSimulation()
            } else {
                resumeTimer?.invalidate()
                let block: (Timer) -> Void = { [self] _ in
                    self.viewModel.model.startSimulation()
                }
                resumeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: block)  // Extended to 1s
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                viewModel.model.startSimulation()
            case .inactive, .background:
                viewModel.model.stopSimulation()
            @unknown default:
                break
            }
        }
        .onAppear {
            viewSize = WKInterfaceDevice.current().screenBounds.size
            onUpdateZoomRanges()
            viewModel.model.startSimulation()
            previousCrownPosition = crownPosition  // New: Init previous
        }
    }
    
    private func graphCanvasView(geo: GeometryProxy) -> some View {
        GraphCanvasView(
            viewModel: viewModel,
            zoomScale: $zoomScale,
            offset: $offset,
            draggedNode: $draggedNode,
            dragOffset: $dragOffset,
            potentialEdgeTarget: $potentialEdgeTarget,
            selectedNodeID: $selectedNodeID,
            viewSize: geo.size,
            panStartOffset: $panStartOffset,
            showMenu: $showMenu,
            maxZoom: maxZoom,
            crownPosition: $crownPosition,
            onUpdateZoomRanges: onUpdateZoomRanges,
            selectedEdgeID: $selectedEdgeID,
            showOverlays: $showOverlays  // Pass the binding
        )
        .onAppear {
            viewSize = geo.size
        }
    }
    
    // Completed menuView with node/edge delete logic (add toggle for simulation lock if desired)
    private var menuView: some View {
        VStack {
            if let selectedID = selectedNodeID,
               let selectedNode = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
                Button("Delete Node \(selectedNode.label)") {
                    viewModel.snapshot()
                    viewModel.model.deleteNode(withID: selectedID)
                    viewModel.model.startSimulation()
                    selectedNodeID = nil
                    showMenu = false
                    WKInterfaceDevice.current().play(.success)
                }
            } else if let selectedEdge = selectedEdgeID {
                Button("Delete Edge") {
                    viewModel.snapshot()
                    viewModel.model.deleteSelectedEdge(id: selectedEdge)
                    viewModel.model.startSimulation()
                    selectedEdgeID = nil
                    showMenu = false
                    WKInterfaceDevice.current().play(.success)
                }
            }
            Button("Add Node") {
                viewModel.snapshot()
                viewModel.model.addNode(at: CGPoint(x: viewSize.width / 2, y: viewSize.height / 2))
                viewModel.model.startSimulation()
                showMenu = false
                WKInterfaceDevice.current().play(.success)
            }
            Button("Undo") {
                viewModel.undo()
                showMenu = false
                WKInterfaceDevice.current().play(.success)
            }
            .disabled(!viewModel.canUndo)
            Button("Redo") {
                viewModel.redo()
                showMenu = false
                WKInterfaceDevice.current().play(.success)
            }
            .disabled(!viewModel.canRedo)
            Button("Toggle Overlays") {
                showOverlays.toggle()
                showMenu = false
            }
            Button("Close") {
                showMenu = false
            }
        }
        .padding()
    }
    
    // Existing function (unchanged, but called in onUpdateZoomRanges)
    private func updateZoomRanges() {
        guard !viewModel.model.nodes.isEmpty else {
            minZoom = 0.2
            maxZoom = 5.0
            return
        }
        
        let bbox = viewModel.model.boundingBox()
        let graphWidth = Swift.max(bbox.width, CGFloat(20)) + CGFloat(20)
        let graphHeight = Swift.max(bbox.height, CGFloat(20)) + CGFloat(20)
        let graphDia = Swift.max(graphWidth, graphHeight)
        let targetDia = Swift.min(viewSize.width, viewSize.height) / CGFloat(3)
        let newMinZoom = targetDia / graphDia
        
        let nodeDia = 2 * AppConstants.nodeModelRadius
        let targetNodeDia = Swift.min(viewSize.width, viewSize.height) * (CGFloat(2) / CGFloat(3))
        let newMaxZoom = targetNodeDia / nodeDia
        
        minZoom = newMinZoom
        maxZoom = Swift.max(newMaxZoom, newMinZoom * CGFloat(2))
        
        let currentScale = zoomScale
        var progress: CGFloat = 0.5
        if minZoom < currentScale && currentScale < maxZoom && minZoom > 0 && maxZoom > minZoom {
            progress = CGFloat(log(Double(currentScale / minZoom)) / log(Double(maxZoom / minZoom)))
        } else if currentScale <= minZoom {
            progress = 0.0
        } else {
            progress = 1.0
        }
        progress = progress.clamped(to: 0.0...1.0)  // Explicit clamp to [0,1] with CGFloat range
        let newCrown = Double(progress * CGFloat(AppConstants.numZoomLevels - 1))
        if abs(newCrown - crownPosition) > 1e-6 {
            ignoreNextCrownChange = true
            crownPosition = newCrown
        }
    }
    
    // Updated: Center on selected if present and zoomed in; no y-bias
    private func updateZoomScale(oldCrown: Double) {
        let clampedOldCrown = Swift.max(0, Swift.min(oldCrown, Double(AppConstants.numZoomLevels - 1)))
        
        let oldProgress = clampedOldCrown / Double(AppConstants.numZoomLevels - 1)
        let oldScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), Double(oldProgress)))
        
        let newProgress = crownPosition / Double(AppConstants.numZoomLevels - 1)
        let newScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), Double(newProgress)))
        
        zoomScale = newScale
    }
    
    // Updated: More padding at high zoom for better panning
    private func clampOffset() {
        let paddingFactor: CGFloat = zoomScale > 3.0 ? 0.5 : 0.25  // More room at high zoom
        let paddingX = viewSize.width * paddingFactor
        let paddingY = viewSize.height * paddingFactor
        
        let visibleNodes = viewModel.model.visibleNodes()
        guard !visibleNodes.isEmpty else { return }
        
        // Compute effective centroid (matches GraphCanvasView)
        var effectiveCentroid = visibleNodes.reduce(CGPoint.zero) { acc, node in acc + node.position } / CGFloat(visibleNodes.count)
        if let selectedID = selectedNodeID, let selected = visibleNodes.first(where: { $0.id == selectedID }) {
            effectiveCentroid = selected.position
        } else if let selectedEdge = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdge }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }), let to = visibleNodes.first(where: { $0.id == edge.to }) {
            effectiveCentroid = (from.position + to.position) / 2.0
        }
        
        // Compute relative BBox min/max from effective centroid
        var minRel = CGPoint(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude)
        var maxRel = CGPoint(x: -CGFloat.greatestFiniteMagnitude, y: -CGFloat.greatestFiniteMagnitude)
        for node in visibleNodes {
            let rel = node.position - effectiveCentroid
            minRel.x = min(minRel.x, rel.x)
            minRel.y = min(minRel.y, rel.y)
            maxRel.x = max(maxRel.x, rel.x)
            maxRel.y = max(maxRel.y, rel.y)
        }
        
        // Scale relative extents
        let scaledMinX = minRel.x * zoomScale
        let scaledMaxX = maxRel.x * zoomScale
        let scaledMinY = minRel.y * zoomScale
        let scaledMaxY = maxRel.y * zoomScale
        
        // Clamp offsets to keep BBox within view with padding
        let minOffsetX = (viewSize.width / 2 - paddingX) - scaledMaxX
        let maxOffsetX = (viewSize.width / 2 + paddingX) - scaledMinX
        let minOffsetY = (viewSize.height / 2 - paddingY) - scaledMaxY
        let maxOffsetY = (viewSize.height / 2 + paddingY) - scaledMinY
        
        offset.width = max(min(offset.width, maxOffsetX), minOffsetX)
        offset.height = max(min(offset.height, maxOffsetY), minOffsetY)
    }
}


extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

#Preview {
    ContentView()
}
