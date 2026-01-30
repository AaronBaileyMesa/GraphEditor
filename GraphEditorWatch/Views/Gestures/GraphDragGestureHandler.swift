//
//  GraphDragGestureHandler.swift
//  GraphEditorWatch
//

import SwiftUI
import GraphEditorShared
import WatchKit  // Needed for play(.click)

struct GraphDragGestureHandler: ViewModifier {
    let viewModel: GraphViewModel
    let renderContext: RenderContext
    let viewSize: CGSize
    
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize
    @Binding var draggedNode: (any NodeProtocol)?
    @Binding var dragOffset: CGPoint
    @Binding var currentDragLocation: CGPoint?
    @Binding var dragStartNode: (any NodeProtocol)?
    @Binding var panStartOffset: CGSize?
    @Binding var isAddingEdge: Bool
    @Binding var potentialEdgeTarget: (any NodeProtocol)?
    
    // ADD THESE MISSING BINDINGS
    @Binding var selectedNodeID: NodeID?
    @Binding var selectedEdgeID: UUID?

    private let dragStartThreshold: CGFloat = 5.0
    
    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in handleDragChanged(value) }
                    .onEnded { value in handleDragEnded(value) }
            )
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        print("Drag changed at time: \(Date().timeIntervalSinceReferenceDate), location: \(value.location), translation: \(value.translation), magnitude: \(hypot(value.translation.width, value.translation.height))")  // NEW: Log for debugging sim issues
        
        currentDragLocation = value.location
        
        let translation = value.translation
        let magnitude = hypot(translation.width, translation.height)
        
        if draggedNode == nil && magnitude > dragStartThreshold {
            let screenPos = value.startLocation
            let modelPos = CoordinateTransformer.screenToModel(screenPos, renderContext)
            
            if let hitNode = HitTestHelper.closestNode(at: screenPos,
                                                       visibleNodes: viewModel.model.visibleNodes,
                                                       renderContext: renderContext) {
                draggedNode = hitNode
                dragStartNode = hitNode
                dragOffset = modelPos - hitNode.position
                selectedNodeID = hitNode.id
                viewModel.draggedNodeID = hitNode.id
                Task { await viewModel.model.pauseSimulation() }
                return
            }
            
            // Also handle edge selection on drag start (from original code)
            if let hitEdge = HitTestHelper.closestEdge(at: screenPos,
                                                       visibleEdges: viewModel.model.visibleEdges,
                                                       visibleNodes: viewModel.model.visibleNodes,
                                                       renderContext: renderContext) {
                selectedEdgeID = hitEdge.id
                selectedNodeID = nil
                return
            }
            
            panStartOffset = offset
        }
        
        if let dragged = draggedNode {
            let screenPos = value.location
                let newModelPos = CoordinateTransformer.screenToModel(screenPos, renderContext) - dragOffset
                
                if let nodeIndex = viewModel.model.nodes.firstIndex(where: { $0.id == dragged.id }) {
                    viewModel.model.nodes[nodeIndex].position = newModelPos
                    viewModel.model.objectWillChange.send()  // Trigger redraw
                    draggedNode = viewModel.model.nodes[nodeIndex]  // Refresh reference
                }
                
                if let ownerID = selectedNodeID {
                    updateControlNodes(for: ownerID, to: newModelPos)
                }
            
            if isAddingEdge, let start = dragStartNode {
                if let target = HitTestHelper.closestNode(at: value.location,
                                                          visibleNodes: viewModel.model.visibleNodes.filter { $0.id != start.id },
                                                          renderContext: renderContext) {
                    potentialEdgeTarget = target
                } else {
                    potentialEdgeTarget = nil
                }
            }
            return
        }
        
        if let start = panStartOffset {
            offset = CGSize(width: start.width + translation.width / zoomScale,
                            height: start.height + translation.height / zoomScale)
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let moved = hypot(value.translation.width, value.translation.height) >= dragStartThreshold
        
        if !moved {
            // Short drag → treat as tap
            handleShortTap(at: value.location)
            resetDragState()
            return
        }
        
        // Edge creation
        if isAddingEdge,
           let from = draggedNode ?? dragStartNode,
           let target = HitTestHelper.closestNode(at: value.location,
                                                  visibleNodes: viewModel.model.visibleNodes,
                                                  renderContext: renderContext),
           from.id != target.id,
           !viewModel.model.edges.contains(where: {
               ($0.from == from.id && $0.target == target.id) ||
               ($0.from == target.id && $0.target == from.id)
           }) {
            let type = viewModel.pendingEdgeType
            Task { await viewModel.addEdge(from: from.id, to: target.id, type: type) }
        }
        
        resetDragState()
    }
    
    private func handleShortTap(at location: CGPoint) {
        let visibleNodes = viewModel.model.visibleNodes
        let visibleEdges = viewModel.model.visibleEdges
        
        if let node = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, renderContext: renderContext) {
            selectedNodeID = selectedNodeID == node.id ? nil : node.id
            selectedEdgeID = nil
            if selectedNodeID != nil {
                Task { await viewModel.generateControls(for: node.id) }
            } else {
                Task { await viewModel.clearControls() }
            }
            WKInterfaceDevice.current().play(.click)
            return
        }
        
        if let edge = HitTestHelper.closestEdge(at: location, visibleEdges: visibleEdges, visibleNodes: visibleNodes, renderContext: renderContext) {
            selectedEdgeID = selectedEdgeID == edge.id ? nil : edge.id
            selectedNodeID = nil
            Task { await viewModel.clearControls() }
            WKInterfaceDevice.current().play(.click)
            return
        }
        
        selectedNodeID = nil
        selectedEdgeID = nil
        Task { await viewModel.clearControls() }
    }
    
    private func updateControlNodes(for ownerID: NodeID, to newOwnerPos: CGPoint) {
        for iteration in viewModel.model.ephemeralControlNodes.indices {
            guard viewModel.model.ephemeralControlNodes[iteration].ownerID == ownerID else { continue }
            
            let priority = viewModel.model.ephemeralControlNodes[iteration].priority
            let freeSlots = viewModel.model.getFreeSlots(for: ownerID)
            guard priority < freeSlots.count else { continue }
            
            let angle = freeSlots[priority]
            let offsetDistance: CGFloat = Constants.App.nodeModelRadius * 3  // Standard spacing: 3× node radius
            
            let offset = CGPoint(
                x: cos(angle) * offsetDistance,
                y: sin(angle) * offsetDistance
            )
            
            viewModel.model.ephemeralControlNodes[iteration].position = newOwnerPos + offset
        }
    }
    
    private func resetDragState() {
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
