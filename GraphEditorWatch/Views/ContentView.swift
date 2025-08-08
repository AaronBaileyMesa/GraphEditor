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

    @State private var showOverlay: Bool = true  // New: Toggle for overlays (can bind to menu later)
    
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
                self.centerGraph()  // Recenters on centroid or selected
                self.clampOffset()
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {  // New: Use ZStack for overlays
                graphCanvasView(geo: geo)
                
                // New: Overlays (conditional on showOverlay)
                if showOverlay {
                    // Zoom level text at top-center
                    Text("Zoom: \(zoomScale, specifier: "%.1f")x")
                        .font(.caption2)  // Small font for Watch
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5))  // Semi-transparent bg for readability
                        .position(x: geo.size.width / 2, y: 20)  // Top-center
                    
                    // Model space borders (bounding box outline)
                    if !viewModel.model.nodes.isEmpty {
                        let modelBBox = viewModel.model.boundingBox()
                        let screenMinX = modelBBox.minX * zoomScale + offset.width
                        let screenMinY = modelBBox.minY * zoomScale + offset.height
                        let screenWidth = modelBBox.width * zoomScale
                        let screenHeight = modelBBox.height * zoomScale
                        
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 1)  // Blue outline
                            .frame(width: screenWidth, height: screenHeight)
                            .position(x: screenMinX + screenWidth / 2, y: screenMinY + screenHeight / 2)
                    }
                    
                    // Future overlays can go here, e.g.:
                    // if someCondition {
                    //     Text("Node Count: \(viewModel.model.nodes.count)")
                    //         .position(x: geo.size.width / 2, y: geo.size.height - 20)  // Bottom-center
                    // }
                }
            }
        }
        .ignoresSafeArea()  // New: Ignore safe area insets to fill screen top/bottom
        .sheet(isPresented: $showMenu) {
            menuView
        }
        .focusable()
        .digitalCrownRotation($crownPosition, from: 0.0, through: Double(AppConstants.numZoomLevels - 1), sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crownPosition) { newValue in  // Single parameter for watchOS 9 compatibility
            let oldValue = previousCrownPosition  // Manually get "old" from stored state
            
            if ignoreNextCrownChange {
                ignoreNextCrownChange = false
                // Skip update if just clamping (prevents invalid calls)
                return
            }
            
            let maxCrown = Double(AppConstants.numZoomLevels - 1)
            let clampedValue = Swift.max(0, Swift.min(newValue, maxCrown))
            if clampedValue != newValue {
                ignoreNextCrownChange = true  // Prevent feedback loop on set
                crownPosition = clampedValue
                previousCrownPosition = clampedValue  // Update previous immediately for clamping
                return
            }
            
            // Pause simulation on crown interaction (longer delay for stability)
            viewModel.model.stopSimulation()
            isZooming = true
            resumeTimer?.invalidate()
            
            // Explicitly typed closure to fix inference
            let resumeBlock: (Timer) -> Void = { [self] _ in  // Discard timer if unused
                self.isZooming = false
                self.viewModel.model.startSimulation()  // Use startSimulation (safe to call multiple times)
            }
            resumeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false, block: resumeBlock)  // Extended to 1s
            
            // Integrated updates here
            let oldOffset = offset  // For logging
            updateZoomScale(oldCrown: oldValue, adjustOffset: true)
            clampOffset()  // Clamp after zoom adjustment
            if selectedNodeID == nil && selectedEdgeID == nil {
                centerGraph()
            }
            if logOffsetChanges && oldOffset != offset {
                print("Offset changed during zoom: from \(oldOffset) to \(offset)")
            }
            
            previousCrownPosition = newValue  // Update previous at end
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
            centerGraph()
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
            selectedEdgeID: $selectedEdgeID
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
    private func updateZoomScale(oldCrown: Double, adjustOffset: Bool) {
        // Clamp oldCrown to valid range (prevents invalid oldScale)
        let clampedOldCrown = Swift.max(0, Swift.min(oldCrown, Double(AppConstants.numZoomLevels - 1)))
        
        let oldProgress = clampedOldCrown / Double(AppConstants.numZoomLevels - 1)
        let oldScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), Double(oldProgress)))
        
        let newProgress = crownPosition / Double(AppConstants.numZoomLevels - 1)
        let newScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), Double(newProgress)))
        
        if adjustOffset && oldScale != newScale && viewSize != .zero {
            // Default focus: screen center
            var focus = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
            
            // Override with selected node if present
            if let selectedID = selectedNodeID, let selectedNode = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
                // Convert selected node model pos to old screen pos
                let selectedScreenX = selectedNode.position.x * oldScale + offset.width
                let selectedScreenY = selectedNode.position.y * oldScale + offset.height
                focus = CGPoint(x: selectedScreenX, y: selectedScreenY)
            } else if let selectedEdge = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdge }),
                      let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }), let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                // For edge, focus on midpoint
                let midX = (fromNode.position.x + toNode.position.x) / 2
                let midY = (fromNode.position.y + toNode.position.y) / 2
                let midScreenX = midX * oldScale + offset.width
                let midScreenY = midY * oldScale + offset.height
                focus = CGPoint(x: midScreenX, y: midScreenY)
            }
            
            let worldFocus = CGPoint(
                x: (focus.x - offset.width) / oldScale,
                y: (focus.y - offset.height) / oldScale
            )
            offset = CGSize(
                width: focus.x - worldFocus.x * newScale,
                height: focus.y - worldFocus.y * newScale
            )
        }
        
        zoomScale = newScale
    }
    
    // Updated: More padding at high zoom for better panning
    private func clampOffset() {
        let paddingFactor: CGFloat = zoomScale > 3.0 ? 0.5 : 0.25  // More room at high zoom
        let paddingX = viewSize.width * paddingFactor
        let paddingY = viewSize.height * paddingFactor
        
        let bbox = self.viewModel.model.physicsEngine.boundingBox(nodes: self.viewModel.model.visibleNodes())
        
        let scaledMinX = bbox.minX * self.zoomScale
        let scaledMaxX = bbox.maxX * self.zoomScale
        let scaledMinY = bbox.minY * self.zoomScale
        let scaledMaxY = bbox.maxY * self.zoomScale
        
        let minOffsetX = viewSize.width - scaledMaxX - paddingX
        let maxOffsetX = -scaledMinX + paddingX
        let minOffsetY = viewSize.height - scaledMaxY - paddingY
        let maxOffsetY = -scaledMinY + paddingY
        
        let clampedMinX = Swift.min(minOffsetX, maxOffsetX)
        let clampedMaxX = Swift.max(minOffsetX, maxOffsetX)
        let clampedMinY = Swift.min(minOffsetY, maxOffsetY)
        let clampedMaxY = Swift.max(minOffsetY, maxOffsetY)
        
        self.offset.width = Swift.max(Swift.min(self.offset.width, clampedMaxX), clampedMinX)
        self.offset.height = Swift.max(Swift.min(self.offset.height, clampedMaxY), clampedMinY)
    }
    
    // Updated: Center on selected if present, else centroid
    private func centerGraph() {
        guard !viewModel.model.nodes.isEmpty else { return }
        
        var centerPoint: CGPoint
        
        if let selectedID = selectedNodeID, let selectedNode = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
            centerPoint = selectedNode.position  // Center on selected node
        } else if let selectedEdge = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdge }),
                  let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }), let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
            // Center on edge midpoint
            centerPoint = CGPoint(x: (fromNode.position.x + toNode.position.x) / 2, y: (fromNode.position.y + toNode.position.y) / 2)
        } else {
            // Default: Centroid
            let totalX = viewModel.model.nodes.reduce(0.0) { $0 + $1.position.x }
            let totalY = viewModel.model.nodes.reduce(0.0) { $0 + $1.position.y }
            centerPoint = CGPoint(x: totalX / CGFloat(viewModel.model.nodes.count), y: totalY / CGFloat(viewModel.model.nodes.count))
        }
        
        // Set offset to center the point
        offset = CGSize(
            width: viewSize.width / 2 - centerPoint.x * zoomScale,
            height: viewSize.height / 2 - centerPoint.y * zoomScale
        )
        
        clampOffset()  // Clamp after centering
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
