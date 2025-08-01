//
//  GraphGesturesModifier.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Views/GraphGesturesModifier.swift
import SwiftUI
import WatchKit

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
    let hitScreenRadius: CGFloat
    let tapThreshold: CGFloat
    let maxZoom: CGFloat
    let numZoomLevels: Int
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    
    func body(content: Content) -> some View {
        content
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                        .scaledBy(x: zoomScale, y: zoomScale)
                        .inverted()
                    if draggedNode == nil {
                        let touchPos = value.startLocation.applying(inverseTransform)
                        if let hitNode = viewModel.model.nodes.first(where: { hypot($0.position.x - touchPos.x, $0.position.y - touchPos.y) < hitScreenRadius / zoomScale }) {
                            draggedNode = hitNode
                        }
                    }
                    if let dragged = draggedNode {
                        dragOffset = CGPoint(x: value.translation.width / zoomScale, y: value.translation.height / zoomScale)
                        let currentPos = value.location.applying(inverseTransform)
                        potentialEdgeTarget = viewModel.model.nodes.first {
                            $0.id != dragged.id && hypot($0.position.x - currentPos.x, $0.position.y - currentPos.y) < hitScreenRadius / zoomScale
                        }
                    }
                }
                .onEnded { value in
                    let dragDistance = hypot(value.translation.width, value.translation.height)
                    if let node = draggedNode,
                       let index = viewModel.model.nodes.firstIndex(where: { $0.id == node.id }) {
                        viewModel.snapshot()
                        if dragDistance < tapThreshold {
                            if selectedNodeID == node.id {
                                selectedNodeID = nil
                            } else {
                                selectedNodeID = node.id
                                WKInterfaceDevice.current().play(.click)
                                if zoomScale < maxZoom * 0.8 {
                                    crownPosition = Double(numZoomLevels - 1)
                                }
                                let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                                let worldPoint = node.position
                                offset = CGSize(width: viewCenter.x - worldPoint.x * zoomScale, height: viewCenter.y - worldPoint.y * zoomScale)
                            }
                        } else {
                            if let target = potentialEdgeTarget, target.id != node.id,
                               !viewModel.model.edges.contains(where: { ($0.from == node.id && $0.to == target.id) || ($0.from == target.id && $0.to == node.id) }) {
                                viewModel.model.edges.append(Edge(from: node.id, to: target.id))
                                viewModel.model.startSimulation()
                            } else {
                                var updatedNode = viewModel.model.nodes[index]
                                updatedNode.position = CGPoint(x: updatedNode.position.x + dragOffset.x, y: updatedNode.position.y + dragOffset.y)
                                viewModel.model.nodes[index] = updatedNode
                                viewModel.model.startSimulation()
                            }
                        }
                    } else {
                        if dragDistance < tapThreshold {
                            selectedNodeID = nil
                            viewModel.snapshot()
                            let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                                .scaledBy(x: zoomScale, y: zoomScale)
                                .inverted()
                            let touchPos = value.location.applying(inverseTransform)
                            viewModel.model.addNode(at: touchPos)
                            viewModel.model.startSimulation()
                        }
                    }
                    onUpdateZoomRanges()
                    draggedNode = nil
                    dragOffset = .zero
                    potentialEdgeTarget = nil
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
                        
                        // Check for node hit
                        if let hitNode = viewModel.model.nodes.first(where: { hypot($0.position.x - worldPos.x, $0.position.y - worldPos.y) < hitScreenRadius / zoomScale }) {
                            viewModel.deleteNode(withID: hitNode.id)
                            WKInterfaceDevice.current().play(.success)
                            viewModel.model.startSimulation()
                            return
                        }
                        
                        // Check for edge hit (near midpoint)
                        for edge in viewModel.model.edges {
                            if let from = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                               let to = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                                let midX = (from.position.x + to.position.x)/2
                                let midY = (from.position.y + to.position.y)/2
                                if hypot(midX - worldPos.x, midY - worldPos.y) < hitScreenRadius / zoomScale {
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
}