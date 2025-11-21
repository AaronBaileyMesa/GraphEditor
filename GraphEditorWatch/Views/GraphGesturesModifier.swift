//
//  GraphGesturesModifier.swift
//  GraphEditorWatch
//
//  Created by handcart on 2025-08-16

import SwiftUI
import WatchKit
import GraphEditorShared
import os  // Added for optimized logging

struct GestureContext {
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    let effectiveCentroid: CGPoint
}

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
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let visibleNodes = viewModel.model.visibleNodes
                let effectiveCentroid = viewModel.effectiveCentroid
                
                let renderContext = RenderContext(
                    effectiveCentroid: effectiveCentroid,
                    zoomScale: zoomScale,
                    offset: offset,
                    viewSize: viewSize
                )
                
                let context = GestureContext(
                    zoomScale: zoomScale,
                    offset: offset,
                    viewSize: viewSize,
                    effectiveCentroid: effectiveCentroid
                )
                
                // Fixed: pass renderContext
                handleDragChanged(value: value,
                                  visibleNodes: visibleNodes,
                                  context: context,
                                  renderContext: renderContext)
            }
            .onEnded { value in
                let visibleNodes = viewModel.model.visibleNodes
                let visibleEdges = viewModel.model.visibleEdges
                let effectiveCentroid = viewModel.effectiveCentroid
                
                let renderContext = RenderContext(
                    effectiveCentroid: effectiveCentroid,
                    zoomScale: zoomScale,
                    offset: offset,
                    viewSize: viewSize
                )
                
                let context = GestureContext(
                    zoomScale: zoomScale,
                    offset: offset,
                    viewSize: viewSize,
                    effectiveCentroid: effectiveCentroid
                )
                
                // Fixed: pass renderContext
                handleDragEnded(value: value,
                                visibleNodes: visibleNodes,
                                visibleEdges: visibleEdges,
                                context: context,
                                renderContext: renderContext)
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
    
    private func handleDragChanged(
        value: DragGesture.Value,
        visibleNodes: [any NodeProtocol],
        context: GestureContext,
        renderContext: RenderContext                  // ← THIS IS REQUIRED NOW
    ) {
        // 1. Initial node pickup (tap → drag)
        if draggedNode == nil && dragOffset == .zero {
            if let tappedNode = HitTestHelper.closestNode(
                at: value.location,
                visibleNodes: visibleNodes,
                renderContext: renderContext) {       // ← uses RenderContext
            
                draggedNode = tappedNode
                dragStartNode = tappedNode
                
                let modelPos = tappedNode.position
                let screenPos = CoordinateTransformer.modelToScreen(modelPos, renderContext)
                dragOffset = CGPoint(x: value.location.x - screenPos.x,
                                     y: value.location.y - screenPos.y)
                
                GraphGesturesModifier.logger.debug("Started dragging node \(tappedNode.label)")
            }
        }
        
        // 2. Potential edge target (when adding edge)
        if isAddingEdge {
            potentialEdgeTarget = HitTestHelper.closestNode(
                at: value.location,
                visibleNodes: visibleNodes,
                renderContext: renderContext)
        } else {
            potentialEdgeTarget = nil
        }
        
        // 3. Actual drag movement (node dragging or view panning)
        if let dragged = draggedNode {
            // Optional live edge preview
            if isAddingEdge {
                potentialEdgeTarget = HitTestHelper.closestNode(
                    at: value.location,
                    visibleNodes: visibleNodes,
                    renderContext: renderContext)
            } else {
                potentialEdgeTarget = nil
            }

            // Live, buttery-smooth node movement
            let screenPos = CGPoint(x: value.location.x - dragOffset.x,
                                    y: value.location.y - dragOffset.y)
            let newModelPos = CoordinateTransformer.screenToModel(screenPos, renderContext)

            Task { @MainActor in
                await viewModel.model.moveNode(withID: dragged.id, to: newModelPos)
            }
        } else {
            // Existing view panning code — leave unchanged
            if panStartOffset == nil {
                panStartOffset = offset
            }
            let translation = value.translation
            offset = CGSize(width: (panStartOffset?.width ?? 0) + translation.width,
                            height: (panStartOffset?.height ?? 0) + translation.height)
        }
    }

    private func handleDragEnded(
        value: DragGesture.Value,
        visibleNodes: [any NodeProtocol],
        visibleEdges: [GraphEdge],
        context: GestureContext,
        renderContext: RenderContext                  // ← THIS IS REQUIRED NOW
    ) {
        Task { @MainActor in
            await viewModel.model.resumeSimulation()
        }
        // Final edge creation
        if isAddingEdge,
           let fromNode = draggedNode,
           let toNode = HitTestHelper.closestNode(
               at: value.location,
               visibleNodes: visibleNodes,
               renderContext: renderContext),
           fromNode.id != toNode.id {
           
            Task {
                await viewModel.model.addEdge(from: fromNode.id, target: toNode.id, type: .hierarchy)
            }
            GraphGesturesModifier.logger.debug("Added edge from \(fromNode.label) to \(toNode.label)")
        }
        
        // Tap on release (if no significant movement)
        let movedDistance = hypot(value.translation.width, value.translation.height)
        if movedDistance < dragStartThreshold {
            _ = handleTap(at: value.location,
                          visibleNodes: visibleNodes,
                          visibleEdges: visibleEdges,
                          renderContext: renderContext)
        }
        
        resetGestureState()
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
    
    func handleTap(at location: CGPoint,
                   visibleNodes: [any NodeProtocol],
                   visibleEdges: [GraphEdge],
                   renderContext: RenderContext) -> Bool {   // ← now takes RenderContext
        
        if let hitNode = HitTestHelper.closestNode(
            at: location,
            visibleNodes: visibleNodes,
            renderContext: renderContext) {                 // ← new signature
        
            if selectedNodeID == hitNode.id {
                selectedNodeID = nil
            } else {
                selectedNodeID = hitNode.id
                selectedEdgeID = nil
            }
            return true
        }
        
        if let hitEdge = HitTestHelper.closestEdge(
            at: location,
            visibleEdges: visibleEdges,
            visibleNodes: visibleNodes,
            renderContext: renderContext) {                 // ← new signature
        
            if selectedEdgeID == hitEdge.id {
                selectedEdgeID = nil
            } else {
                selectedEdgeID = hitEdge.id
                selectedNodeID = nil
            }
            return true
        }
        
        selectedNodeID = nil
        selectedEdgeID = nil
        return false
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
