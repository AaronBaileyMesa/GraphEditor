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
    @State private var clampTimer: Timer?
    @State private var resumeTimer: Timer? = nil
    @State private var logOffsetChanges = true  // Toggle for console logs
    @State private var isPanning: Bool = false  // New: Track panning to pause clamping/simulation
    
    
    // Fixed: Use unlabeled tuple to match compiler type
    @State private var previousSelection: (NodeID?, UUID?) = (nil, nil)
    
    init(storage: GraphStorage = PersistenceManager(),
         physicsEngine: PhysicsEngine = PhysicsEngine(simulationBounds: WKInterfaceDevice.current().screenBounds.size)) {
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        _viewModel = StateObject(wrappedValue: GraphViewModel(model: model))
    }
    
    private func recenterOn(position: CGPoint) {
        guard viewSize != .zero else { return }  // Avoid div-by-zero
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let targetOffsetX = viewCenter.x - position.x * zoomScale
        let targetOffsetY = viewCenter.y - position.y * zoomScale
        
        // Dampen: Limit max change per animation to prevent jarring (50% of screen)
        let maxDeltaX = viewSize.width * 0.5
        let maxDeltaY = viewSize.height * 0.5
        let deltaX = targetOffsetX - offset.width
        let deltaY = targetOffsetY - offset.height
        offset.width += deltaX.clamped(to: -maxDeltaX...maxDeltaX)
        offset.height += deltaY.clamped(to: -maxDeltaY...maxDeltaY)
        
        clampOffset()  // Apply your existing clamping after adjustment
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
        let geoReader = FocusableView {  // Wrap with your custom FocusableView for reliable crown focus
            GeometryReader { geo in
                GraphCanvasView(
                    viewModel: viewModel,
                    zoomScale: $zoomScale,
                    offset: $offset,
                    draggedNode: $draggedNode,
                    dragOffset: $dragOffset,
                    potentialEdgeTarget: $potentialEdgeTarget,
                    selectedNodeID: $viewModel.selectedNodeID,
                    viewSize: geo.size,
                    panStartOffset: $panStartOffset,
                    showMenu: $showMenu,
                    maxZoom: maxZoom,
                    crownPosition: $crownPosition,
                    onUpdateZoomRanges: onUpdateZoomRanges,
                    selectedEdgeID: $viewModel.selectedEdgeID,
                    showOverlays: $showOverlays
                )
            }
            .background(Color.black)  // Move inside wrapper if needed; keeps background on the GeometryReader
        }
        .digitalCrownRotation($crownPosition, from: 0.0, through: 1.0, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)  // Attach to wrapper

        let withIgnore = geoReader.ignoresSafeArea()
        
        let withSheet = withIgnore.sheet(isPresented: $showMenu) {
            List {
                // Show Add only if no edge is selected (and optionally if a node is selected or none)
                if viewModel.selectedEdgeID == nil {
                    AddSection(viewModel: viewModel, selectedNodeID: viewModel.selectedNodeID, onDismiss: { showMenu = false })
                }
                
                // Show Edit only if it would have at least one button
                if viewModel.selectedNodeID != nil || viewModel.selectedEdgeID != nil || viewModel.canUndo || viewModel.canRedo {
                    EditSection(viewModel: viewModel, selectedNodeID: viewModel.selectedNodeID, selectedEdgeID: viewModel.selectedEdgeID, onDismiss: { showMenu = false })
                }
                
                // Always show View
                ViewSection(
                    showOverlays: $showOverlays,
                    isSimulating: $viewModel.model.isSimulating,
                    onDismiss: { showMenu = false },
                    onSimulationChange: { newValue in
                        if newValue {
                            viewModel.resumeSimulation()
                        } else {
                            viewModel.pauseSimulation()
                        }
                    }
                )
                
                // Always show Graph
                GraphSection(viewModel: viewModel, onDismiss: { showMenu = false })
            }
            .listStyle(.carousel)
        }
            .onChange(of: viewModel.selectedNodeID) { oldValue, newValue in
                print("Selection change (node): from \(oldValue?.uuidString ?? "nil") to \(newValue?.uuidString ?? "nil"). Offset before: width \(offset.width), height \(offset.height)")
                if newValue != oldValue && newValue != previousSelection.0 {  // This is fine; no strings here
                    previousSelection.0 = newValue
                    if let newID = newValue, let selectedNode = viewModel.model.nodes.first(where: { $0.id == newID }) {
                        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                           // recenterOn(position: selectedNode.position)
                        }
                        viewModel.model.isSimulating = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            viewModel.model.isSimulating = true
                            print("Resuming simulation after node selection change/deselection. Node count: \(viewModel.model.nodes.count), Visible nodes: \(viewModel.model.visibleNodes().count)")
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            clampOffset()
                        }
                    }
                }
                print("Offset after node selection change: width \(offset.width), height \(offset.height)")
            }
            .onChange(of: viewModel.selectedEdgeID) { oldValue, newValue in
                print("Selection change (edge): from \(oldValue?.uuidString ?? "nil") to \(newValue?.uuidString ?? "nil"). Offset before: width \(offset.width), height \(offset.height)")
                if newValue != oldValue && newValue != previousSelection.1 {
                    previousSelection.1 = newValue
                    if let newID = newValue, let edge = viewModel.model.edges.first(where: { $0.id == newID }),
                       let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                       let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                        let midpoint = CGPoint(x: (fromNode.position.x + toNode.position.x) / 2, y: (fromNode.position.y + toNode.position.y) / 2)
                        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                            //recenterOn(position: midpoint)
                        }
                        viewModel.model.isSimulating = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            viewModel.model.isSimulating = true
                            print("Resuming simulation after edge selection change/deselection. Node count: \(viewModel.model.nodes.count), Visible nodes: \(viewModel.model.visibleNodes().count)")
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            clampOffset()
                        }
                    }
                }
                print("Offset after edge selection change: width \(offset.width), height \(offset.height)")
            }
                
        let withCrownChange = withSheet.onChange(of: crownPosition) { oldValue, newValue in
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
        
        let withNodesReceive = withCrownChange.onReceive(viewModel.model.$nodes) { _ in
            onUpdateZoomRanges()
        }
        
        let withPanChange = withNodesReceive
            .onChange(of: panStartOffset) {
                isPanning = panStartOffset != nil
                if isPanning {
                    viewModel.model.stopSimulation()
                } else {
                    // Delay clamp for smoother "settle"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if !self.isPanning {  // Re-check to avoid race
                            self.clampOffset()
                        }
                    }
                    resumeTimer?.invalidate()
                    resumeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                        self.viewModel.model.startSimulation()
                    }
                }
            }
        
        let withScene = withPanChange.onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                viewModel.model.startSimulation()
            case .inactive:
                viewModel.model.pauseSimulation()
            case .background:
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
        
        // New: Combined onChange for selections
        let withSelectionsChange: some View = withEdgesChange.onChange(of: [viewModel.selectedNodeID, viewModel.selectedEdgeID]) {
            handleSelectionChange()  // No parameters; ignores old/new values
        }
        
        withSelectionsChange.onAppear {
            viewSize = WKInterfaceDevice.current().screenBounds.size
            onUpdateZoomRanges()
            viewModel.model.startSimulation()
            previousCrownPosition = crownPosition
        }
    }
    
    // New: Handle selection change with transitional offset
    private func handleSelectionChange() {
        let currentSelection = (viewModel.selectedNodeID, viewModel.selectedEdgeID)
        let oldSelection = previousSelection
        previousSelection = currentSelection
        
        let visibleNodes = viewModel.model.visibleNodes()
        
        // Compute old effective centroid (inline)
        var oldCentroid: CGPoint = .zero
        if let oldNodeID = oldSelection.0, let oldNode = visibleNodes.first(where: { $0.id == oldNodeID }) {
            oldCentroid = oldNode.position
        } else if let oldEdgeID = oldSelection.1, let edge = viewModel.model.edges.first(where: { $0.id == oldEdgeID }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }), let to = visibleNodes.first(where: { $0.id == edge.to }) {
            oldCentroid = CGPoint(x: (from.position.x + to.position.x) / 2, y: (from.position.y + to.position.y) / 2)
        } else if !visibleNodes.isEmpty {
            let count = CGFloat(visibleNodes.count)
            let sumX = visibleNodes.reduce(0.0) { $0 + $1.position.x }
            let sumY = visibleNodes.reduce(0.0) { $0 + $1.position.y }
            oldCentroid = CGPoint(x: sumX / count, y: sumY / count)
        }
        
        // Compute new effective centroid (inline)
        var newCentroid: CGPoint = .zero
        if let newNodeID = currentSelection.0, let newNode = visibleNodes.first(where: { $0.id == newNodeID }) {
            newCentroid = newNode.position
        } else if let newEdgeID = currentSelection.1, let edge = viewModel.model.edges.first(where: { $0.id == newEdgeID }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }), let to = visibleNodes.first(where: { $0.id == edge.to }) {
            newCentroid = CGPoint(x: (from.position.x + to.position.x) / 2, y: (from.position.y + to.position.y) / 2)
        } else if !visibleNodes.isEmpty {
            let count = CGFloat(visibleNodes.count)
            let sumX = visibleNodes.reduce(0.0) { $0 + $1.position.x }
            let sumY = visibleNodes.reduce(0.0) { $0 + $1.position.y }
            newCentroid = CGPoint(x: sumX / count, y: sumY / count)
        }
        
        // Immediate offset adjustment to prevent jump
        let delta = CGPoint(x: newCentroid.x - oldCentroid.x, y: newCentroid.y - oldCentroid.y)
        offset.width -= delta.x * zoomScale
        offset.height -= delta.y * zoomScale
        
        // Animate to center (offset = .zero) and clamp
        withAnimation(.easeInOut(duration: 0.3)) {
            offset = .zero
            clampOffset()
        }
        
        // Pause/resume simulation for stability during transition
        viewModel.model.pauseSimulation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            viewModel.model.resumeSimulation()
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
    
    // Updated: More padding at high zoom for better panning
    private func clampOffset() {
        let oldOffset = offset
        let visibleNodes = viewModel.model.visibleNodes()
        guard !visibleNodes.isEmpty else { return }
        
        // Compute bbox using visible nodes (via physicsEngine for consistency)
        let graphBBox = viewModel.model.physicsEngine.boundingBox(nodes: visibleNodes)
        let nodeRadius = Constants.App.nodeModelRadius
        let scaledWidth = graphBBox.width * zoomScale + 2 * nodeRadius * zoomScale
        let scaledHeight = graphBBox.height * zoomScale + 2 * nodeRadius * zoomScale
        
        let effectiveViewWidth = viewSize.width - 2 * nodeRadius * zoomScale
        let effectiveViewHeight = viewSize.height - 2 * nodeRadius * zoomScale
        
        var panRoomX: CGFloat = 0
        if scaledWidth > effectiveViewWidth {
            panRoomX = (scaledWidth - effectiveViewWidth) / 2
        } else {
            panRoomX = (effectiveViewWidth - scaledWidth) / 2
        }
        
        var panRoomY: CGFloat = 0
        if scaledHeight > effectiveViewHeight {
            panRoomY = (scaledHeight - effectiveViewHeight) / 2
        } else {
            panRoomY = (effectiveViewHeight - scaledHeight) / 2
        }
        
        let minOffsetX = -panRoomX
        let maxOffsetX = panRoomX
        let minOffsetY = -panRoomY
        let maxOffsetY = panRoomY
        
        let bounceFactor: CGFloat = 0.1
        let extendedMinX = minOffsetX - panRoomX * bounceFactor
        let extendedMaxX = maxOffsetX + panRoomX * bounceFactor
        let extendedMinY = minOffsetY - panRoomY * bounceFactor
        let extendedMaxY = maxOffsetY + panRoomY * bounceFactor
        
        // New: Only clamp if actually out of range (reduce unnecessary ops/logs)
        if offset.width < extendedMinX || offset.width > extendedMaxX ||
            offset.height < extendedMinY || offset.height > extendedMaxY {
            offset.width = offset.width.clamped(to: extendedMinX...extendedMaxX)
            offset.height = offset.height.clamped(to: extendedMinY...extendedMaxY)
        } else {
            return  // Skip log if no change
        }
        
        // Debug log (add condition to print only on change or debug mode)
#if DEBUG
        print("Zoom: \(zoomScale), Clamped Offset: \(offset), X Range: \(minOffsetX)...\(maxOffsetX), Y Range: \(minOffsetY)...\(maxOffsetY)")
#endif
        if offset != oldOffset {
            print("ClampOffset adjusted from width \(oldOffset.width), height \(oldOffset.height) to width \(offset.width), height \(offset.height). Triggered by deselection? \(viewModel.selectedNodeID == nil && viewModel.selectedEdgeID == nil)")
            } else {
                print("ClampOffset called but no adjustment needed.")
            }
    }    // Updated: Center on selected if present and zoomed in; no y-bias
    
    
    private func updateZoomScale(oldCrown: Double) {
        let newProgress = crownPosition
        let newScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), Double(newProgress)))
        let oldScale = zoomScale
        zoomScale = newScale
        
        let zoomRatio = newScale / oldScale
        offset.width *= zoomRatio
        offset.height *= zoomRatio
        
        // Debounce clamp to after zoom stops (prevents mid-zoom snaps)
        clampTimer?.invalidate()
        clampTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in  // 0.3s delay
            withAnimation(.easeOut(duration: 0.2)) {
                clampOffset()
            }
        }
        // Inside updateZoomScale(...), after lines like offset.width *= zoomRatio and offset.height *= zoomRatio:
        if let selectedID = viewModel.selectedNodeID, let selectedNode = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
            //recenterOn(position: selectedNode.position)
        } else if let selectedEdgeID = viewModel.selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdgeID }),
                  let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                  let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
            let midpoint = CGPoint(x: (fromNode.position.x + toNode.position.x) / 2, y: (fromNode.position.y + toNode.position.y) / 2)
            //recenterOn(position: midpoint)
        }
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
            }
            if let selectedEdgeID = selectedEdgeID,
               let selectedEdge = viewModel.model.edges.first(where: { $0.id == selectedEdgeID }) {
                // Assignments moved inside (no 'if let' needed for non-optionals)
                let fromID = selectedEdge.from
                let toID = selectedEdge.to
                let isBi = viewModel.model.isBidirectionalBetween(fromID, toID)
                Button(isBi ? "Delete Both Edges" : "Delete Edge", role: .destructive) {
                    viewModel.snapshot()
                    if isBi {
                        let pair = viewModel.model.edgesBetween(fromID, toID)
                        viewModel.model.edges.removeAll { pair.contains($0) }
                    } else {
                        viewModel.model.edges.removeAll { $0.id == selectedEdgeID }
                    }
                    viewModel.model.startSimulation()
                    onDismiss()
                }
            }
            if viewModel.canUndo {
                Button("Undo") {
                    viewModel.undo()
                    onDismiss()
                }
            }
            if viewModel.canRedo {
                Button("Redo") {
                    viewModel.redo()
                    onDismiss()
                }
            }
        }
    }
}
struct ViewSection: View {
    @Binding var showOverlays: Bool
    @Binding var isSimulating: Bool  // Now a Binding for direct Toggle control
    let onDismiss: () -> Void
    let onSimulationChange: (Bool) -> Void  // New: Handles pause/resume logic

    var body: some View {
        Section(header: Text("View & Simulation")) {
            Toggle("Show Overlays", isOn: $showOverlays)
                .onChange(of: showOverlays) {  // Zero-params: ignores value
                    onDismiss()
                }
            
            Toggle("Run Simulation", isOn: $isSimulating)
                .onChange(of: isSimulating) { _, new in  // Two-params: ignore old, use new
                    onSimulationChange(new)
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
