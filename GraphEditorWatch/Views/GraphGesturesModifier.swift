//
//  GraphGesturesModifier.swift
//  GraphEditorWatch
//
//  Fully working, clean, no compile errors
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
    
    private let dragStartThreshold: CGFloat = 10.0
    private static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "gestures")
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                currentDragLocation = value.location  // ← SET THE SHARED BINDING HERE
                handleDragChanged(value)
            }
            .onEnded { value in
                currentDragLocation = nil  // ← RESET ON END
                handleDragEnded(value)
            }
        
        let longPress = LongPressGesture(minimumDuration: AppConstants.menuLongPressDuration, maximumDistance: 10)
            .updating($isLongPressing) { current, state, _ in state = current }
            .onEnded { _ in handleLongPressEnded() }
        
        content
            .highPriorityGesture(dragGesture)
            .simultaneousGesture(longPress)
            .onChange(of: isLongPressing) { _, new in new ? handleLongPressStart() : handleLongPressCancel() }
    }
    
    // MARK: - Long Press
    private func handleLongPressStart() {
        Self.logger.debug("Long press started")
        WKInterfaceDevice.current().play(.click)
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            pressProgress += 0.05 / AppConstants.menuLongPressDuration
            saturation = 1.0 - pressProgress
            if pressProgress >= 1.0 {
                longPressTimer?.invalidate()
            }
        }
    }
    
    private func handleLongPressCancel() {
        withAnimation(.easeInOut(duration: 0.2)) { saturation = 1.0 }
        pressProgress = 0.0
        longPressTimer?.invalidate()
    }
    
    private func handleLongPressEnded() {
        guard !isSimulating else { return }
        selectedNodeID = nil
        selectedEdgeID = nil
        showMenu = true
        WKInterfaceDevice.current().play(.click)
        withAnimation(.easeInOut(duration: 0.1)) { saturation = 1.0 }
        longPressTimer?.invalidate()
    }
    
    // MARK: - Drag
    private func handleDragChanged(_ value: DragGesture.Value) {
        let pos = value.location
        let nodes = viewModel.model.visibleNodes
        let edges = viewModel.model.visibleEdges
        
        if hypot(value.translation.width, value.translation.height) < dragStartThreshold { return }
        
        let hit = hitTest(at: pos, visibleNodes: nodes, visibleEdges: edges)
        
        switch hit {
        case .node(let node):
            if draggedNode == nil {
                draggedNode = node
                dragStartNode = node
                let modelPos = CoordinateTransformer.screenToModel(pos, renderContext)
                dragOffset = node.position - modelPos
                viewModel.draggedNodeID = node.id
                WKInterfaceDevice.current().play(.click)
            }
            
            // Live move
            if let dragged = draggedNode {
                let modelPos = CoordinateTransformer.screenToModel(pos, renderContext)
                let newPos = modelPos + dragOffset
                if let indexI = viewModel.model.nodes.firstIndex(where: { $0.id == dragged.id }) {
                    var nodeN = viewModel.model.nodes[indexI]
                    nodeN = AnyNode(nodeN.unwrapped.with(position: newPos, velocity: .zero))
                    viewModel.model.nodes[indexI] = nodeN
                    
                    // NEW: Sync subtree positions if this is a collapsed ToggleNode
                    // Keeps displayRadius stable by moving hidden children along
                    if nodeN.unwrapped is ToggleNode {
                        viewModel.model.updateSubtreePositions(for: nodeN.id, to: newPos)
                    } else {
                        viewModel.model.objectWillChange.send()  // Ensure redraw for non-ToggleNodes
                    }
                }
                
                // Edge preview
                if isAddingEdge,
                   let target = HitTestHelper.closestNode(at: pos, visibleNodes: nodes, renderContext: renderContext),
                   target.id != dragged.id {
                    potentialEdgeTarget = target
                } else {
                    potentialEdgeTarget = nil
                }
            }
            
        case .edge(let edge):
            selectedEdgeID = edge.id
            selectedNodeID = nil
            
        case .none:
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
        
        // Edge creation
        if isAddingEdge,
           let from = draggedNode ?? dragStartNode,
           let target = HitTestHelper.closestNode(at: value.location,
                                              visibleNodes: viewModel.model.visibleNodes,
                                              renderContext: renderContext),
           from.id != target.id,
           !viewModel.model.edges.contains(where: { $0.from == from.id && $0.target == target.id ||
                                                    $0.from == target.id && $0.target == from.id }) {
            let type = viewModel.pendingEdgeType
            Task { await viewModel.addEdge(from: from.id, to: target.id, type: type) }
            Self.logger.debug("Added edge: \(type.rawValue) \"\(from.label)\" → \"\(target.label)\"")
        }
        
        resetGestureState()
    }
    
    // MARK: - Tap
    private func handleTap(at location: CGPoint, visibleNodes: [any NodeProtocol], visibleEdges: [GraphEdge]) -> Bool {
        if let node = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, renderContext: renderContext) {
            selectedNodeID = selectedNodeID == node.id ? nil : node.id
            selectedEdgeID = nil
            WKInterfaceDevice.current().play(.click)
            return true
        }
        if let edge = HitTestHelper.closestEdge(at: location, visibleEdges: visibleEdges, visibleNodes: visibleNodes, renderContext: renderContext) {
            selectedEdgeID = selectedEdgeID == edge.id ? nil : edge.id
            selectedNodeID = nil
            WKInterfaceDevice.current().play(.click)
            return true
        }
        selectedNodeID = nil
        selectedEdgeID = nil
        return false
    }
    
    // MARK: - Hit Test
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
