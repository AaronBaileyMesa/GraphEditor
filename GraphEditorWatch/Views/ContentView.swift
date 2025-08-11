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
    @State private var offset: CGSize = .zero
    @State private var draggedNode: (any NodeProtocol)? = nil
    @State private var dragOffset: CGPoint = .zero
    @State private var potentialEdgeTarget: (any NodeProtocol)? = nil
    @State private var selectedNodeID: NodeID? = nil
    @State private var selectedEdgeID: UUID? = nil
    @State private var panStartOffset: CGSize? = nil
    @State private var showMenu = false
    @State private var showOverlays = false
    @State private var minZoom: CGFloat = 0.2
    @State private var maxZoom: CGFloat = 5.0
    @State private var crownPosition: Double = 0.5
    @State private var viewSize: CGSize = .zero
    @State private var ignoreNextCrownChange: Bool = false
    @State private var isZooming: Bool = false  // Track active zoom for pausing simulation
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousCrownPosition: Double = 0.5
    
    
    // New: Timer for debouncing simulation resume
    @State private var resumeTimer: Timer? = nil
    
    @State private var logOffsetChanges = true  // Toggle for console logs
    
    @State private var isPanning: Bool = false  // New: Track panning to pause clamping/simulation
    
    
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
        let geoReader: some View = GeometryReader { geo in
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
                showOverlays: $showOverlays
            )
        }
        
        let withIgnore: some View = geoReader.ignoresSafeArea()
        
        let withSheet: some View = withIgnore.sheet(isPresented: $showMenu) {
            NavigationStack {
                List {
                    AddSection(
                        viewModel: viewModel,
                        selectedNodeID: selectedNodeID,
                        onDismiss: { showMenu = false }
                    )
                    EditSection(
                        viewModel: viewModel,
                        selectedNodeID: selectedNodeID,
                        selectedEdgeID: selectedEdgeID,
                        onDismiss: { showMenu = false }
                    )
                    ViewSection(
                        isSimulating: viewModel.model.isSimulating,
                        toggleSimulation: toggleSimulation,
                        showOverlays: $showOverlays,
                        onDismiss: { showMenu = false }
                    )
                    GraphSection(
                        viewModel: viewModel,
                        onDismiss: { showMenu = false }
                    )
                }
                .navigationTitle("Actions")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        
        let withFocus: some View = withSheet.focusable()
        
        let withCrown: some View = withFocus.digitalCrownRotation($crownPosition, from: 0.0, through: 1.0, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        
        let withCrownChange: some View = withCrown.onChange(of: crownPosition) { oldValue, newValue in
            if ignoreNextCrownChange {
                ignoreNextCrownChange = false
                return
            }
            
            let oldOffset = offset
            print("Crown changed from \(oldValue) to \(newValue), pausing simulation")
            isZooming = true
            resumeTimer?.invalidate()
            viewModel.model.pauseSimulation()
            resumeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                print("Resuming simulation after delay")
                isZooming = false
                viewModel.model.resumeSimulation()
            }
            
            updateZoomScale(oldCrown: oldValue)
            clampOffset()
            
            let newOffset = offset
            if newOffset != oldOffset && logOffsetChanges {
                print("Offset changed during zoom: from \(oldOffset) to \(newOffset)")
            }
        }
        
        let withNodesReceive: some View = withCrownChange.onReceive(viewModel.model.$nodes) { _ in
            onUpdateZoomRanges()
        }
        
        let withPanChange: some View = withNodesReceive.onChange(of: panStartOffset) {
            isPanning = panStartOffset != nil
            if isPanning {
                viewModel.model.stopSimulation()
            } else {
                clampOffset()
                resumeTimer?.invalidate()
                resumeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    self.viewModel.model.startSimulation()
                }
            }
        }
        
        let withScene: some View = withPanChange.onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                viewModel.model.startSimulation()
            case .inactive, .background:
                viewModel.model.stopSimulation()
            @unknown default:
                break
            }
        }
        
        let withZoomChange: some View = withScene.onChange(of: zoomScale) {
            clampOffset()  // Changed: Zero-parameter closure (dropped _ in)
        }
        
        let withEdgesChange: some View = withZoomChange.onChange(of: viewModel.model.edges) {
            clampOffset()  // Changed: Zero-parameter closure (dropped _ in)
        }
        
        let withSelectedNode: some View = withEdgesChange.onChange(of: selectedNodeID) {
            withAnimation(.easeInOut(duration: 0.3)) {
                clampOffset()
            }  // Changed: Zero-parameter closure (dropped _ in)
        }
        
        let withSelectedEdge: some View = withSelectedNode.onChange(of: selectedEdgeID) {
            withAnimation(.easeInOut(duration: 0.3)) {
                clampOffset()
            }  // Changed: Zero-parameter closure (dropped _ in)
        }
        
        withSelectedEdge.onAppear {
            viewSize = WKInterfaceDevice.current().screenBounds.size
            onUpdateZoomRanges()
            viewModel.model.startSimulation()
            previousCrownPosition = crownPosition
        }
    }
    private func toggleSimulation() {
        if viewModel.model.isSimulating {
            viewModel.model.pauseSimulation()
        } else {
            viewModel.model.resumeSimulation()
        }
    }
    
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
        
        let nodeDia = 2 * Constants.App.nodeModelRadius
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
        let newCrown = progress
        if abs(newCrown - crownPosition) > 1e-6 {
            ignoreNextCrownChange = true
            crownPosition = newCrown
        }
    }
    
    // Updated: Center on selected if present and zoomed in; no y-bias
    private func updateZoomScale(oldCrown: Double) {
        let newProgress = crownPosition
        let newScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), Double(newProgress)))
        
        let oldScale = zoomScale  // Capture old
        zoomScale = newScale
        
        // NEW: Adjust pan to keep screen center fixed (prevents drift off-screen)
        let zoomRatio = newScale / oldScale
        offset.width *= zoomRatio
        offset.height *= zoomRatio
    }
    // Updated: More padding at high zoom for better panning
    private func clampOffset() {
        let visibleNodes = viewModel.model.visibleNodes()
        guard !visibleNodes.isEmpty else { return }
        
        // Compute effective centroid (unchanged)
        var effectiveCentroid = visibleNodes.reduce(CGPoint.zero) { acc, node in acc + node.position } / CGFloat(visibleNodes.count)
        if let selectedID = selectedNodeID, let selected = visibleNodes.first(where: { $0.id == selectedID }) {
            effectiveCentroid = selected.position
        } else if let selectedEdge = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdge }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }), let to = visibleNodes.first(where: { $0.id == edge.to }) {
            effectiveCentroid = (from.position + to.position) / 2.0
        }
        
        // Compute world-space extents relative to centroid
        var minRel = CGPoint(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude)
        var maxRel = CGPoint(x: -CGFloat.greatestFiniteMagnitude, y: -CGFloat.greatestFiniteMagnitude)
        for node in visibleNodes {
            let rel = node.position - effectiveCentroid
            minRel.x = min(minRel.x, rel.x - node.radius)  // Expand by radius for full node visibility
            minRel.y = min(minRel.y, rel.y - node.radius)
            maxRel.x = max(maxRel.x, rel.x + node.radius)
            maxRel.y = max(maxRel.y, rel.y + node.radius)
        }
        
        // Scaled extents
        let scaledHalfWidth = (maxRel.x - minRel.x) * zoomScale / 2
        let scaledHalfHeight = (maxRel.y - minRel.y) * zoomScale / 2
        
        // View half-sizes minus padding (adjust paddingFactor as before)
        var paddingFactor: CGFloat = zoomScale > 3.0 ? 0.5 : 0.25
        let graphHeight = (maxRel.y - minRel.y) * zoomScale
        if graphHeight < viewSize.height * 0.5 {
            paddingFactor *= 0.5
        }
        let paddingX = viewSize.width * paddingFactor
        let paddingY = viewSize.height * paddingFactor
        
        let viewHalfWidth = viewSize.width / 2 - paddingX
        let viewHalfHeight = viewSize.height / 2 - paddingY
        
        // Clamp ranges: Allow panning so content edges don't go beyond view edges + padding
        // Offset convention: Positive moves content right (view pans left)
        let minOffsetX = -(scaledHalfWidth - viewHalfWidth)  // Large negative at high zoom
        let maxOffsetX = scaledHalfWidth - viewHalfWidth     // Large positive
        let minOffsetY = -(scaledHalfHeight - viewHalfHeight)
        let maxOffsetY = scaledHalfHeight - viewHalfHeight
        
        // If content fits (range negative), center by setting to 0
        offset.width = (maxOffsetX > minOffsetX) ? offset.width.clamped(to: minOffsetX...maxOffsetX) : 0
        offset.height = (maxOffsetY > minOffsetY) ? offset.height.clamped(to: minOffsetY...maxOffsetY) : 0
        print("Zoom: \(zoomScale), Offset: \(offset), MinX: \(minOffsetX), MaxX: \(maxOffsetX), MinY: \(minOffsetY), MaxY: \(maxOffsetY)")
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


struct AddSection: View {
    let viewModel: GraphViewModel
    let selectedNodeID: NodeID?
    let onDismiss: () -> Void

    var body: some View {
        Section(header: Text("Add")) {
            Button("Add Node") {
                viewModel.addNode(at: .zero)
                onDismiss()
            }
            Button("Add Toggle Node") {
                viewModel.addToggleNode(at: .zero)
                onDismiss()
            }
            if let selectedID = selectedNodeID {
                Button("Add Child") {
                    viewModel.addChild(to: selectedID)
                    onDismiss()
                }
            } else {
                Button("Add Child") { }
                    .disabled(true)
            }
        }
    }
}

struct EditSection: View {
    let viewModel: GraphViewModel
    let selectedNodeID: NodeID?
    let selectedEdgeID: UUID?
    let onDismiss: () -> Void

    var body: some View {
        Section(header: Text("Edit")) {
            if let selectedID = selectedNodeID {
                Button("Delete Node", role: .destructive) {
                    viewModel.deleteNode(withID: selectedID)
                    onDismiss()
                }
            } else {
                Button("Delete Node", role: .destructive) { }
                    .disabled(true)
            }
            if let selectedEdgeID = selectedEdgeID {
                Button("Delete Edge", role: .destructive) {
                    viewModel.deleteSelectedEdge(id: selectedEdgeID)
                    onDismiss()
                }
            } else {
                Button("Delete Edge", role: .destructive) { }
                    .disabled(true)
            }
            if viewModel.canUndo {
                Button("Undo") {
                    viewModel.undo()
                    onDismiss()
                }
            } else {
                Button("Undo") { }
                    .disabled(true)
            }
            if viewModel.canRedo {
                Button("Redo") {
                    viewModel.redo()
                    onDismiss()
                }
            } else {
                Button("Redo") { }
                    .disabled(true)
            }
        }
    }
}

struct ViewSection: View {
    let isSimulating: Bool
    let toggleSimulation: () -> Void
    let showOverlays: Binding<Bool>
    let onDismiss: () -> Void

    var body: some View {
        Section(header: Text("View & Simulation")) {
            Button(showOverlays.wrappedValue ? "Hide Overlays" : "Show Overlays") {
                showOverlays.wrappedValue.toggle()
                onDismiss()
            }
            Button(isSimulating ? "Pause Simulation" : "Resume Simulation") {
                toggleSimulation()
                onDismiss()
            }
        }
    }
}

struct GraphSection: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void

    var body: some View {
        Section(header: Text("Graph")) {
            Button("Clear Graph", role: .destructive) {
                viewModel.clearGraph()
                onDismiss()
            }
        }
    }
}
