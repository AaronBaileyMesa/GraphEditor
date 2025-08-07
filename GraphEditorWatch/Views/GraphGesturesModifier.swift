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
    @Binding var selectedEdgeID: UUID?  // New: Binding for edge selection
    let viewSize: CGSize
    @Binding var panStartOffset: CGSize?
    @Binding var showMenu: Bool
    let maxZoom: CGFloat
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0)
            .onChanged { value in
                if panStartOffset == nil {
                    panStartOffset = offset
                }
                offset = CGSize(width: panStartOffset!.width + value.translation.width, height: panStartOffset!.height + value.translation.height)
            }
            .onEnded { value in
                let dragDistance = hypot(value.translation.width, value.translation.height)
                if dragDistance < AppConstants.tapThreshold {
                    let preOffset = panStartOffset ?? offset
                    let transform = CGAffineTransform(scaleX: zoomScale, y: zoomScale).translatedBy(x: preOffset.width, y: preOffset.height)
                    let inverseTransform = transform.inverted()
                    let touchPos = value.startLocation.applying(inverseTransform)
                    
                    // Node hit check first
                    if let hitNode = viewModel.model.nodes.first(where: { distance($0.position, touchPos) < AppConstants.hitScreenRadius / zoomScale }) {
                        if hitNode.isExpanded != true {  // Or check if type is ToggleNode, but polymorphic
                            // Toggle via protocol method
                            if let index = viewModel.model.nodes.firstIndex(where: { $0.id == hitNode.id }) {
                                viewModel.snapshot()
                                viewModel.model.nodes[index] = hitNode.handlingTap()  // Calls toggle if ToggleNode
                                viewModel.model.startSimulation()
                            }
                        }
                        selectedNodeID = (selectedNodeID == hitNode.id) ? nil : hitNode.id
                        selectedEdgeID = nil
                        WKInterfaceDevice.current().play(.click)
                    } else {
                        // Edge hit check if no node
                        var hitEdge: GraphEdge? = nil
                        for edge in viewModel.model.edges {
                            if let from = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                               let to = viewModel.model.nodes.first(where: { $0.id == edge.to }),
                               pointToLineDistance(point: touchPos, from: from.position, to: to.position) < AppConstants.hitScreenRadius / zoomScale {
                                hitEdge = edge
                                break
                            }
                        }
                        if let hitEdge = hitEdge {
                            selectedEdgeID = (selectedEdgeID == hitEdge.id) ? nil : hitEdge.id
                            selectedNodeID = nil  // Clear node selection
                            WKInterfaceDevice.current().play(.click)
                        } else {
                            selectedNodeID = nil
                            selectedEdgeID = nil
                        }
                    }
                    
                    // Reset offset only if panStartOffset was set
                    if panStartOffset != nil {
                        offset = preOffset
                    }
                } else {
                    // True pan, no action
                }
                panStartOffset = nil
            }
        
        let longPressDragGesture = LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .second(true, let drag?):
                    let transform = CGAffineTransform(scaleX: zoomScale, y: zoomScale).translatedBy(x: offset.width, y: offset.height)
                    let inverseTransform = transform.inverted()
                    if draggedNode == nil {
                        let startPos = drag.startLocation.applying(inverseTransform)
                        if let hitNode = viewModel.model.nodes.first(where: { distance($0.position, startPos) < AppConstants.hitScreenRadius / zoomScale }) {
                            draggedNode = hitNode
                            WKInterfaceDevice.current().play(.click)  // Feedback for grab
                        }
                    }
                    if let dragged = draggedNode {
                        dragOffset = CGPoint(x: drag.translation.width / zoomScale, y: drag.translation.height / zoomScale)
                        let currentPos = drag.location.applying(inverseTransform)
                        potentialEdgeTarget = viewModel.model.nodes.first {
                            $0.id != dragged.id && distance($0.position, currentPos) < AppConstants.hitScreenRadius / zoomScale
                        }
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let drag?):
                    if let node = draggedNode {
                        let dragDistance = hypot(drag.translation.width, drag.translation.height)
                        viewModel.snapshot()
                        if dragDistance > AppConstants.tapThreshold {
                            // Move or create edge
                            if let target = potentialEdgeTarget, target.id != node.id,
                               !viewModel.model.edges.contains(where: { $0.from == node.id && $0.to == target.id }) {
                                viewModel.model.edges.append(GraphEdge(from: node.id, to: target.id))
                                viewModel.model.startSimulation()
                                WKInterfaceDevice.current().play(.success)
                            } else {
                                if let index = viewModel.model.nodes.firstIndex(where: { $0.id == node.id }) {
                                    var updatedNode = viewModel.model.nodes[index]
                                    updatedNode.position.x += dragOffset.x
                                    updatedNode.position.y += dragOffset.y
                                    viewModel.model.nodes[index] = updatedNode
                                    viewModel.model.startSimulation()
                                }
                            }
                        } else {
                            // Delete node (no significant drag)
                            viewModel.deleteNode(withID: node.id)
                            viewModel.model.startSimulation()
                            WKInterfaceDevice.current().play(.success)
                        }
                    } else {
                        // No node hit: Check for edge delete (only if it matches selectedEdgeID)
                        let transform = CGAffineTransform(scaleX: zoomScale, y: zoomScale).translatedBy(x: offset.width, y: offset.height)
                        let inverseTransform = transform.inverted()
                        let startPos = drag.startLocation.applying(inverseTransform)
                        for edge in viewModel.model.edges {
                            if let from = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                               let to = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                                if edge.id == selectedEdgeID &&  // Add this check for selection consistency
                                   pointToLineDistance(point: startPos, from: from.position, to: to.position) < AppConstants.hitScreenRadius / zoomScale {
                                    viewModel.deleteSelectedEdge(id: edge.id)  // Updated: Call via ViewModel
                                    selectedEdgeID = nil  // Clear selection
                                    viewModel.model.startSimulation()
                                    WKInterfaceDevice.current().play(.success)
                                    break
                                }
                            }
                        }
                    }
                default:
                    break
                }
                draggedNode = nil
                dragOffset = .zero
                potentialEdgeTarget = nil
                onUpdateZoomRanges()
            }
        
        let doubleTapGesture = TapGesture(count: 2)
            .onEnded {
                showMenu = true
            }
        
        content
            .gesture(dragGesture)
            .highPriorityGesture(longPressDragGesture)
            .gesture(doubleTapGesture)
    }
    
    // Helper function (keep as in original)
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
