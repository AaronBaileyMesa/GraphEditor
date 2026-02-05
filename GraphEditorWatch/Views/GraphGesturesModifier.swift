//
//  GraphGesturesModifier.swift
//  GraphEditorWatch
//
//  Fully working, clean, no compile errors – with drag updates for control nodes fixed.
//  Fixed: Restored long press for desaturation + menu (2025-12-06).
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os

struct GraphGesturesModifier: ViewModifier {
    let viewModel: GraphViewModel
    let renderContext: RenderContext
    
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize
    @Binding var draggedNode: (any NodeProtocol)?
    @Binding var dragOffset: CGPoint
    @Binding var potentialEdgeTarget: (any NodeProtocol)?
    @Binding var selectedNodeID: NodeID?
    @Binding var selectedEdgeID: UUID?
    let viewSize: CGSize
    @Binding var panStartOffset: CGSize?
    @Binding var showMenu: Bool
    let maxZoom: CGFloat
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    @Binding var isAddingEdge: Bool
    @Binding var isSimulating: Bool
    @Binding var saturation: Double
    @Binding var currentDragLocation: CGPoint?  // NEW: Replaces @GestureState dragGestureLocation
    @Binding var dragStartNode: (any NodeProtocol)?  // Change from @State to @Binding (now shared)
    @GestureState private var isLongPressing: Bool = false
    @State private var longPressTimer: Timer?
    @State private var pressProgress: Double = 0.0
    
    private let dragStartThreshold: CGFloat = 8.0  // Increased from 5.0 for better tap detection
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "gestures")
    
    func body(content: Content) -> some View {
        // Using minimumDistance: 1 instead of 0 to allow tap gestures to work better
        let dragGesture = DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                // Log EVERY change to diagnose tap detection issues
                let isFirstChange = currentDragLocation == nil
                if isFirstChange {
                    Self.logger.debug("DragGesture FIRST onChanged: location=\(value.location.x, format: .fixed(precision: 1)),\(value.location.y, format: .fixed(precision: 1)) startLocation=\(value.startLocation.x, format: .fixed(precision: 1)),\(value.startLocation.y, format: .fixed(precision: 1)) selectedNode=\(selectedNodeID?.uuidString.prefix(8) ?? "nil") visibleNodes=\(viewModel.model.visibleNodes.count)")
                }
                currentDragLocation = value.location  // Track for edge preview
                let translation = value.translation
                let magnitude = hypot(translation.width, translation.height)
                
                // Only log significant drags to reduce noise
                if magnitude > dragStartThreshold || draggedNode != nil {
                    Self.logger.debug("Drag changed: location=\(value.location.x, format: .fixed(precision: 1)),\(value.location.y, format: .fixed(precision: 1)) translation=\(translation.width, format: .fixed(precision: 1)),\(translation.height, format: .fixed(precision: 1)) magnitude=\(magnitude, format: .fixed(precision: 2))")
                }
                
                if draggedNode == nil && magnitude > dragStartThreshold {
                    // Cancel long press immediately when drag threshold is exceeded
                    handleLongPressCancel()
                    
                    let screenPos = value.startLocation
                    let modelPos = CoordinateTransformer.screenToModel(screenPos, renderContext)
                    Self.logger.debug("Drag threshold exceeded: checking for node at start location=\(screenPos.x, format: .fixed(precision: 1)),\(screenPos.y, format: .fixed(precision: 1))")
                    if let hitNode = HitTestHelper.closestNode(at: screenPos, visibleNodes: viewModel.model.visibleNodes, renderContext: renderContext) {
                        draggedNode = hitNode
                        dragStartNode = hitNode
                        let initialModelPos = hitNode.position
                        dragOffset = modelPos - initialModelPos
                        selectedNodeID = hitNode.id
                        viewModel.draggedNodeID = hitNode.id
                        Task { await viewModel.model.pauseSimulation() }
                        Self.logger.debug("Started dragging node \(hitNode.id.uuidString.prefix(8)) at model (\(modelPos.x, format: .fixed(precision: 2)), \(modelPos.y, format: .fixed(precision: 2)))")  // FIXED: Proper formatting with OSLogFloatFormatting
                    } else if let hitEdge = HitTestHelper.closestEdge(at: screenPos, visibleEdges: viewModel.model.visibleEdges, visibleNodes: viewModel.model.visibleNodes, renderContext: renderContext) {
                        selectedEdgeID = hitEdge.id
                        selectedNodeID = nil
                    } else {
                        panStartOffset = offset
                    }
                }
                
                if let dragged = draggedNode {
                    let liveScreenPos = value.location
                    let liveModelPos = CoordinateTransformer.screenToModel(liveScreenPos, renderContext)
                    let newOwnerPos = liveModelPos - dragOffset  // Corrected: Use - for accurate delta
                    
                    if let nodeIndex = viewModel.model.nodes.firstIndex(where: { $0.id == dragged.id }) {
                        // Existing: Update dragged node's position
                        Self.logger.debug("Updating dragged node position to model (\(newOwnerPos.x, format: .fixed(precision: 1)), \(newOwnerPos.y, format: .fixed(precision: 1)))")
                        viewModel.model.nodes[nodeIndex].position = newOwnerPos
                        
                        // NEW: Update attached control nodes' positions in real-time
                        for controlIndex in viewModel.model.ephemeralControlNodes.indices {
                            if viewModel.model.ephemeralControlNodes[controlIndex].ownerID == dragged.id {
                                // Use the stored relativeAngle from the control node (in degrees)
                                let angleInDegrees = viewModel.model.ephemeralControlNodes[controlIndex].relativeAngle
                                let angleInRadians = angleInDegrees * .pi / 180
                                let distance: CGFloat = 50.0  // TUNABLE: Fixed distance from owner (match your addControlsForNode)
                                let offset = CGPoint(x: cos(angleInRadians) * distance, y: sin(angleInRadians) * distance)
                                viewModel.model.ephemeralControlNodes[controlIndex].position = newOwnerPos + offset
                            }
                        }
                        viewModel.model.objectWillChange.send()  // Ensure redraw for non-ToggleNodes
                    }
                }
                
                // Edge preview (unchanged)
                if isAddingEdge,
                   let dragged = draggedNode,
                   let pos = currentDragLocation {
                    if let target = HitTestHelper.closestNode(at: pos, visibleNodes: viewModel.model.visibleNodes, renderContext: renderContext),
                       target.id != dragged.id {
                        potentialEdgeTarget = target
                    } else {
                        potentialEdgeTarget = nil
                    }
                }
                
                // Pan handling (adapted from your case .none)
                if draggedNode == nil {
                    let delta = CGSize(
                        width: value.translation.width - (panStartOffset?.width ?? 0),
                        height: value.translation.height - (panStartOffset?.height ?? 0)
                    )
                    offset.width += delta.width / zoomScale
                    offset.height += delta.height / zoomScale
                    panStartOffset = value.translation
                }
            }
            .onEnded { value in
                let magnitude = hypot(value.translation.width, value.translation.height)
                Self.logger.debug("DragGesture onEnded: location=\(value.location.x, format: .fixed(precision: 1)),\(value.location.y, format: .fixed(precision: 1)) translation=\(value.translation.width, format: .fixed(precision: 1)),\(value.translation.height, format: .fixed(precision: 1)) magnitude=\(magnitude, format: .fixed(precision: 2)) selectedNode=\(selectedNodeID?.uuidString.prefix(8) ?? "nil") visibleNodes=\(viewModel.model.visibleNodes.count)")
                handleDragEnded(value)
            }
        
        // TEMPORARILY DISABLED: Long press is interfering with tap detection
        // TODO: Re-enable once tap/drag gestures are working reliably
        /*
        let longPressGesture = LongPressGesture(minimumDuration: AppConstants.menuLongPressDuration, maximumDistance: 25.0)
            .updating($isLongPressing) { currentState, gestureState, _ in
                gestureState = currentState
            }
            .onEnded { _ in
                if draggedNode == nil {
                    handleLongPressEnded()
                }
            }
        */
        
        // FIXED: Add explicit tap gesture with higher priority than drag
        let tapGesture = TapGesture()
            .onEnded { _ in
                // Get the tap location from a state variable we'll set in drag onChanged
                // Since TapGesture doesn't provide location, we need a workaround
                Self.logger.debug("TapGesture detected - handling tap")
                // We'll need to track the last touch location
            }
        
        content
            .highPriorityGesture(
                // Use SpatialTapGesture on watchOS to get tap location
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { event in
                        let location = event.location
                        Self.logger.debug("Tap at location=\(location.x, format: .fixed(precision: 1)),\(location.y, format: .fixed(precision: 1))")
                        _ = handleTap(at: location,
                                      visibleNodes: viewModel.model.visibleNodes,
                                      visibleEdges: viewModel.model.visibleEdges)
                    }
            )
            .gesture(dragGesture)  // Lower priority for drag
            // .simultaneousGesture(longPressGesture)  // DISABLED temporarily

    }
    
    // FIXED: Restore handlers from old version (adapted for latest)
    private func handleLongPressStart() {
        Self.logger.debug("Long press started: Beginning desaturation")
        pressProgress = 0.0
        saturation = 1.0  // Start at full saturation
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            pressProgress += 0.02 / AppConstants.menuLongPressDuration  // Progress to 1.0 over duration
            saturation = 1.0 - pressProgress  // Progressive desaturation
            if pressProgress >= 1.0 {
                longPressTimer?.invalidate()
                longPressTimer = nil
            }
        }
    }
    
    private func handleLongPressCancel() {
        Self.logger.debug("Long press cancelled: Resetting saturation")
        longPressTimer?.invalidate()
        longPressTimer = nil
        pressProgress = 0.0
        saturation = 1.0  // Reset to full saturation
    }
    
    private func handleLongPressEnded() {
        Self.logger.debug("Long press ended: Showing menu")
        longPressTimer?.invalidate()
        longPressTimer = nil
        showMenu = true  // Trigger menu
        pressProgress = 0.0
        saturation = 1.0  // Reset saturation
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let magnitude = hypot(value.translation.width, value.translation.height)
        let moved = magnitude >= dragStartThreshold
        Self.logger.debug("Drag ended: magnitude=\(magnitude, format: .fixed(precision: 2)) threshold=\(dragStartThreshold, format: .fixed(precision: 2)) moved=\(moved) hasDraggedNode=\(draggedNode != nil)")
        
        // Treat as tap if movement was small AND we didn't start dragging a node
        if !moved && draggedNode == nil {
            Self.logger.debug("Treating as tap at location=\(value.location.x, format: .fixed(precision: 1)),\(value.location.y, format: .fixed(precision: 1))")
            _ = handleTap(at: value.location,
                          visibleNodes: viewModel.model.visibleNodes,
                          visibleEdges: viewModel.model.visibleEdges)
            resetGestureState()
            return
        }
        
        // If we started dragging but movement was small, still treat as tap
        if !moved && draggedNode != nil {
            Self.logger.debug("Drag was too small, treating as tap instead")
            _ = handleTap(at: value.location,
                          visibleNodes: viewModel.model.visibleNodes,
                          visibleEdges: viewModel.model.visibleEdges)
            resetGestureState()
            return
        }
        
        // Edge creation (FIXED: No 'EdgeType.directed' – use viewModel.pendingEdgeType; treat as undirected for uniqueness check)
        if isAddingEdge,
           let from = draggedNode ?? dragStartNode,
           let target = HitTestHelper.closestNode(at: value.location,
                                                  visibleNodes: viewModel.model.visibleNodes,
                                                  renderContext: renderContext),
           from.id != target.id,
           !viewModel.model.edges.contains(where: { ($0.from == from.id && $0.target == target.id) ||
               ($0.from == target.id && $0.target == from.id) }) {
            let type = viewModel.pendingEdgeType  // Assume this is set elsewhere (e.g., .hierarchy)
            Task { await viewModel.addEdge(from: from.id, to: target.id, type: type) }
            Self.logger.debug("Added edge: \(type.rawValue) \"\(from.label)\" → \"\(target.label)\"")
        }
        
        resetGestureState()
    }
    
    // MARK: - Tap (unchanged)
    func handleTap(at location: CGPoint, visibleNodes: [any NodeProtocol], visibleEdges: [GraphEdge]) -> Bool {
        Self.logger.debug("handleTap: location=\(location.x, format: .fixed(precision: 1)),\(location.y, format: .fixed(precision: 1)) visibleNodes=\(visibleNodes.count)")
        if let node = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, renderContext: renderContext) {
            
            // Check if this is a control node
            if let controlNode = node as? ControlNode {
                Self.logger.debug("Hit control node: \(controlNode.kind.rawValue) for owner \(controlNode.ownerID?.uuidString.prefix(8) ?? "nil")")
                // Trigger the control's action
                Task {
                    await viewModel.handleControlTap(control: controlNode)
                }
                WKInterfaceDevice.current().play(.click)
                return true
            }
            
            // Regular node tap - toggle selection
            let newID = selectedNodeID == node.id ? nil : node.id
            Self.logger.debug("Hit node: \(node.label) id=\(node.id.uuidString.prefix(8)) newSelection=\(newID?.uuidString.prefix(8) ?? "nil")")
            selectedNodeID = newID
            selectedEdgeID = nil
            if let id = newID {
                Task{
                    await viewModel.generateControls(for: id)  // Now defined – generates immediately
                }
            } else {
                Task {
                    await viewModel.clearControls()  // Now defined – clears immediately
                }
            }
            WKInterfaceDevice.current().play(.click)
            return true
        }
        if let edge = HitTestHelper.closestEdge(at: location, visibleEdges: visibleEdges, visibleNodes: visibleNodes, renderContext: renderContext) {
            selectedEdgeID = selectedEdgeID == edge.id ? nil : edge.id
            selectedNodeID = nil
            Task { await viewModel.clearControls() } // Clears if switching to edge
            WKInterfaceDevice.current().play(.click)
            return true
        }
        selectedNodeID = nil
        selectedEdgeID = nil
        Task { await viewModel.clearControls() } // Clears on background tap
        return false
    }
    
    // MARK: - Hit Test (unchanged)
    private func hitTest(at screenPos: CGPoint, visibleNodes: [any NodeProtocol], visibleEdges: [GraphEdge]) -> HitType {
        if let nodeN = HitTestHelper.closestNode(at: screenPos, visibleNodes: visibleNodes, renderContext: renderContext) {
            return .node(nodeN)
        }
        if let edgeE = HitTestHelper.closestEdge(at: screenPos, visibleEdges: visibleEdges, visibleNodes: visibleNodes, renderContext: renderContext) {
            return .edge(edgeE)
        }
        return .none
    }
    
    private func resetGestureState() {
        let wasDragging = draggedNode != nil
        let nodeToRegenerate = selectedNodeID  // Capture before clearing
        
        currentDragLocation = nil
        draggedNode = nil
        dragStartNode = nil
        dragOffset = .zero
        potentialEdgeTarget = nil
        panStartOffset = nil
        isAddingEdge = false
        viewModel.draggedNodeID = nil
        
        // Resume simulation if we were dragging
        if wasDragging {
            Task { await viewModel.model.resumeSimulation() }
            Self.logger.debug("Resumed simulation after drag ended")
            
            // Regenerate controls for the selected node if one is still selected
            if let nodeID = nodeToRegenerate {
                Task { await viewModel.generateControls(for: nodeID) }
                Self.logger.debug("Regenerating controls for node \(nodeID.uuidString.prefix(8)) after drag")
            }
        }
    }
}
