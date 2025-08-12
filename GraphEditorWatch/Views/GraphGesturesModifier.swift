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
    
    // New: Helper to convert screen coords to model coords (full inverse transform)
    private func screenToModel(_ screenPos: CGPoint) -> CGPoint {
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let panOffset = CGPoint(x: offset.width, y: offset.height)
        
        let visibleNodes = viewModel.model.visibleNodes()
        var effectiveCentroid = visibleNodes.centroid() ?? .zero
        if let selectedID = selectedNodeID, let selected = visibleNodes.first(where: { $0.id == selectedID }) {
            effectiveCentroid = selected.position
        } else if let selectedEdgeID = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdgeID }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }), let to = visibleNodes.first(where: { $0.id == edge.to }) {
            effectiveCentroid = (from.position + to.position) / 2
        }
        
        let translated = screenPos - viewCenter - panOffset
        let unscaled = CGPoint(x: translated.x / zoomScale, y: translated.y / zoomScale)
        return unscaled + effectiveCentroid
    }
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0)
            .onChanged { value in
                // After handling, clamp with smooth animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {  // Damped spring for "soft" return
                        onUpdateZoomRanges()  // This calls clampOffset()
                    }
                let touchPos = screenToModel(value.location)  // Updated: Use full inverse
                
                if dragStartNode == nil {
                    let startModelPos = screenToModel(value.startLocation)  // Updated: Use full inverse for initial hit
                    if let hitNode = viewModel.model.nodes.first(where: { distance($0.position, startModelPos) < Constants.App.hitScreenRadius / zoomScale }) {
                        dragStartNode = hitNode
                        isMovingSelectedNode = (hitNode.id == selectedNodeID)
                    }
                }
                
                if isMovingSelectedNode, let node = dragStartNode {
                    dragOffset = CGPoint(x: value.translation.width / zoomScale, y: value.translation.height / zoomScale)
                    draggedNode = node
                } else {
                    if panStartOffset == nil {
                        panStartOffset = offset
                    }
                    // Free update—no clamp here!
                    offset = CGSize(width: panStartOffset!.width + value.translation.width,
                                    height: panStartOffset!.height + value.translation.height)
                }
                
                potentialEdgeTarget = viewModel.model.nodes.first {
                    dragStartNode?.id != $0.id && distance($0.position, touchPos) < Constants.App.hitScreenRadius / zoomScale
                }
            }
            .onEnded { value in
                viewModel.resumeSimulation()
                
                let dragDistance = hypot(value.translation.width, value.translation.height)
                
                if dragDistance < Constants.App.tapThreshold {
                    let tapModelPos = screenToModel(value.startLocation)  // Updated: Use full inverse for tap
                    if let hitNode = viewModel.model.nodes.first(where: { distance($0.position, tapModelPos) < Constants.App.hitScreenRadius / zoomScale }) {
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
                           pointToLineDistance(point: tapModelPos, from: from.position, to: to.position) < Constants.App.hitScreenRadius / zoomScale {  // Updated: Use tapModelPos
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
                    viewModel.snapshot()
                    if let startNode = dragStartNode, let target = potentialEdgeTarget, target.id != startNode.id,
                       !viewModel.model.edges.contains(where: { $0.from == startNode.id && $0.to == target.id }) {
                        viewModel.model.edges.append(GraphEdge(from: startNode.id, to: target.id))
                        viewModel.model.startSimulation()
#if os(watchOS)
                        WKInterfaceDevice.current().play(.success)  // Haptic on edge creation
#endif
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
                
                // After handling, clamp with smooth animation
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {  // Damped spring for "soft" return
                    onUpdateZoomRanges()  // This calls clampOffset()
                }
                
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
    
    // Existing pointToLineDistance and distance functions (ensure they're defined or imported)
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        hypot(p1.x - p2.x, p1.y - p2.y)
    }
    
    private func pointToLineDistance(point: CGPoint, from: CGPoint, to: CGPoint) -> CGFloat {
        let lineVec = to - from
        let pointVec = point - from
        let lineLen = hypot(lineVec.x, lineVec.y)
        if lineLen == 0 { return distance(point, from) }
        let t = max(0, min(1, (pointVec.x * lineVec.x + pointVec.y * lineVec.y) / (lineLen * lineLen)))
        let projection = from + CGPoint(x: lineVec.x * t, y: lineVec.y * t)
        return distance(point, projection)
    }
}
