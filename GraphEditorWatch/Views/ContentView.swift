//  ContentView.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.

import SwiftUI
import WatchKit
import GraphEditorShared
import Foundation
import CoreGraphics  // For CGRect in clampOffset

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
    @State private var minZoom: CGFloat = 0.5  // Reduced range
    @State private var maxZoom: CGFloat = 2.5  // Reduced range
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
    @State private var zoomTimer: Timer? = nil  // For debouncing zoom resume
    @State private var isLoaded: Bool = false  // New: Prevent multiple loads
    
    // Fixed: Use unlabeled tuple to match compiler type
    @State private var previousSelection: (NodeID?, UUID?) = (nil, nil)
    
    init(storage: GraphStorage = PersistenceManager(),
         physicsEngine: PhysicsEngine = PhysicsEngine(simulationBounds: WKInterfaceDevice.current().screenBounds.size)) {
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        _viewModel = StateObject(wrappedValue: GraphViewModel(model: model))
    }
    
    // Moved function outside body
    private func recenterOn(position: CGPoint) {
        guard viewSize != .zero else { return }  // Avoid div-by-zero
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let targetOffsetX = viewCenter.x - position.x * zoomScale
        let targetOffsetY = viewCenter.y - position.y * zoomScale
        withAnimation {
            offset = CGSize(width: targetOffsetX, height: targetOffsetY)
        }
    }
    
    private func adjustedOffset(for newZoom: CGFloat, currentCenter: CGPoint) -> CGSize {
        // Calculate new offset to keep the same center in view
        let newOffsetX = -(currentCenter.x - viewSize.width / (2 * newZoom)) * newZoom
        let newOffsetY = -(currentCenter.y - viewSize.height / (2 * newZoom)) * newZoom
        // Optional: Log for verification (remove after testing)
            print("Adjusted offset to preserve center: (\(newOffsetX), \(newOffsetY))")
        return CGSize(width: newOffsetX, height: newOffsetY)
    }
    
    private func clampOffset() {
        let oldOffset = offset  // For logging changes
        
        // Completed logic from truncated paste (assumed if-else for panRoom when scaled > effective)
        let graphBounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.nodes)
        let scaledWidth = graphBounds.width * zoomScale
        let scaledHeight = graphBounds.height * zoomScale
        let effectiveViewWidth = viewSize.width
        let effectiveViewHeight = viewSize.height
        
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
        
        // Re-added: Log pre-zoom center
        let centerX = -offset.width / oldScale + viewSize.width / (2 * oldScale)
        let centerY = -offset.height / oldScale + viewSize.height / (2 * oldScale)
        print("Pre-zoom center (model): (\(centerX), \(centerY))")
        
        zoomScale = newScale
        
        let zoomRatio = newScale / oldScale
        offset.width *= zoomRatio
        offset.height *= zoomRatio
        
        // Preserve center by adjusting offset
        offset = adjustedOffset(for: newScale, currentCenter: CGPoint(x: centerX, y: centerY))
        
        // Re-added: Log post-adjustment center (before clamp)
        let postAdjCenterX = -offset.width / newScale + viewSize.width / (2 * newScale)
        let postAdjCenterY = -offset.height / newScale + viewSize.height / (2 * newScale)
        print("Post-adjustment center (model, pre-clamp): (\(postAdjCenterX), \(postAdjCenterY))")
        
        // Debounce clamp...
        clampTimer?.invalidate()
        clampTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                self.clampOffset()
            }
            // Re-added: Log post-clamp center
            let postClampCenterX = -self.offset.width / self.zoomScale + self.viewSize.width / (2 * self.zoomScale)
            let postClampCenterY = -self.offset.height / self.zoomScale + self.viewSize.height / (2 * self.zoomScale)
            print("Post-clamp center (model): (\(postClampCenterX), \(postClampCenterY))")
        
            
        }
    }
    
    var body: some View {
        let isSimulatingBinding = Binding<Bool>(
            get: { viewModel.model.isSimulating },
            set: { viewModel.model.isSimulating = $0 }
        )
        
        GeometryReader { geo in
            ZStack {
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
                    onUpdateZoomRanges: { clampOffset() },
                    selectedEdgeID: $viewModel.selectedEdgeID,
                    showOverlays: $showOverlays
                )
            }
        }
        .focusable()  // Add this BEFORE .digitalCrownRotation
        .digitalCrownRotation(
            $crownPosition,
            from: 0.0,
            through: 1.0,
            sensitivity: .high,  // Try .medium if too fast
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onAppear {
            viewSize = WKInterfaceDevice.current().screenBounds.size
            if !isLoaded {
                viewModel.loadGraph()
                viewModel.loadViewState()
                isLoaded = true
            }
            
        }
        .onChange(of: scenePhase) { newPhase in
                     if newPhase == .active && !isLoaded {
                viewModel.loadGraph()
                viewModel.loadViewState()
                isLoaded = true
            }
        }
        .onChange(of: crownPosition) { newValue in
            print("Crown position changed to: \(newValue)")  // Already there
            guard !showMenu else {
                previousCrownPosition = newValue
                return
            }
            let delta = abs(newValue - previousCrownPosition)
            if delta < 0.01 || ignoreNextCrownChange {
                ignoreNextCrownChange = false
                return
            }
            
            // New: Simple throttle to skip if too soon after last update (reduces rapid fires)
            var lastUpdateTime: Date = .distantPast
            if Date().timeIntervalSince(lastUpdateTime) < 0.05 {  // 50ms min interval
                return
            }
            lastUpdateTime = Date()
            
            updateZoomScale(oldCrown: previousCrownPosition)
            
            isZooming = true
            zoomTimer?.invalidate()
            zoomTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                self.isZooming = false
                self.viewModel.model.startSimulation()
            }
            
            previousCrownPosition = newValue
        }
        
        .onChange(of: viewModel.selectedNodeID) {
            if let selectedID = viewModel.selectedNodeID, let selectedNode = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
                recenterOn(position: selectedNode.position)
                clampOffset()  // Immediate clamp after recenter
            }
        }
        .onChange(of: viewModel.selectedEdgeID) {
            if let selectedEdgeID = viewModel.selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdgeID }),
               let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
               let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                let midPoint = CGPoint(x: (fromNode.position.x + toNode.position.x) / 2, y: (fromNode.position.y + toNode.position.y) / 2)
                recenterOn(position: midPoint)
                clampOffset()  // Immediate clamp after recenter
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showMenu) {
            // ... (unchanged)
        }
            List {
                if viewModel.selectedEdgeID == nil {
                    AddSection(viewModel: viewModel, selectedNodeID: viewModel.selectedNodeID, onDismiss: { showMenu = false })
                }
                
                if viewModel.selectedNodeID != nil || viewModel.selectedEdgeID != nil || viewModel.canUndo || viewModel.canRedo {
                    EditSection(viewModel: viewModel, selectedNodeID: viewModel.selectedNodeID, selectedEdgeID: viewModel.selectedEdgeID, onDismiss: { showMenu = false })
                }
                
                ViewSection(
                    showOverlays: $showOverlays,
                    isSimulating: isSimulatingBinding,
                    onDismiss: { showMenu = false },
                    onSimulationChange: { newValue in
                        viewModel.model.isSimulating = newValue
                        if newValue {
                            viewModel.model.startSimulation()
                        } else {
                            viewModel.model.stopSimulation()
                        }
                    }
                )
                
                GraphSection(viewModel: viewModel, onDismiss: { showMenu = false })
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
                .onChange(of: showOverlays) {
                    onDismiss()
                }

            Toggle("Run Simulation", isOn: $isSimulating)
                .onChange(of: isSimulating) { newValue in
                    onSimulationChange(newValue)
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
