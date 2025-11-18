//
//  GraphGesturesModifier.swift
//  GraphEditorWatch
//
//  Created by handcart on 2025-08-16

import SwiftUI
import WatchKit
import GraphEditorShared
import os  // Added for optimized logging

struct GraphGesturesModifier: ViewModifier {
    let viewModel: GraphViewModel
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
    @Binding var saturation: Double  // NEW: Already present, but confirm
    
    @State private var dragStartNode: (any NodeProtocol)?
    @State private var isMovingSelectedNode: Bool = false
    @State private var gestureStartCentroid: CGPoint = .zero
    @State private var startLocation: CGPoint?
    @GestureState private var isLongPressing: Bool = false
    @State private var longPressTimer: Timer?
    @State private var pressProgress: Double = 0.0  // For progressive desaturation
    
    private let dragStartThreshold: CGFloat = 10.0  // Increased for better tap vs. drag distinction
    
    // Optimized logger
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "gestures")
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)  // Zero for immediate detection
            .onChanged { value in
                let visibleNodes = viewModel.model.visibleNodes()  // Or viewModel.model.nodes if no visibleNodes()
                let effectiveCentroid = viewModel.effectiveCentroid  // From ViewModel
                let context = GestureContext(zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: effectiveCentroid)
                handleDragChanged(value: value, visibleNodes: visibleNodes, context: context)
            }
            .onEnded { value in
                let visibleNodes = viewModel.model.visibleNodes()
                let visibleEdges = viewModel.model.visibleEdges()  // NEW: Get visible edges (assume method exists; use model.edges if not)
                let effectiveCentroid = viewModel.effectiveCentroid
                let context = GestureContext(zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: effectiveCentroid)
                handleDragEnded(value: value, visibleNodes: visibleNodes, visibleEdges: visibleEdges, context: context)
            }
        
        let longPressGesture = LongPressGesture(minimumDuration: AppConstants.menuLongPressDuration, maximumDistance: 10.0)
            .updating($isLongPressing) { currentState, gestureState, _ in
                gestureState = currentState  // Track if actively pressing
            }
            .onEnded { _ in
                handleLongPressEnded()
            }
        
        content
            .highPriorityGesture(dragGesture)
            .simultaneousGesture(longPressGesture)
            .onChange(of: isLongPressing) { _, newValue in
                if newValue {  // Press started
                    handleLongPressStart()
                } else {  // Press cancelled (e.g., moved too far)
                    handleLongPressCancel()
                }
            }
    }
    private func handleLongPressStart() {
        Self.logger.debug("Long press detected: Starting desaturation")
        WKInterfaceDevice.current().play(.click)  // Initial haptic
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            pressProgress += 0.05 / AppConstants.menuLongPressDuration
            saturation = 1.0 - pressProgress  // Progressive desaturation (1.0 -> 0.0)
            if pressProgress >= 1.0 {
                longPressTimer?.invalidate()
                longPressTimer = nil
            }
        }
    }

    private func handleLongPressCancel() {
        Self.logger.debug("Long press cancelled: Resetting saturation")
        withAnimation(.easeInOut(duration: 0.2)) {
            saturation = 1.0
        }
        pressProgress = 0.0
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    private func handleLongPressEnded() {
        if !isSimulating {
            selectedNodeID = nil
            selectedEdgeID = nil
            showMenu = true
            WKInterfaceDevice.current().play(.click)  // Better haptic for completion
            withAnimation(.easeInOut(duration: 0.1)) {
                saturation = 1.0  // Immediate reset on success
            }
            pressProgress = 0.0
            longPressTimer?.invalidate()
            longPressTimer = nil
            Self.logger.debug("Long press completed: Menu shown, saturation reset")
        }
    }
}

extension GraphGesturesModifier {
    
    // Hybrid hit test with screen-space thresholds, model-space for small zooms
    func hitTest(at screenPos: CGPoint, visibleNodes: [any NodeProtocol], visibleEdges: [GraphEdge], context: GestureContext) -> HitType? {
        let safeZoom = max(context.zoomScale, 0.1)
        let modelPos = CoordinateTransformer.screenToModel(screenPos, effectiveCentroid: context.effectiveCentroid, zoomScale: safeZoom, offset: context.offset, viewSize: context.viewSize)
        let minHitScreenRadius: CGFloat = 20.0  // Screen points
        let minHitModelRadius: CGFloat = minHitScreenRadius / safeZoom
        
        // Check nodes first
        for node in visibleNodes {
            let dist = distance(modelPos, node.position)
            if dist <= max(node.radius, minHitModelRadius) {
                return .node
            }
        }
        
        // Check edges
        for edge in visibleEdges {
            guard let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                  let toNode = visibleNodes.first(where: { $0.id == edge.target }) else { continue }
            let fromScreen = CoordinateTransformer.modelToScreen(fromNode.position, effectiveCentroid: context.effectiveCentroid, zoomScale: safeZoom, offset: context.offset, viewSize: context.viewSize)
            let toScreen = CoordinateTransformer.modelToScreen(toNode.position, effectiveCentroid: context.effectiveCentroid, zoomScale: safeZoom, offset: context.offset, viewSize: context.viewSize)
            let dist = pointToLineDistance(point: screenPos, from: fromScreen, endPoint: toScreen)
            if dist <= minHitScreenRadius / 2 {
                return .edge
            }
        }
        return nil
    }
    
    private func handleDragChanged(value: DragGesture.Value, visibleNodes: [any NodeProtocol], context: GestureContext) {
        let location = value.location
        let translation = value.translation
        let dragMagnitude = distance(.zero, CGPoint(x: translation.width, y: translation.height))
        
        // Initial drag: Check for node hit
        if draggedNode == nil && dragStartNode == nil {
            let hitContext = HitTestContext(zoomScale: context.zoomScale, offset: context.offset, viewSize: context.viewSize, effectiveCentroid: context.effectiveCentroid)
            let hitNode = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, context: hitContext)
            if let node = hitNode {
                dragStartNode = node
                draggedNode = node
                dragOffset = .zero
                isAddingEdge = true  // Enter edge creation mode
                GraphGesturesModifier.logger.debug("Drag of \(dragMagnitude) started from Node \(node.label)")
            } else {
                // Pan the canvas instead
                if panStartOffset == nil {
                    panStartOffset = offset
                }
                let delta = CGSize(width: translation.width, height: translation.height)
                offset = panStartOffset! + delta
            }
            startLocation = location  // For tap threshold in onEnded
            gestureStartCentroid = context.effectiveCentroid
            return
        }
        
        // Ongoing drag: Update drag offset and check for potential target
        if let node = draggedNode {
            dragOffset = CGPoint(x: translation.width / zoomScale, y: translation.height / zoomScale)
            let hitContext = HitTestContext(zoomScale: context.zoomScale, offset: context.offset, viewSize: context.viewSize, effectiveCentroid: context.effectiveCentroid)
            let potential = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, context: hitContext)
            potentialEdgeTarget = (potential?.id != node.id) ? potential : nil  // Avoid self-edges
            if let target = potentialEdgeTarget {
                GraphGesturesModifier.logger.debug("Potential edge target: Node \(target.label)")
            }
        }
    }
    
    private func handleDragEnded(value: DragGesture.Value, visibleNodes: [any NodeProtocol], visibleEdges: [GraphEdge], context: GestureContext) {
        let location = value.location
        let translation = value.translation
        let dragMagnitude = distance(.zero, CGPoint(x: translation.width, y: translation.height))
        
        // Defer cleanup (ensures reset even on errors/taps)
        defer { resetGestureState() }
        
        // Early exit for taps (short drag) - enhanced for node/edge selection
        if let start = startLocation, dragMagnitude < dragStartThreshold, distance(start, location) < dragStartThreshold {
            let wasHit = handleTap(at: location, visibleNodes: visibleNodes, visibleEdges: visibleEdges, context: context)
            if wasHit {
                WKInterfaceDevice.current().play(.click)  // Subtler haptic feedback (short tick/tap) on successful hit
            }
            return  // Exit early
        }
        
        GraphGesturesModifier.logger.debug("Processing as drag: magnitude \(dragMagnitude), translation (\(translation.width), \(translation.height))")
        
        if let dragged = draggedNode {
            Task { await viewModel.model.snapshot() }
            let modelDragOffset = CGPoint(x: translation.width / zoomScale, y: translation.height / zoomScale)
            GraphGesturesModifier.logger.debug("Drag offset in model: (\(modelDragOffset.x), \(modelDragOffset.y))")
            
            if let target = potentialEdgeTarget, target.id != dragged.id, isAddingEdge {
                handleEdgeCreation(from: dragged, to: target, translation: translation)
            } else {
                handleNodeMovement(for: dragged, with: modelDragOffset)
            }
        }
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            onUpdateZoomRanges()
        }
    }
    
    private func handleEdgeCreation(from dragged: any NodeProtocol, to target: any NodeProtocol, translation: CGSize) {
        // Duplicate check with logging
        let exists = viewModel.model.edges.contains { edge in
            (edge.from == dragged.id && edge.target == target.id) || (edge.from == target.id && edge.target == dragged.id)
        }
        if !exists {
            GraphGesturesModifier.logger.debug("No duplicate; adding edge")
            // Heuristic: Downward = hierarchy
            let type = (translation.height > 0) ? .hierarchy : viewModel.pendingEdgeType
            viewModel.pendingEdgeType = type  // Update for UI
            Task {
                await viewModel.addEdge(from: dragged.id, to: target.id, type: type)  // Async call
            }
            GraphGesturesModifier.logger.debug("Created edge of type \(type.rawValue) from node \(dragged.label) to \(target.label)")
            isAddingEdge = false
        } else {
            GraphGesturesModifier.logger.debug("Duplicate edge ignored between \(dragged.label) and \(target.label)")
        }
    }
    
    private func handleNodeMovement(for dragged: any NodeProtocol, with modelDragOffset: CGPoint) {
        // No target: Move the node (with casts for .with, as it's not on protocol)
        if let index = viewModel.model.nodes.firstIndex(where: { $0.id == dragged.id }) {
            let oldNode = viewModel.model.nodes[index]
            let unwrapped = oldNode.unwrapped
            let newPos = unwrapped.position + modelDragOffset
            let updatedNode: AnyNode
            if let concrete = unwrapped as? Node {
                let concreteUpdated = concrete.with(position: newPos, velocity: .zero)
                updatedNode = AnyNode(concreteUpdated)
            } else if let concrete = unwrapped as? ToggleNode {
                let concreteUpdated = concrete.with(position: newPos, velocity: .zero)
                updatedNode = AnyNode(concreteUpdated)
            } else {
                GraphGesturesModifier.logger.error("Unsupported node type for move: \(type(of: unwrapped))")
                return
            }
            viewModel.model.nodes[index] = updatedNode
            print("Moved node \(unwrapped.label) to new position \(newPos)")
            Task { await viewModel.model.startSimulation() }
        }
    }
    
    private func resetGestureState() {
        draggedNode = nil
        dragStartNode = nil
        dragOffset = .zero
        potentialEdgeTarget = nil
        panStartOffset = nil
        startLocation = nil
        isAddingEdge = false  // Reset edge mode
    }
}

extension GraphGesturesModifier {
    public func pointToLineDistance(point: CGPoint, from startPoint: CGPoint, endPoint: CGPoint) -> CGFloat {
        let pointX = Double(point.x), pointY = Double(point.y)
        let startX = Double(startPoint.x), startY = Double(startPoint.y)
        let endX = Double(endPoint.x), endY = Double(endPoint.y)
        
        let lineVecX = endX - startX
        let lineVecY = endY - startY
        let lineLen = hypot(lineVecX, lineVecY)
        
        if lineLen == 0 {
            return distance(point, startPoint)
        }
        
        let pointVecX = pointX - startX
        let pointVecY = pointY - startY
        let dot = pointVecX * lineVecX + pointVecY * lineVecY
        let denom = lineLen * lineLen
        let projectionParam = dot / denom
        let clampedParam = max(0.0, min(1.0, projectionParam))
        
        let projX = startX + lineVecX * clampedParam
        let projY = startY + lineVecY * clampedParam
        
        let proj = CGPoint(x: CGFloat(projX), y: CGFloat(projY))
        return distance(point, proj)
    }
}

// MARK: - Tap Handling
extension GraphGesturesModifier {
    private func handleTap(at location: CGPoint, visibleNodes: [any NodeProtocol], visibleEdges: [GraphEdge], context: GestureContext) -> Bool {
        if handleChevronTap(at: location, visibleNodes: visibleNodes, context: context) {
            return true
        }
        if handleNodeTap(at: location, visibleNodes: visibleNodes, context: context) {
            return true
        }
        if handleEdgeTap(at: location, visibleEdges: visibleEdges, visibleNodes: visibleNodes, context: context) {
            return true
        }
        
        // Miss: Deselect both
        selectedNodeID = nil
        selectedEdgeID = nil
        Self.logger.debug("Tap miss: Deselected all")
        return false
    }
    
    private func handleChevronTap(at location: CGPoint, visibleNodes: [any NodeProtocol], context: GestureContext) -> Bool {
        guard let    selectedID = selectedNodeID,
              let selectedNode = visibleNodes.first(where: { $0.id == selectedID }) as? ToggleNode else {
            return false
        }
        
        let screenPos = CoordinateTransformer.modelToScreen(
            selectedNode.position,
            effectiveCentroid: context.effectiveCentroid,
            zoomScale: context.zoomScale,
            offset: context.offset,
            viewSize: context.viewSize
        )
        
        let nodeRadius = selectedNode.radius * context.zoomScale
        let chevronCenter = CGPoint(
            x: screenPos.x + nodeRadius + 14 * context.zoomScale,
            y: screenPos.y
        )
        
        let chevronHitRadius: CGFloat = 20 * context.zoomScale
        let distanceToChevron = hypot(location.x - chevronCenter.x, location.y - chevronCenter.y)
        
        if distanceToChevron < chevronHitRadius {
            Task {
                await viewModel.model.snapshot()
                let updated = selectedNode.handlingTap()
                if let index = viewModel.model.nodes.firstIndex(where: { $0.id == selectedID }) {
                    viewModel.model.nodes[index] = AnyNode(updated)
                }
                await viewModel.model.startSimulation()
            }
            Self.logger.debug("Toggled expansion for node \(selectedNode.label)")
            return true
        }
        return false
    }

    private func handleNodeTap(at location: CGPoint, visibleNodes: [any NodeProtocol], context: GestureContext) -> Bool {
        let hitContext = HitTestContext(zoomScale: context.zoomScale, offset: context.offset, viewSize: context.viewSize, effectiveCentroid: context.effectiveCentroid)
        guard let hitNode = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, context: hitContext) else {
            return false
        }
        
        if selectedNodeID == hitNode.id {
            selectedNodeID = nil
            Self.logger.debug("Deselected Node \(hitNode.label)")
        } else {
            selectedNodeID = hitNode.id
            selectedEdgeID = nil
            Self.logger.debug("Selected Node \(hitNode.label)")
        }
        return true
    }

    private func handleEdgeTap(at location: CGPoint, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], context: GestureContext) -> Bool {
        let hitContext = HitTestContext(zoomScale: context.zoomScale, offset: context.offset, viewSize: context.viewSize, effectiveCentroid: context.effectiveCentroid)
        guard let hitEdge = HitTestHelper.closestEdge(at: location, visibleEdges: visibleEdges, visibleNodes: visibleNodes, context: hitContext) else {
            return false
        }
        
        if selectedEdgeID == hitEdge.id {
            selectedEdgeID = nil
            Self.logger.debug("Deselected Edge \(String(describing: hitEdge.id))")
        } else {
            selectedEdgeID = hitEdge.id
            selectedNodeID = nil
            Self.logger.debug("Selected Edge \(String(describing: hitEdge.id))")
        }
        return true
    }
}
