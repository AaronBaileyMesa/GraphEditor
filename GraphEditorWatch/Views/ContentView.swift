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
    @State private var clampTimer: Timer?
    
    
    // New: Timer for debouncing simulation resume
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
            .focusable()  // Applied directly to GraphCanvasView
            .digitalCrownRotation($crownPosition, from: 0.0, through: 1.0, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)  // Applied directly
        }
        
        let withIgnore: some View = geoReader.ignoresSafeArea()
        
        let withSheet: some View = withIgnore.sheet(isPresented: $showMenu) {
            List {
                // Always show Add (it has unconditional buttons)
                AddSection(viewModel: viewModel, selectedNodeID: selectedNodeID, onDismiss: { showMenu = false })
                
                // Show Edit only if it would have at least one button
                if selectedNodeID != nil || selectedEdgeID != nil || viewModel.canUndo || viewModel.canRedo {
                    EditSection(viewModel: viewModel, selectedNodeID: selectedNodeID, selectedEdgeID: selectedEdgeID, onDismiss: { showMenu = false })
                }
                
                // Always show View (it has unconditional toggles)
                ViewSection(isSimulating: viewModel.model.isSimulating, toggleSimulation: toggleSimulation, showOverlays: $showOverlays, onDismiss: { showMenu = false })
                
                // Always show Graph (Clear is unconditional)
                GraphSection(viewModel: viewModel, onDismiss: { showMenu = false })
            }
            .listStyle(.carousel)  // Ensures watchOS-friendly scrolling
        }
        
        
        // Removed .focusable() here since moved inside GeometryReader
        
        let withCrownChange: some View = withSheet.onChange(of: crownPosition) { oldValue, newValue in
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
        
        // New: Combined onChange for selections
        let withSelectionsChange: some View = withEdgesChange.onChange(of: [selectedNodeID, selectedEdgeID]) {
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
        let currentSelection = (selectedNodeID, selectedEdgeID)
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
        let visibleNodes = viewModel.model.visibleNodes()
        guard !visibleNodes.isEmpty else {
            offset = .zero
            return
        }
        
        // Compute effective centroid (unchanged)
        var effectiveCentroid = visibleNodes.reduce(CGPoint.zero) { $0 + $1.position } / CGFloat(visibleNodes.count)
        if let selectedID = selectedNodeID, let selected = visibleNodes.first(where: { $0.id == selectedID }) {
            effectiveCentroid = selected.position
        } else if let selectedEdge = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdge }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }), let to = visibleNodes.first(where: { $0.id == edge.to }) {
            effectiveCentroid = (from.position + to.position) / 2.0
        }
        
        // Compute relative extents, expanded by node radius
        var minRel = CGPoint(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.greatestFiniteMagnitude)
        var maxRel = CGPoint(x: -.greatestFiniteMagnitude, y: -.greatestFiniteMagnitude)
        for node in visibleNodes {
            let rel = node.position - effectiveCentroid
            minRel.x = min(minRel.x, rel.x - node.radius)
            minRel.y = min(minRel.y, rel.y - node.radius)
            maxRel.x = max(maxRel.x, rel.x + node.radius)
            maxRel.y = max(maxRel.y, rel.y + node.radius)
        }
        
        // Scaled extents (full, not half)
        let scaledWidth = (maxRel.x - minRel.x) * zoomScale
        let scaledHeight = (maxRel.y - minRel.y) * zoomScale
        
        // Adjust padding for small graphs and high zoom
        var paddingFactor: CGFloat = zoomScale > 3.0 ? 0.5 : 0.25
        let scaledGraphHeight = scaledHeight
        if scaledGraphHeight < viewSize.height * 0.5 {
            paddingFactor *= 0.5
        }
        let paddingX = viewSize.width * paddingFactor / 2
        let paddingY = viewSize.height * paddingFactor / 2
        
        // Effective view sizes minus padding
        let effectiveViewWidth = viewSize.width - 2 * paddingX
        let effectiveViewHeight = viewSize.height - 2 * paddingY
        
        // Compute pan room (positive direction)
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
        
        // Allow slight over-pan for bounce
        let bounceFactor: CGFloat = 0.1
        let extendedMinX = minOffsetX - panRoomX * bounceFactor
        let extendedMaxX = maxOffsetX + panRoomX * bounceFactor
        let extendedMinY = minOffsetY - panRoomY * bounceFactor
        let extendedMaxY = maxOffsetY + panRoomY * bounceFactor
        
        // Apply extended clamp (strict clamp happens in gesture animation)
        offset.width = offset.width.clamped(to: extendedMinX...extendedMaxX)
        offset.height = offset.height.clamped(to: extendedMinY...extendedMaxY)
        
        // Debug log
        print("Zoom: \(zoomScale), Clamped Offset: \(offset), X Range: \(minOffsetX)...\(maxOffsetX), Y Range: \(minOffsetY)...\(maxOffsetY)")
    }
    // Updated: Center on selected if present and zoomed in; no y-bias
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
            if let selectedEdgeID = selectedEdgeID {
                Button("Delete Edge", role: .destructive) {
                    viewModel.deleteSelectedEdge(id: selectedEdgeID)
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
