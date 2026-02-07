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
    @State private var longPressTask: Task<Void, Never>?
    @State private var pressProgress: Double = 0.0
    @State private var longPressStartLocation: CGPoint?
    @State private var hasCheckedForNodeThisGesture = false  // Prevents repeated hit tests during pan
    @State private var justEnteredEdgeMode = false  // Prevents immediate drag-end from trying to complete edge
    
    private let dragStartThreshold: CGFloat = 5.0  // Balanced for tap detection and drag responsiveness
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "gestures")
    
    // Rationale: Central gesture coordinator handling tap/drag/pan disambiguation with complex state machine
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func body(content: Content) -> some View {
        // Using minimumDistance: 0 to detect touch immediately for long press desaturation
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                // Log EVERY change to diagnose tap detection issues
                let isFirstChange = currentDragLocation == nil
                if isFirstChange {
                    Self.logger.debug("DragGesture FIRST onChanged: location=\(value.location.x, format: .fixed(precision: 1)),\(value.location.y, format: .fixed(precision: 1)) startLocation=\(value.startLocation.x, format: .fixed(precision: 1)),\(value.startLocation.y, format: .fixed(precision: 1)) selectedNode=\(selectedNodeID?.uuidString.prefix(8) ?? "nil") visibleNodes=\(viewModel.model.visibleNodes.count)")
                    
                    // Start long press desaturation on first touch
                    longPressStartLocation = value.startLocation
                    handleLongPressStart()
                }
                currentDragLocation = value.location  // Track for edge preview
                let translation = value.translation
                let magnitude = hypot(translation.width, translation.height)
                
                // Only log significant drags to reduce noise
                if magnitude > dragStartThreshold || draggedNode != nil {
                    Self.logger.debug("Drag changed: location=\(value.location.x, format: .fixed(precision: 1)),\(value.location.y, format: .fixed(precision: 1)) translation=\(translation.width, format: .fixed(precision: 1)),\(translation.height, format: .fixed(precision: 1)) magnitude=\(magnitude, format: .fixed(precision: 2))")
                }
                
                if draggedNode == nil && magnitude > dragStartThreshold && !hasCheckedForNodeThisGesture {
                    // Mark that we've checked for a node - prevents repeated checks during pan
                    hasCheckedForNodeThisGesture = true
                    
                    // Cancel long press immediately when drag threshold is exceeded
                    handleLongPressCancel()
                    longPressStartLocation = nil
                    
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
                        viewModel.model.draggedNodeID = hitNode.id  // Sync to model for physics exclusion
                        
                        // CRITICAL: Pause simulation BEFORE repositioning to prevent race condition
                        // Must be synchronous to ensure no physics steps occur during drag
                        viewModel.model.physicsEngine.isPaused = true
                        
                        // Reposition controls immediately to ensure correct distance
                        viewModel.repositionEphemerals(for: hitNode.id, to: initialModelPos)
                        
                        Self.logger.debug("Started dragging node \(hitNode.id.uuidString.prefix(8)) - paused physics")
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
                        let oldOwnerPos = viewModel.model.nodes[nodeIndex].position
                        // Existing: Update dragged node's position
                        Self.logger.debug("Drag: oldOwner=(\(oldOwnerPos.x, format: .fixed(precision: 1)),\(oldOwnerPos.y, format: .fixed(precision: 1))) newOwner=(\(newOwnerPos.x, format: .fixed(precision: 1)),\(newOwnerPos.y, format: .fixed(precision: 1))) delta=(\(newOwnerPos.x - oldOwnerPos.x, format: .fixed(precision: 1)),\(newOwnerPos.y - oldOwnerPos.y, format: .fixed(precision: 1)))")
                        viewModel.model.nodes[nodeIndex].position = newOwnerPos
                        
                        // Update attached control nodes' positions in real-time
                        // Maintains exact 40pt offset from owner node
                        viewModel.repositionEphemerals(for: dragged.id, to: newOwnerPos)
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
                
                // Clean up long press state if it wasn't converted to a long press
                if longPressStartLocation != nil {
                    handleLongPressCancel()
                    longPressStartLocation = nil
                }
                
                handleDragEnded(value)
            }
        
        // Long press gesture for menu - completed when duration elapses
        let longPressGesture = LongPressGesture(minimumDuration: AppConstants.menuLongPressDuration, maximumDistance: 25.0)
            .onEnded { _ in
                if draggedNode == nil {
                    handleLongPressEnded()
                } else {
                    handleLongPressCancel()
                }
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
            .gesture(dragGesture)  // Lower priority for drag (includes long press detection)
            .simultaneousGesture(longPressGesture)  // Re-enabled: Long press for menu

    }
    
    // FIXED: Restore handlers from old version (adapted for latest)
    private func handleLongPressStart() {
        Self.logger.debug("Long press started: Beginning desaturation")
        pressProgress = 0.0
        saturation = 1.0  // Start at full saturation
        longPressTask?.cancel()
        longPressTask = Task { @MainActor in
            let startTime = Date()
            let animationDuration = AppConstants.menuLongPressDuration * 0.75  // Animate for 75% of duration (1.0s)
            let pauseDuration = AppConstants.menuLongPressDuration * 0.25  // Pause for 25% (0.33s)
            var lastLoggedProgress = 0.0
            
            // Phase 1: Animate desaturation (0.0s to 1.0s)
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(startTime)
                
                if elapsed >= animationDuration {
                    // Animation complete, stay at 0.0 saturation
                    saturation = 0.0
                    pressProgress = 1.0
                    Self.logger.debug("Desaturation animation complete: saturation=0.00, pausing...")
                    break
                }
                
                let progress = elapsed / animationDuration
                pressProgress = progress
                saturation = 1.0 - progress
                
                // Log every 25% progress
                if progress - lastLoggedProgress >= 0.25 {
                    Self.logger.debug("Desaturation progress: \(progress, format: .fixed(precision: 2)) saturation: \(saturation, format: .fixed(precision: 2))")
                    lastLoggedProgress = progress
                }
                
                try? await Task.sleep(nanoseconds: 20_000_000)  // 20ms
            }
            
            // Phase 2: Pause at fully desaturated (1.0s to 1.33s)
            // The LongPressGesture will fire during this pause and show the menu
        }
    }
    
    private func handleLongPressCancel() {
        Self.logger.debug("Long press cancelled: Resetting saturation")
        longPressTask?.cancel()
        longPressTask = nil
        pressProgress = 0.0
        saturation = 1.0  // Reset to full saturation
    }
    
    private func handleLongPressEnded() {
        Self.logger.debug("Long press ended: Showing menu")
        longPressTask?.cancel()
        longPressTask = nil
        showMenu = true  // Trigger menu
        
        // Keep saturation at final desaturated state briefly before resetting
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms delay
            pressProgress = 0.0
            saturation = 1.0  // Reset saturation
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let magnitude = hypot(value.translation.width, value.translation.height)
        let moved = magnitude >= dragStartThreshold
        Self.logger.debug("Drag ended: magnitude=\(magnitude, format: .fixed(precision: 2)) threshold=\(dragStartThreshold, format: .fixed(precision: 2)) moved=\(moved) hasDraggedNode=\(draggedNode != nil)")
        
        // Treat as tap if movement was small AND we didn't start dragging a node
        if !moved && draggedNode == nil {
            Self.logger.debug("Treating as tap at location=\(value.location.x, format: .fixed(precision: 1)),\(value.location.y, format: .fixed(precision: 1))")
            _ = handleTap(
                at: value.location,
                visibleNodes: viewModel.model.visibleNodes,
                visibleEdges: viewModel.model.visibleEdges
            )
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
        // Skip edge creation if we just entered edge mode (prevents immediate completion on control tap)
        if isAddingEdge && !justEnteredEdgeMode,
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
        
        // Clear the flag after first drag-end
        if justEnteredEdgeMode {
            justEnteredEdgeMode = false
            // Don't reset gesture state when entering edge mode - we need to preserve state
            Self.logger.debug("Skipping resetGestureState because we just entered edge mode")
            return
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
                
                // Set flag BEFORE triggering async action to prevent immediate drag-end from completing edge
                if controlNode.kind == .addEdge {
                    justEnteredEdgeMode = true
                    Self.logger.debug("Set justEnteredEdgeMode=true for addEdge control")
                }
                
                // Trigger the control's action
                Task {
                    await viewModel.handleControlTap(control: controlNode)
                }
                WKInterfaceDevice.current().play(.click)
                return true
            }
            
            // Check if we're in edge-adding mode
            if isAddingEdge {
                Self.logger.debug("In edge-adding mode: draggedNodeID=\(viewModel.draggedNodeID?.uuidString.prefix(8) ?? "nil") targetNode=\(node.id.uuidString.prefix(8))")
                
                // Capture the source ID before we clear it
                let sourceID = viewModel.draggedNodeID
                
                if let sourceID = sourceID,
                   node.id != sourceID,
                   !viewModel.model.edges.contains(where: { ($0.from == sourceID && $0.target == node.id) ||
                       ($0.from == node.id && $0.target == sourceID) }) {
                    // Create edge from source to tapped node
                    let type = viewModel.pendingEdgeType
                    Task { 
                        await viewModel.addEdge(from: sourceID, to: node.id, type: type)
                        Self.logger.info("✓ Created edge via tap: \(type.rawValue) from \(sourceID.uuidString.prefix(8)) → \(node.id.uuidString.prefix(8))")
                    }
                    // Exit edge creation mode
                    isAddingEdge = false
                    viewModel.draggedNodeID = nil
                    WKInterfaceDevice.current().play(.click)
                    return true
                } else {
                    // Exit edge mode even if we can't create the edge
                    isAddingEdge = false
                    viewModel.draggedNodeID = nil
                    
                    if sourceID == nil {
                        Self.logger.warning("Edge-adding mode active but draggedNodeID is nil!")
                    } else if node.id == sourceID {
                        Self.logger.info("Cannot create edge to same node")
                        WKInterfaceDevice.current().play(.failure)
                    } else {
                        Self.logger.info("Edge already exists between these nodes")
                        WKInterfaceDevice.current().play(.failure)
                    }
                    // Continue to select the node
                }
            }
            
            // Regular node tap - toggle selection
            let newID = selectedNodeID == node.id ? nil : node.id
            Self.logger.debug("Hit node: \(node.label) id=\(node.id.uuidString.prefix(8)) newSelection=\(newID?.uuidString.prefix(8) ?? "nil")")
            selectedNodeID = newID
            selectedEdgeID = nil
            if let id = newID {
                Task {
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
        // Cancel edge creation mode if active
        if isAddingEdge {
            isAddingEdge = false
            viewModel.draggedNodeID = nil
            Self.logger.debug("Cancelled edge creation - tapped on background")
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
        viewModel.model.draggedNodeID = nil  // Clear from model too
        hasCheckedForNodeThisGesture = false  // Reset for next gesture
        
        // Resume simulation if we were dragging
        if wasDragging {
            // CRITICAL: Zero all velocities before resuming physics
            // This prevents the physics engine from applying cached forces from before the drag
            // which would cause all nodes to shift by the centroid delta
            Self.logger.debug("Zeroing velocities before resuming physics")
            var stabilizedNodes = viewModel.model.nodes
            for index in stabilizedNodes.indices {
                let node = stabilizedNodes[index].unwrapped
                stabilizedNodes[index] = AnyNode(node.with(position: node.position, velocity: .zero))
            }
            viewModel.model.nodes = stabilizedNodes
            
            // Resume physics immediately (synchronous)
            viewModel.model.physicsEngine.isPaused = false
            Self.logger.debug("Resumed physics after drag ended with zeroed velocities")
            
            // No need to regenerate controls - they were already repositioned during drag
            // and are in the correct position relative to the node
        }
    }
}
