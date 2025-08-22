//
//  GraphGesturesModifier.swift
//  GraphEditorWatch
//
//  Created by handcart on 2025-08-16

import SwiftUI
import WatchKit
import GraphEditorShared

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
    
    @State private var dragStartNode: (any NodeProtocol)? = nil
    @State private var isMovingSelectedNode: Bool = false
    @State private var longPressTimer: Timer? = nil
    @State private var isLongPressTriggered: Bool = false
    @State private var hasStartedGesture: Bool = false
    @State private var dragTimer: Timer? = nil
    
    private let dragStartThreshold: CGFloat = 5.0
    
    
    private func screenToModel(_ screenPos: CGPoint, zoomScale: CGFloat, offset: CGSize, viewSize: CGSize) -> CGPoint {
        guard zoomScale > 0 else { return .zero }

        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let panOffset = CGPoint(x: offset.width, y: offset.height)
        let effectiveCentroid = focalPointForCentering()
        
        let translated = CGPoint(
            x: screenPos.x - viewCenter.x - panOffset.x,
            y: screenPos.y - viewCenter.y - panOffset.y
        )
        let unscaled = CGPoint(
            x: (translated.x / zoomScale).rounded(to: 2),  // Round for precision
            y: (translated.y / zoomScale).rounded(to: 2)
        )
        return CGPoint(
            x: (unscaled.x + effectiveCentroid.x).rounded(to: 2),
            y: (unscaled.y + effectiveCentroid.y).rounded(to: 2)
        )
    }
    
    private func focalPointForCentering() -> CGPoint {
        let visibleNodes = viewModel.model.visibleNodes()
        guard !visibleNodes.isEmpty else { return .zero }  // New: Guard against empty graph
        var effectiveCentroid = visibleNodes.centroid() ?? .zero
        if let selectedID = selectedNodeID, let selected = visibleNodes.first(where: { $0.id == selectedID }) {
            effectiveCentroid = selected.position
        } else if let selectedEdgeID = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdgeID }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }), let to = visibleNodes.first(where: { $0.id == edge.to }) {
            effectiveCentroid = (from.position + to.position) / 2
        }
        return effectiveCentroid
    }
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0)
        
            .onChanged { value in
                if isLongPressTriggered { return }
                dragTimer?.invalidate()
                dragTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: false) { _ in
                    
                    // New: Define hit radius once at top for consistency
                    let screenHitRadius: CGFloat = Constants.App.hitScreenRadius  // Fixed on-screen size
                    let modelHitRadius = screenHitRadius / zoomScale  // Dynamic model-space conversion

                    let translationDistance = hypot(value.translation.width, value.translation.height)
                    let touchPos = screenToModel(value.location, zoomScale: zoomScale, offset: offset, viewSize: viewSize)

                    if dragStartNode == nil {
                        let startModelPos = screenToModel(value.startLocation, zoomScale: zoomScale, offset: offset, viewSize: viewSize)
                        if let hitNode = viewModel.model.nodes.first(where: { distance($0.position, startModelPos) < modelHitRadius }) {
                            dragStartNode = hitNode
                            isMovingSelectedNode = (hitNode.id == selectedNodeID)
                        }
                    }

                    if translationDistance > 0.0 {
                        hasStartedGesture = true
                    }

                    if translationDistance < 1.0 && longPressTimer == nil && hasStartedGesture {
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                            self.showMenu = true
                            WKInterfaceDevice.current().play(.click)
                            self.isLongPressTriggered = true
                            self.longPressTimer = nil
                        }
                        print("Long-press timer started")
                    }

                    if translationDistance < dragStartThreshold {
                        return
                    }

                    longPressTimer?.invalidate()
                    longPressTimer = nil
                        
                    if isMovingSelectedNode, let node = dragStartNode {
                        dragOffset = CGPoint(x: value.translation.width / zoomScale, y: value.translation.height / zoomScale)
                        draggedNode = node
                    } else {
                        if panStartOffset == nil {
                            panStartOffset = offset
                        }
                        offset = CGSize(width: panStartOffset!.width + value.translation.width,
                                        height: panStartOffset!.height + value.translation.height)
                    }
                    
                    potentialEdgeTarget = viewModel.model.nodes.first {
                        dragStartNode?.id != $0.id && distance($0.position, touchPos) < modelHitRadius  // Use consistent var
                    }
                    
                    // Diagnostic logs for .onChanged (unchanged)
                    let effectiveCentroid = focalPointForCentering()
                    let translated = CGPoint(x: value.location.x - viewSize.width / 2 - offset.width, y: value.location.y - viewSize.height / 2 - offset.height)
                    let unscaled = CGPoint(x: translated.x / zoomScale, y: translated.y / zoomScale)
                    print("--- .onChanged Diagnostic ---")
                    print("Effective Centroid: \(effectiveCentroid)")
                    print("Screen Pos: \(value.location)")
                    print("Translated: \(translated)")
                    print("Unscaled: \(unscaled)")
                    print("Model Pos (touchPos): \(touchPos)")
                    print("Visible Nodes Positions: \(viewModel.model.visibleNodes().map { $0.position })")
                    print("-----------------------------")
                
                    
                }
                return

                }
        
            .onEnded { value in
                hasStartedGesture = false
                if isLongPressTriggered {
                    isLongPressTriggered = false
                    longPressTimer?.invalidate()  // New: Explicit cleanup
                    longPressTimer = nil
                    return
                }
                
                longPressTimer?.invalidate()
                longPressTimer = nil
                
                viewModel.resumeSimulation()
                
                // New: Define hit radius once at top for consistency (with tap tolerance)
                let screenHitRadius: CGFloat = Constants.App.hitScreenRadius * 1.5  // Larger for taps
                let modelHitRadius = screenHitRadius / zoomScale  // Dynamic model-space

                let dragDistance = hypot(value.translation.width, value.translation.height)
                let tapModelPos = screenToModel(value.startLocation, zoomScale: zoomScale, offset: offset, viewSize: viewSize)
                
             
                    if dragDistance < Constants.App.tapThreshold {
                        if let hitNode = viewModel.model.visibleNodes().first(where: { distance($0.position, tapModelPos) < modelHitRadius }) {
                            let updatedNode = hitNode.handlingTap()  // Toggle if applicable
                            viewModel.model.updateNode(updatedNode)
                            selectedNodeID = (selectedNodeID == hitNode.id) ? nil : hitNode.id
                            selectedEdgeID = nil
                            print("Tap detected at model position: \(tapModelPos). SelectedNodeID before: \(selectedNodeID?.uuidString ?? "nil"), SelectedEdgeID before: \(selectedEdgeID?.uuidString ?? "nil")")
                        WKInterfaceDevice.current().play(.click)
                    } else if let hitEdge = viewModel.model.visibleEdges().first(where: { edge in
                        if let from = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                           let to = viewModel.model.nodes.first(where: { $0.id == edge.to }),
                           pointToLineDistance(point: tapModelPos, from: from.position, to: to.position) < modelHitRadius {  // Use consistent var
                            return true
                        }
                        return false
                    }) {
                        print("Edge hit detected with tightened radius.")
                        selectedEdgeID = (selectedEdgeID == hitEdge.id) ? nil : hitEdge.id
                        selectedNodeID = nil
                        WKInterfaceDevice.current().play(.click)
                    } else {
                        print("Background tap confirmed (no hit with tightened radius). Deselecting everything.")
                        selectedNodeID = nil
                        selectedEdgeID = nil
                    }
                    
                    print("SelectedNodeID after tap: \(selectedNodeID?.uuidString ?? "nil"), SelectedEdgeID after: \(selectedEdgeID?.uuidString ?? "nil")")
                    
                    // Diagnostic logs for tap in .onEnded (unchanged)
                    let effectiveCentroid = focalPointForCentering()
                    let translated = CGPoint(x: value.startLocation.x - viewSize.width / 2 - offset.width, y: value.startLocation.y - viewSize.height / 2 - offset.height)
                    let unscaled = CGPoint(x: translated.x / zoomScale, y: translated.y / zoomScale)
                    print("--- Tap (.onEnded) Diagnostic ---")
                    print("Effective Centroid: \(effectiveCentroid)")
                    print("Screen Pos: \(value.startLocation)")
                    print("Translated: \(translated)")
                    print("Unscaled: \(unscaled)")
                    print("Model Pos (tapModelPos): \(tapModelPos)")
                    print("Visible Nodes Positions: \(viewModel.model.visibleNodes().map { $0.position })")
                    print("--------------------------------")
                } else {
                    viewModel.snapshot()
                    if let startNode = dragStartNode, let target = potentialEdgeTarget, target.id != startNode.id {
                        let newEdge = GraphEdge(from: startNode.id, to: target.id)
                        if !viewModel.model.hasCycle(adding: newEdge) &&
                           !viewModel.model.edges.contains(where: { $0.from == startNode.id && $0.to == target.id }) {
                            viewModel.model.edges.append(newEdge)
                            viewModel.model.startSimulation()
                            WKInterfaceDevice.current().play(.success)
                        }
                    } else if isMovingSelectedNode, let node = dragStartNode,
                              let index = viewModel.model.nodes.firstIndex(where: { $0.id == node.id }) {
                        var updatedNode = viewModel.model.nodes[index]
                        updatedNode.position.x += value.translation.width / zoomScale
                        updatedNode.position.y += value.translation.height / zoomScale
                        viewModel.model.nodes[index] = updatedNode
                        viewModel.model.startSimulation()
                        WKInterfaceDevice.current().play(.click)
                    }
                    viewModel.handleTap()
                }
                
                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                    onUpdateZoomRanges()
                }
                
                dragStartNode = nil
                isMovingSelectedNode = false
                draggedNode = nil
                dragOffset = .zero
                potentialEdgeTarget = nil
                panStartOffset = nil
                onUpdateZoomRanges()
            }
        content
            .gesture(dragGesture)
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        hypot(p1.x - p2.x, p1.y - p2.y)
    }
    
    private func pointToLineDistance(point: CGPoint, from: CGPoint, to: CGPoint) -> CGFloat {
        let lineVec = to - from
        let pointVec = point - from
        let lineLen = hypot(lineVec.x, lineVec.y)
        if lineLen == 0 { return hypot(point.x - from.x, point.y - from.y) }
        let dot = pointVec.x * lineVec.x + pointVec.y * lineVec.y
        let denom = lineLen * lineLen
        let tUnclamped = dot / denom
        let t = max(0, min(1, tUnclamped))
        let projection = from + (lineVec * t)
        return hypot(point.x - projection.x, point.y - projection.y)
    }
}
