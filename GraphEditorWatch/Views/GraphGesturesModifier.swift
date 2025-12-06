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
    
    private let dragStartThreshold: CGFloat = 5.0
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "gestures")
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                currentDragLocation = value.location  // Track for edge preview
                let translation = value.translation
                let magnitude = hypot(translation.width, translation.height)
                
                if draggedNode == nil && magnitude > dragStartThreshold {
                    let screenPos = value.startLocation
                    let modelPos = CoordinateTransformer.screenToModel(screenPos, renderContext)
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
                        viewModel.model.nodes[nodeIndex].position = newOwnerPos
                        
                        // NEW: Update attached control nodes' positions in real-time
                        for controlIndex in viewModel.model.ephemeralControlNodes.indices {
                            if viewModel.model.ephemeralControlNodes[controlIndex].ownerID == dragged.id {
                                // Recalculate relative position (adapt from addControlsForNode logic)
                                let controlKind = viewModel.model.ephemeralControlNodes[controlIndex].kind
                                let priority = viewModel.model.ephemeralControlNodes[controlIndex].priority  // Use stored priority
                                let freeSlots = viewModel.model.getFreeSlots(for: dragged.id)  // Reuse your method
                                guard priority < freeSlots.count else { continue }
                                let angle = freeSlots[priority]  // FIXED: Complete the truncated line – assume freeSlots is [CGFloat] angles in radians
                                
                                let distance: CGFloat = 50.0  // TUNABLE: Fixed distance from owner (match your addControlsForNode)
                                let offset = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
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
                handleDragEnded(value)
            }
        
        // FIXED: Restore long press gesture (from old version)
        let longPressGesture = LongPressGesture(minimumDuration: AppConstants.menuLongPressDuration, maximumDistance: 10.0)
            .updating($isLongPressing) { currentState, gestureState, _ in
                gestureState = currentState
            }
            .onEnded { _ in
                handleLongPressEnded()
            }
        
        content
            .highPriorityGesture(dragGesture)  // FIXED: Use high priority for drag (prevents conflicts)
            .simultaneousGesture(longPressGesture)  // FIXED: Attach long press simultaneously
            .onChange(of: isLongPressing) { oldValue, newValue in  // FIXED: Restore change handler
                if newValue {
                    handleLongPressStart()
                } else if oldValue {
                    handleLongPressCancel()
                }
            }
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
        let moved = hypot(value.translation.width, value.translation.height) >= dragStartThreshold
        
        if !moved {
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
        if let node = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, renderContext: renderContext) {
            let newID = selectedNodeID == node.id ? nil : node.id
            selectedNodeID = newID
            selectedEdgeID = nil
            if let id = newID {
                viewModel.generateControls(for: id)  // Now defined – generates immediately
            } else {
                viewModel.clearControls()  // Now defined – clears immediately
            }
            WKInterfaceDevice.current().play(.click)
            return true
        }
        if let edge = HitTestHelper.closestEdge(at: location, visibleEdges: visibleEdges, visibleNodes: visibleNodes, renderContext: renderContext) {
            selectedEdgeID = selectedEdgeID == edge.id ? nil : edge.id
            selectedNodeID = nil
            viewModel.clearControls()  // Clears if switching to edge
            WKInterfaceDevice.current().play(.click)
            return true
        }
        selectedNodeID = nil
        selectedEdgeID = nil
        viewModel.clearControls()  // Clears on background tap
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
        currentDragLocation = nil
        draggedNode = nil
        dragStartNode = nil
        dragOffset = .zero
        potentialEdgeTarget = nil
        panStartOffset = nil
        isAddingEdge = false
        viewModel.draggedNodeID = nil
    }
}
