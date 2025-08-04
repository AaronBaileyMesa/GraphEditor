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
    @Binding var draggedNode: Node?
    @Binding var dragOffset: CGPoint
    @Binding var potentialEdgeTarget: Node?
    @Binding var selectedNodeID: NodeID?
    let viewSize: CGSize
    @Binding var panStartOffset: CGSize?
    @Binding var showMenu: Bool
    let maxZoom: CGFloat
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    
    func body(content: Content) -> some View {
        content
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                        .scaledBy(x: zoomScale, y: zoomScale)
                        .inverted()
                    let touchPos = value.startLocation.applying(inverseTransform)
                    
                    if draggedNode == nil {
                        // Check for node hit to prioritize drag/selection
                        if let hitNode = viewModel.model.nodes.first(where: { hypot($0.position.x - touchPos.x, $0.position.y - touchPos.y) < AppConstants.hitScreenRadius / zoomScale }) {
                            draggedNode = hitNode
                        }
                    }
                    
                    if let dragged = draggedNode {
                        // Handle ongoing drag (for potential edge or move)
                        dragOffset = CGPoint(x: value.translation.width / zoomScale, y: value.translation.height / zoomScale)
                        let currentPos = value.location.applying(inverseTransform)
                        potentialEdgeTarget = viewModel.model.nodes.first {
                            $0.id != dragged.id && hypot($0.position.x - currentPos.x, $0.position.y - currentPos.y) < AppConstants.hitScreenRadius / zoomScale
                        }
                    }
                }
                .onEnded { value in
                    let dragDistance = hypot(value.translation.width, value.translation.height)
                    let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                        .scaledBy(x: zoomScale, y: zoomScale)
                        .inverted()
                    let touchPos = value.location.applying(inverseTransform)
                    
                    if let node = draggedNode,
                       let index = viewModel.model.nodes.firstIndex(where: { $0.id == node.id }) {
                        viewModel.snapshot()
                        if dragDistance < AppConstants.tapThreshold {
                            // Handle tap on node: Toggle selection
                            if selectedNodeID == node.id {
                                selectedNodeID = nil
                            } else {
                                selectedNodeID = node.id
                            }
                            WKInterfaceDevice.current().play(.click)  // Haptic feedback for selection
                        } else {
                            // Handle actual drag: Move node or create edge
                            if let target = potentialEdgeTarget, target.id != node.id,
                               !viewModel.model.edges.contains(where: { ($0.from == node.id && $0.to == target.id) || ($0.from == target.id && $0.to == node.id) }) {
                                viewModel.model.edges.append(GraphEdge(from: node.id, to: target.id))
                                viewModel.model.startSimulation()
                                WKInterfaceDevice.current().play(.success)
                            } else {
                                var updatedNode = viewModel.model.nodes[index]
                                updatedNode.position = CGPoint(x: updatedNode.position.x + dragOffset.x, y: updatedNode.position.y + dragOffset.y)
                                viewModel.model.nodes[index] = updatedNode
                                viewModel.model.startSimulation()
                            }
                        }
                    } else {
                        // No node dragged: Handle tap to add new node or pan (but pan is in simultaneous gesture)
                        if dragDistance < AppConstants.tapThreshold {
                            selectedNodeID = nil  // Deselect on background tap
                            viewModel.snapshot()
                            viewModel.model.addNode(at: touchPos)
                            viewModel.model.startSimulation()
                        }
                    }
                    
                    // Reset drag state
                    draggedNode = nil
                    dragOffset = .zero
                    potentialEdgeTarget = nil
                    onUpdateZoomRanges()
                }
            )
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if draggedNode == nil {
                        if panStartOffset == nil {
                            panStartOffset = offset
                        }
                        offset = CGSize(width: panStartOffset!.width + value.translation.width, height: panStartOffset!.height + value.translation.height)
                    }
                }
                .onEnded { _ in
                    panStartOffset = nil
                }
            )
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5)
                        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                        .onEnded { value in
                            switch value {
                            case .second(true, let drag?):
                                let location = drag.location
                                let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                                    .scaledBy(x: zoomScale, y: zoomScale)
                                    .inverted()
                                let worldPos = location.applying(inverseTransform)
                                
                                // Check for node hit (unchanged)
                                if let hitNode = viewModel.model.nodes.first(where: { hypot($0.position.x - worldPos.x, $0.position.y - worldPos.y) < AppConstants.hitScreenRadius / zoomScale }) {
                                    viewModel.deleteNode(withID: hitNode.id)
                                    WKInterfaceDevice.current().play(.success)
                                    viewModel.model.startSimulation()
                                    return
                                }
                                
                                // Check for edge hit (now using point-to-line distance)
                                for edge in viewModel.model.edges {
                                    if let from = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                                       let to = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                                        if pointToLineDistance(point: worldPos, from: from.position, to: to.position) < AppConstants.hitScreenRadius / zoomScale {
                                            viewModel.deleteEdge(withID: edge.id)
                                            WKInterfaceDevice.current().play(.success)
                                            viewModel.model.startSimulation()
                                            return
                                        }
                                    }
                                }
                            default:
                                break
                            }
                        }
                    )
            .simultaneousGesture(TapGesture(count: 2)
                .onEnded {
                    showMenu = true
                }
            )
    }
    
    // New helper function for point-to-line distance
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
