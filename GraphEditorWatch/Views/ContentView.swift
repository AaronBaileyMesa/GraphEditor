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
    
    init(storage: GraphStorage = PersistenceManager(),
         physicsEngine: PhysicsEngine = PhysicsEngine(simulationBounds: WKInterfaceDevice.current().screenBounds.size)) {
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        _viewModel = StateObject(wrappedValue: GraphViewModel(model: model))
    }
    
    // New: Define the shared closure here (incorporates your existing logic + offset clamping)
    // In ContentView, update the onUpdateZoomRanges closure:
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
            graphCanvasView(geo: geo)
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
            
            // Pause simulation on crown interaction
            viewModel.model.stopSimulation()
            isZooming = true
            resumeTimer?.invalidate()
            
            // Explicitly typed closure to fix inference
            let resumeBlock: (Timer) -> Void = { [self] _ in  // Discard timer if unused
                self.isZooming = false
                self.viewModel.model.startSimulation()  // Use startSimulation (safe to call multiple times)
            }
            resumeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: resumeBlock)
            
            // Integrated updates here
            let oldOffset = offset  // For logging
            updateZoomScale(oldCrown: oldValue, adjustOffset: true)
            clampOffset()  // Clamp after zoom adjustment
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
                resumeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: block)
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
    
    // Completed menuView with node/edge delete logic
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
    
    // Updates the zoom scale and adjusts offset if needed.
    private func updateZoomScale(oldCrown: Double, adjustOffset: Bool) {
        // Clamp oldCrown to valid range (prevents invalid oldScale)
        let clampedOldCrown = Swift.max(0, Swift.min(oldCrown, Double(AppConstants.numZoomLevels - 1)))
        
        let oldProgress = clampedOldCrown / Double(AppConstants.numZoomLevels - 1)
        let oldScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), Double(oldProgress)))
        
        let newProgress = crownPosition / Double(AppConstants.numZoomLevels - 1)
        let newScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), Double(newProgress)))
        
        if adjustOffset && oldScale != newScale && viewSize != .zero {
            // Center focus without bias
            let focus = CGPoint(x: viewSize.width / 2, y: viewSize.height * 0.5)
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
    
    private func clampOffset() {
        let paddingX = viewSize.width * 0.25
        let paddingY = viewSize.height * 0.25
        
        let bbox = self.viewModel.model.physicsEngine.boundingBox(nodes: self.viewModel.model.visibleNodes())
        
        let scaledMinX = bbox.minX * self.zoomScale
        let scaledMaxX = bbox.maxX * self.zoomScale
        let scaledMinY = bbox.minY * self.zoomScale
        let scaledMaxY = bbox.maxY * self.zoomScale
        
        let minOffsetX = -scaledMinX - paddingX
        let maxOffsetX = self.viewSize.width - scaledMaxX + paddingX
        let minOffsetY = -scaledMinY - paddingY
        let maxOffsetY = self.viewSize.height - scaledMaxY + paddingY
        
        let clampedMinX = Swift.min(minOffsetX, maxOffsetX)
        let clampedMaxX = Swift.max(minOffsetX, maxOffsetX)
        let clampedMinY = Swift.min(minOffsetY, maxOffsetY)
        let clampedMaxY = Swift.max(minOffsetY, maxOffsetY)
        
        self.offset.width = Swift.max(Swift.min(self.offset.width, clampedMaxX), clampedMinX)
        self.offset.height = Swift.max(Swift.min(self.offset.height, clampedMaxY), clampedMinY)
    }
    
    
    private func centerGraph() {
        guard !viewModel.model.nodes.isEmpty else { return }
        
        // Compute centroid
        let totalX = viewModel.model.nodes.reduce(0.0) { $0 + $1.position.x }
        let totalY = viewModel.model.nodes.reduce(0.0) { $0 + $1.position.y }
        let centroid = CGPoint(x: totalX / CGFloat(viewModel.model.nodes.count), y: totalY / CGFloat(viewModel.model.nodes.count))
        
        // Set offset to center centroid
        offset = CGSize(
            width: viewSize.width / 2 - centroid.x * zoomScale,
            height: viewSize.height / 2 - centroid.y * zoomScale
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
