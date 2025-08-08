//
//  GraphGesturesModifier.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//

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
    
    @State private var dragStartNode: (any NodeProtocol)? = nil  // New: Track node at drag start
    @State private var isMovingSelectedNode: Bool = false  // New: Flag for moving selected node
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0)
            .onChanged { value in
                let transform = CGAffineTransform(scaleX: zoomScale, y: zoomScale).translatedBy(x: offset.width, y: offset.height)
                let inverseTransform = transform.inverted()
                let touchPos = value.location.applying(inverseTransform)
                
                if dragStartNode == nil {
                    // Detect start on node
                    if let hitNode = viewModel.model.nodes.first(where: { distance($0.position, value.startLocation.applying(inverseTransform)) < AppConstants.hitScreenRadius / zoomScale }) {
                        dragStartNode = hitNode
                        isMovingSelectedNode = (hitNode.id == selectedNodeID)
                    }
                }
                
                if isMovingSelectedNode, let node = dragStartNode {
                    // Update dragOffset for moving
                    dragOffset = CGPoint(x: value.translation.width / zoomScale, y: value.translation.height / zoomScale)
                    draggedNode = node  // Set for rendering
                } else {
                    // Pan if not moving node
                    if panStartOffset == nil {
                        panStartOffset = offset
                    }
                    offset = CGSize(width: panStartOffset!.width + value.translation.width, height: panStartOffset!.height + value.translation.height)
                }
                
                // Update potential target for edge creation
                potentialEdgeTarget = viewModel.model.nodes.first {
                    dragStartNode?.id != $0.id && distance($0.position, touchPos) < AppConstants.hitScreenRadius / zoomScale
                }
            }
            .onEnded { value in
                let dragDistance = hypot(value.translation.width, value.translation.height)
                let transform = CGAffineTransform(scaleX: zoomScale, y: zoomScale).translatedBy(x: offset.width, y: offset.height)
                let inverseTransform = transform.inverted()
                // Removed unused endPos
                
                if dragDistance < AppConstants.tapThreshold {
                    // Tap: Select/deselect
                    let touchPos = value.startLocation.applying(inverseTransform)
                    if let hitNode = viewModel.model.nodes.first(where: { distance($0.position, touchPos) < AppConstants.hitScreenRadius / zoomScale }) {
                        if let index = viewModel.model.nodes.firstIndex(where: { $0.id == hitNode.id }) {
                            viewModel.snapshot()
                            viewModel.model.nodes[index] = hitNode.handlingTap()
                            viewModel.model.startSimulation()
                        }
                        selectedNodeID = (selectedNodeID == hitNode.id) ? nil : hitNode.id
                        selectedEdgeID = nil
                        WKInterfaceDevice.current().play(.click)
                    } else if let hitEdge = viewModel.model.edges.first(where: { edge in
                        if let from = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                           let to = viewModel.model.nodes.first(where: { $0.id == edge.to }),
                           pointToLineDistance(point: touchPos, from: from.position, to: to.position) < AppConstants.hitScreenRadius / zoomScale {
                            return true
                        }
                        return false
                    }) {
                        selectedEdgeID = (selectedEdgeID == hitEdge.id) ? nil : hitEdge.id
                        selectedNodeID = nil
                        WKInterfaceDevice.current().play(.click)
                    } else {
                        selectedNodeID = nil
                        selectedEdgeID = nil
                    }
                } else {
                    // Drag: Create edge or move
                    viewModel.snapshot()
                    if let startNode = dragStartNode, let target = potentialEdgeTarget, target.id != startNode.id,
                       !viewModel.model.edges.contains(where: { $0.from == startNode.id && $0.to == target.id }) {
                        // Create edge
                        viewModel.model.edges.append(GraphEdge(from: startNode.id, to: target.id))
                        viewModel.model.startSimulation()
                        WKInterfaceDevice.current().play(.success)
                    } else if isMovingSelectedNode, let node = dragStartNode,
                              let index = viewModel.model.nodes.firstIndex(where: { $0.id == node.id }) {
                        // Move selected node
                        var updatedNode = viewModel.model.nodes[index]
                        updatedNode.position.x += value.translation.width / zoomScale
                        updatedNode.position.y += value.translation.height / zoomScale
                        viewModel.model.nodes[index] = updatedNode
                        viewModel.model.startSimulation()
                        WKInterfaceDevice.current().play(.success)
                    } else {
                        // Pan completed (offset already updated)
                    }
                }
                
                // Reset states
                dragStartNode = nil
                isMovingSelectedNode = false
                draggedNode = nil
                dragOffset = .zero
                potentialEdgeTarget = nil
                panStartOffset = nil
                onUpdateZoomRanges()
            }
        
        let longPressGesture = LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                showMenu = true
                WKInterfaceDevice.current().play(.click)
            }
        
        content
            .gesture(dragGesture)
            .highPriorityGesture(longPressGesture)
    }
    
    private func pointToLineDistance(point: CGPoint, from: CGPoint, to: CGPoint) -> CGFloat {
        let lineVec = to - from
        let pointVec = point - from
        let lineLen = lineVec.magnitude
        if lineLen == 0 { return distance(point, from) }
        let t = max(0, min(1, (pointVec.x * lineVec.x + pointVec.y * lineVec.y) / (lineLen * lineLen)))
        let projection = from + lineVec * t
        return distance(point, projection)
    }
}
