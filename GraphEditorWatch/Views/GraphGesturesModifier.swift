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

// swiftlint:disable file_length type_body_length
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
    @State private var longPressSucceeded = false  // Prevents drag-end from interfering after long press menu
    @State private var justProgrammaticallySelected = false  // Prevents immediate deselection after programmatic selection
    
    private let dragStartThreshold: CGFloat = 5.0  // Balanced for tap detection and drag responsiveness
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "gestures")
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
        
        let longPressGesture = LongPressGesture(minimumDuration: AppConstants.menuLongPressDuration, maximumDistance: 25.0)
            .onEnded { _ in
                handleLongPressGestureEnded()
            }

        content
            .highPriorityGesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { event in
                        let location = event.location
                        Self.logger.debug("Tap at location=\(location.x, format: .fixed(precision: 1)),\(location.y, format: .fixed(precision: 1))")
                        _ = handleTap(at: location,
                                      visibleNodes: viewModel.model.visibleNodes,
                                      visibleEdges: viewModel.model.visibleEdges)
                    }
            )
            .gesture(dragGesture)
            .simultaneousGesture(longPressGesture)
    }
    
    // MARK: - Drag Gesture Handlers
    
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func handleDragChanged(_ value: DragGesture.Value) {
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

                // Play haptic feedback for drag start
                HapticManager.shared.playDragStart(for: hitNode)

                Self.logger.debug("Started dragging node \(hitNode.id.uuidString.prefix(8)) - paused physics")
            } else if let hitEdge = HitTestHelper.closestEdge(at: screenPos, visibleEdges: viewModel.model.visibleEdges, visibleNodes: viewModel.model.visibleNodes, renderContext: renderContext) {
                selectedEdgeID = hitEdge.id
                selectedNodeID = nil
            } else {
                panStartOffset = value.translation
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

                // If dragging a table, update seated person positions in real-time
                if let table = dragged as? TableNode {
                    Self.logger.debug("Dragging table with \(table.seatingAssignments.count) seated persons")
                    // Create updated table with new position for seat calculations
                    var updatedTable = table
                    updatedTable.position = newOwnerPos

                    for (seatPosition, personID) in table.seatingAssignments {
                        if let personIndex = viewModel.model.nodes.firstIndex(where: { $0.id == personID }) {
                            let oldPersonPos = viewModel.model.nodes[personIndex].position
                            let newPersonPos = updatedTable.seatPosition(for: seatPosition)
                            viewModel.model.nodes[personIndex].position = newPersonPos
                            Self.logger.debug("Updated person at seat: (\(oldPersonPos.x, format: .fixed(precision: 1)),\(oldPersonPos.y, format: .fixed(precision: 1))) → (\(newPersonPos.x, format: .fixed(precision: 1)),\(newPersonPos.y, format: .fixed(precision: 1)))")
                        }
                    }
                }

                // Update attached control nodes' positions in real-time
                // Maintains exact 40pt offset from owner node
                viewModel.repositionEphemerals(for: dragged.id, to: newOwnerPos)
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
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let magnitude = hypot(value.translation.width, value.translation.height)
        Self.logger.debug("DragGesture onEnded: location=\(value.location.x, format: .fixed(precision: 1)),\(value.location.y, format: .fixed(precision: 1)) translation=\(value.translation.width, format: .fixed(precision: 1)),\(value.translation.height, format: .fixed(precision: 1)) magnitude=\(magnitude, format: .fixed(precision: 2)) selectedNode=\(selectedNodeID?.uuidString.prefix(8) ?? "nil") visibleNodes=\(viewModel.model.visibleNodes.count)")
        
        // If long press succeeded, don't process drag end - the menu is already showing
        if longPressSucceeded {
            Self.logger.debug("Long press succeeded - skipping drag end processing")
            longPressSucceeded = false
            longPressStartLocation = nil
            resetGestureState()
            return
        }
        
        // Clean up long press state if it wasn't converted to a long press
        if longPressStartLocation != nil {
            handleLongPressCancel()
            longPressStartLocation = nil
        }
        
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
        
        // If we dragged a table, rearrange seated persons
        if let table = draggedNode as? TableNode, moved {
            Self.logger.debug("Table was dragged - rearranging seated persons")
            viewModel.model.arrangePersonsAroundTable(tableID: table.id)
        }

        // Play haptic feedback for drag end if we were dragging a node
        if let dragged = draggedNode, moved {
            HapticManager.shared.playDragEnd(for: dragged)
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
    
    // MARK: - Long Press Handlers
    
    private func handleLongPressGestureEnded() {
        if draggedNode == nil {
            handleLongPressEnded()
        } else {
            handleLongPressCancel()
        }
    }
    private func handleLongPressStart() {
        Self.logger.debug("Long press started: Beginning desaturation")
        pressProgress = 0.0
        saturation = 1.0  // Start at full saturation
        longPressTask?.cancel()
        longPressTask = Task { @MainActor in
            let startTime = Date()
            let animationDuration = AppConstants.menuLongPressDuration * 0.75  // Animate for 75% of duration (1.0s)
            _ = AppConstants.menuLongPressDuration * 0.25  // Pause for 25% (0.33s) - unused but kept for documentation
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
        longPressSucceeded = false  // Reset flag
    }
    
    private func handleLongPressEnded() {
        Self.logger.debug("Long press ended: Checking what's under cursor")
        longPressTask?.cancel()
        longPressTask = nil
        longPressSucceeded = true  // Mark that long press succeeded
        
        // Perform hit test at the long press location to determine correct menu
        if let location = longPressStartLocation {
            if let hitNode = HitTestHelper.closestNode(at: location, visibleNodes: viewModel.model.visibleNodes, renderContext: renderContext) {
                selectedNodeID = hitNode.id
                selectedEdgeID = nil
                Self.logger.debug("Long press on node: \(hitNode.id.uuidString.prefix(8))")
            } else if let hitEdge = HitTestHelper.closestEdge(at: location, visibleEdges: viewModel.model.visibleEdges, visibleNodes: viewModel.model.visibleNodes, renderContext: renderContext) {
                selectedEdgeID = hitEdge.id
                selectedNodeID = nil
                Self.logger.debug("Long press on edge: \(hitEdge.id.uuidString.prefix(8))")
            } else {
                selectedNodeID = nil
                selectedEdgeID = nil
                Self.logger.debug("Long press on empty canvas")
            }
        }
        
        showMenu = true  // Trigger menu
        
        // Keep saturation at final desaturated state briefly before resetting
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms delay
            pressProgress = 0.0
            saturation = 1.0  // Reset saturation
        }
    }
    
    // MARK: - Tap Handling
    func handleTap(at location: CGPoint, visibleNodes: [any NodeProtocol], visibleEdges: [GraphEdge]) -> Bool {
        Self.logger.debug("handleTap: location=\(location.x, format: .fixed(precision: 1)),\(location.y, format: .fixed(precision: 1)) visibleNodes=\(visibleNodes.count)")
        
        #if DEBUG
        print("🎯 Tap Debug:")
        print("  Screen tap location: (\(location.x), \(location.y))")
        let modelPos = CoordinateTransformer.screenToModel(location, renderContext)
        print("  Converted to model: (\(modelPos.x), \(modelPos.y))")
        print("  RenderContext:")
        print("    Centroid: (\(renderContext.effectiveCentroid.x), \(renderContext.effectiveCentroid.y))")
        print("    ZoomScale: \(renderContext.zoomScale)")
        print("    Offset: (\(renderContext.offset.width), \(renderContext.offset.height))")
        print("    ViewSize: (\(renderContext.viewSize.width), \(renderContext.viewSize.height))")
        #endif
        
        if let node = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, renderContext: renderContext) {
            #if DEBUG
            print("  Hit node at model position: (\(node.position.x), \(node.position.y))")
            if let person = node as? PersonNode {
                print("  Node name: \(person.name)")
            }
            #endif
            return handleNodeTap(node: node)
        }
        
        if let edge = HitTestHelper.closestEdge(at: location, visibleEdges: visibleEdges, visibleNodes: visibleNodes, renderContext: renderContext) {
            return handleEdgeTap(edge: edge)
        }
        
        return handleBackgroundTap()
    }
    
    func handleControlNodeTap(controlNode: ControlNode) -> Bool {
        Self.logger.debug("Hit control node: \(controlNode.kind.rawValue) for owner \(controlNode.ownerID?.uuidString.prefix(8) ?? "nil")")
        
        // Set flag BEFORE triggering async action to prevent immediate drag-end from completing edge
        if controlNode.kind == .addEdge {
            justEnteredEdgeMode = true
            Self.logger.debug("Set justEnteredEdgeMode=true for addEdge control")
        }
        
        // Set flag for controls that will programmatically select a new node
        // This prevents the newly selected node from being immediately deselected
        let createsAndSelectsNode: [ControlKind] = [
            .addPersonNode, .addMealNode, .addTacoNight, .duplicate,
            .addChild, .addToggleChild
        ]
        if createsAndSelectsNode.contains(controlNode.kind) {
            justProgrammaticallySelected = true
            Self.logger.debug("Set justProgrammaticallySelected=true for \(controlNode.kind.rawValue) control")
        }
        
        // Handle openMenu control specially - it needs to show the menu
        if controlNode.kind == .openMenu, let ownerID = controlNode.ownerID {
            selectedNodeID = ownerID
            showMenu = true
            WKInterfaceDevice.current().play(.click)
            Self.logger.debug("Opened menu for node \(ownerID.uuidString.prefix(8))")
            return true
        }
        
        // Trigger the control's action
        Task {
            await viewModel.handleControlTap(control: controlNode)
        }
        WKInterfaceDevice.current().play(.click)
        return true
    }
    
    func handleEdgeAddingMode(targetNode: any NodeProtocol) -> Bool {
        Self.logger.debug("In edge-adding mode: draggedNodeID=\(viewModel.draggedNodeID?.uuidString.prefix(8) ?? "nil") targetNode=\(targetNode.id.uuidString.prefix(8))")
        
        let sourceID = viewModel.draggedNodeID
        
        if let sourceID = sourceID,
           targetNode.id != sourceID,
           !viewModel.model.edges.contains(where: { ($0.from == sourceID && $0.target == targetNode.id) ||
               ($0.from == targetNode.id && $0.target == sourceID) }) {
            // Create edge from source to tapped node
            let type = viewModel.pendingEdgeType
            Task {
                await viewModel.addEdge(from: sourceID, to: targetNode.id, type: type)
                Self.logger.info("✓ Created edge via tap: \(type.rawValue) from \(sourceID.uuidString.prefix(8)) → \(targetNode.id.uuidString.prefix(8))")
            }
            // Exit edge creation mode
            isAddingEdge = false
            viewModel.draggedNodeID = nil
            WKInterfaceDevice.current().play(.click)
            return true
        } else {
            // Exit edge mode and log reason
            isAddingEdge = false
            viewModel.draggedNodeID = nil
            
            if sourceID == nil {
                Self.logger.warning("Edge-adding mode active but draggedNodeID is nil!")
            } else if targetNode.id == sourceID {
                Self.logger.info("Cannot create edge to same node")
                WKInterfaceDevice.current().play(.failure)
            } else {
                Self.logger.info("Edge already exists between these nodes")
                WKInterfaceDevice.current().play(.failure)
            }
            // Return false to continue to node selection
            return false
        }
    }
    
    func handleNodeTap(node: any NodeProtocol) -> Bool {
        // Check if this is a control node
        if let controlNode = node as? ControlNode {
            return handleControlNodeTap(controlNode: controlNode)
        }
        
        // Check if we're in edge-adding mode
        if isAddingEdge {
            let handled = handleEdgeAddingMode(targetNode: node)
            if handled {
                return true
            }
            // If edge creation failed, continue to select the node
        }
        
        // Regular node tap - handle special node types
        
        // ChoiceNodes: Select/deselect choice in parent DecisionNode
        if let choiceNode = node as? ChoiceNode {
            Self.logger.debug("Tapped ChoiceNode: \(node.label) id=\(node.id.uuidString.prefix(8))")
            // Find parent DecisionNode
            if let parentEdge = viewModel.model.edges.first(where: { $0.target == node.id && $0.type == .hierarchy }),
               let parentDecision = viewModel.model.nodes.first(where: { $0.id == parentEdge.from }),
               let decisionNode = parentDecision.unwrapped as? DecisionNode {
                Task {
                    await viewModel.model.selectChoice(choiceNode.id, in: decisionNode.id)
                }
                HapticManager.shared.playNodeTap(for: choiceNode)
                return true
            }
        }
        
        // Regular node tap - toggle selection
        // But don't allow immediate deselection if this was just programmatically selected
        let newID: NodeID?
        if justProgrammaticallySelected && selectedNodeID == node.id {
            // This node was just programmatically selected, don't toggle it off
            newID = node.id
            justProgrammaticallySelected = false
            Self.logger.debug("Hit node: \(node.label) id=\(node.id.uuidString.prefix(8)) - ignoring toggle (just programmatically selected)")
        } else {
            newID = selectedNodeID == node.id ? nil : node.id
            Self.logger.debug("Hit node: \(node.label) id=\(node.id.uuidString.prefix(8)) newSelection=\(newID?.uuidString.prefix(8) ?? "nil")")
        }
        selectedNodeID = newID
        selectedEdgeID = nil
        if let id = newID {
            Task {
                await viewModel.generateControls(for: id)
            }
            
            // Auto-open menu for interactive node types
            // Need to check the unwrapped type since node is a protocol
            if let anyNode = viewModel.model.nodes.first(where: { $0.id == id }) {
                let shouldAutoOpen = anyNode.unwrapped is DecisionNode || 
                                    anyNode.unwrapped is TaskNode || 
                                    anyNode.unwrapped is MealNode || 
                                    anyNode.unwrapped is PreferenceNode
                if shouldAutoOpen {
                    Self.logger.debug("Auto-opening menu for interactive node type")
                    showMenu = true
                }
            }
        } else {
            Task {
                await viewModel.clearControls()
            }
        }
        HapticManager.shared.playNodeTap(for: node)
        return true
    }
    
    func handleEdgeTap(edge: GraphEdge) -> Bool {
        selectedEdgeID = selectedEdgeID == edge.id ? nil : edge.id
        selectedNodeID = nil
        Task { await viewModel.clearControls() }
        WKInterfaceDevice.current().play(.click)
        return true
    }
    
    func handleBackgroundTap() -> Bool {
        // Cancel edge creation mode if active
        if isAddingEdge {
            isAddingEdge = false
            viewModel.draggedNodeID = nil
            Self.logger.debug("Cancelled edge creation - tapped on background")
        }
        
        selectedNodeID = nil
        selectedEdgeID = nil
        Task { await viewModel.clearControls() }
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
        _ = selectedNodeID  // Capture before clearing - unused but kept for potential future use
        
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
