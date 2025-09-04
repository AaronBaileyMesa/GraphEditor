//
//  GraphGesturesModifier.swift
//  GraphEditorWatch
//
//  Created by handcart on 2025-08-16

import SwiftUI
import WatchKit
import GraphEditorShared
import os.log  // Added for optimized logging

enum HitType {
    case node
    case edge
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
    
    @State private var dragStartNode: (any NodeProtocol)? = nil
    @State private var isMovingSelectedNode: Bool = false
    @State private var gestureStartCentroid: CGPoint = .zero
    @State private var startLocation: CGPoint? = nil  // Tracks touch-down location for tap detection
    
    private let dragStartThreshold: CGFloat = 10.0  // Increased for better tap vs. drag distinction
    
    // Optimized logger
    private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "gestures")
    
    // New helper: Model to screen conversion (inverse of screenToModel; use your existing if available)
    private func modelToScreen(_ modelPos: CGPoint, zoomScale: CGFloat, offset: CGSize, viewSize: CGSize, effectiveCentroid: CGPoint) -> CGPoint {
        let safeZoom = max(zoomScale, 0.1)
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let panOffset = CGPoint(x: offset.width, y: offset.height)
        let relative = modelPos - effectiveCentroid
        let scaled = relative * safeZoom
        let screenPos = scaled + viewCenter + panOffset
        return screenPos
    }
    
    // New: Screen-space hit test for nodes (consistent usability)
    private func hitTestNodesInScreenSpace(at screenPos: CGPoint, visibleNodes: [any NodeProtocol], zoomScale: CGFloat, offset: CGSize, viewSize: CGSize, effectiveCentroid: CGPoint) -> (any NodeProtocol)? {
        var closestNode: (any NodeProtocol)? = nil
        var minScreenDist: CGFloat = .infinity
        let hitScreenRadius: CGFloat = Constants.App.hitScreenRadius  // Fixed screen size (e.g., 50pt)
        
#if DEBUG
        var nodeDistances: [(label: Int, screenPos: CGPoint, dist: CGFloat)] = []  // For logging
        logger.debug("Using centroid: \(String(describing: effectiveCentroid)) for this gesture")
#endif
        
        for node in visibleNodes {
            let nodeScreenPos = modelToScreen(node.position, zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: effectiveCentroid)
            let dist = hypot(screenPos.x - nodeScreenPos.x, screenPos.y - nodeScreenPos.y)
            
#if DEBUG
            nodeDistances.append((node.label, nodeScreenPos, dist))
#endif
            
            if dist < minScreenDist && dist <= hitScreenRadius {
                minScreenDist = dist
                closestNode = node
            }
        }
        
#if DEBUG
        // Log sorted by distance for verification
        nodeDistances.sort { $0.dist < $1.dist }
        logger.debug("Hit Test Diagnostics: Tap at screen \(String(describing: screenPos))")
        for (label, pos, dist) in nodeDistances.prefix(5) {  // Limit to top 5 closest
            logger.debug("Node \(label): screen pos \(String(describing: pos)), dist \(dist)")
        }
        if let closest = closestNode {
            logger.debug("Hit: Node \(closest.label) (dist \(minScreenDist) <= \(hitScreenRadius))")
        } else {
            logger.debug("Miss: Closest dist \(nodeDistances.first?.dist ?? .infinity) > \(hitScreenRadius)")
        }
#endif
        
        return closestNode
    }
    
    // New: Screen-space hit test for edges (for consistency with nodes)
    private func hitTestEdgesInScreenSpace(at screenPos: CGPoint, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], zoomScale: CGFloat, offset: CGSize, viewSize: CGSize, effectiveCentroid: CGPoint) -> GraphEdge? {
        var closestEdge: GraphEdge? = nil
        var minScreenDist: CGFloat = .infinity
        let hitScreenRadius: CGFloat = Constants.App.hitScreenRadius / 2  // Smaller for edges to avoid overlapping node taps
        
#if DEBUG
        var edgeDistances: [(id: UUID, dist: CGFloat)] = []  // For logging
#endif
        
        for edge in visibleEdges {
            guard let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                  let toNode = visibleNodes.first(where: { $0.id == edge.to }) else { continue }
            
            let fromScreen = modelToScreen(fromNode.position, zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: effectiveCentroid)
            let toScreen = modelToScreen(toNode.position, zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: effectiveCentroid)
            
            let dist = pointToLineDistance(point: screenPos, from: fromScreen, to: toScreen)
            
#if DEBUG
            edgeDistances.append((edge.id, dist))
#endif
            
            if dist < minScreenDist && dist <= hitScreenRadius {
                minScreenDist = dist
                closestEdge = edge
            }
        }
        
#if DEBUG
        edgeDistances.sort { $0.dist < $1.dist }
        logger.debug("Edge Hit Test: Top distances \(edgeDistances.prefix(5).map { "\($0.id): \($0.dist)" }.joined(separator: ", "))")
        if let closest = closestEdge {
            logger.debug("Hit: Edge \(closest.id) (dist \(minScreenDist) <= \(hitScreenRadius))")
        }
#endif
        
        return closestEdge
    }
    
    private func hitTest(at modelPos: CGPoint, type: HitType) -> Any? {
        let minDist = viewModel.model.visibleNodes().map { distance($0.position, modelPos) }.min() ?? 0
        print("Tap at \(modelPos); closest node dist: \(minDist)")
        
        let modelHitRadius = Constants.App.hitScreenRadius / zoomScale * 2.0
        switch type {
        case .node:
            return viewModel.model.visibleNodes().first { distance($0.position, modelPos) < modelHitRadius }
        case .edge:
            return viewModel.model.visibleEdges().first { edge in
                guard let from = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                      let to = viewModel.model.nodes.first(where: { $0.id == edge.to }) else { return false }
                let dist = pointToLineDistance(point: modelPos, from: from.position, to: to.position)
                return dist < modelHitRadius / 2  // Smaller for edges
            }
        }
    }
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)  // Changed: 0 for immediate trigger on touch-down
            .onChanged { value in
                let translation = value.translation
                let dragMagnitude = hypot(translation.width, translation.height)
                
                // Lock centroid once at gesture start (if not set)
                if gestureStartCentroid == .zero {
                    gestureStartCentroid = viewModel.effectiveCentroid
                }
                
                // New: On initial touch-down (small magnitude), record start for tap detection
                if startLocation == nil && dragMagnitude < 1.0 {  // Tiny threshold for true touch-down
                    startLocation = value.startLocation
                    print("Touch-down detected at screen: \(value.startLocation)")  // Console info
                    return  // Wait for more movement or end
                }
                
                // Handle small drags as potential taps (suppress action until .onEnded)
                if dragMagnitude < dragStartThreshold {
                    return  // Changed: No early return that skips taps; just defer action
                }
                
                // Existing drag logic (unchanged)
                if let dragged = draggedNode {
                    dragOffset = CGPoint(x: translation.width / zoomScale, y: translation.height / zoomScale)
                    
                    if isAddingEdge {
                        let targetPos = dragged.position + dragOffset
                        potentialEdgeTarget = viewModel.model.visibleNodes().first {
                            $0.id != dragged.id && distance($0.position, targetPos) < Constants.App.hitScreenRadius
                        }
                    }
                } else if let selectedID = selectedNodeID, dragStartNode == nil {
                    if let node = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
                        dragStartNode = node
                        draggedNode = node
                        isMovingSelectedNode = true
                    }
                } else if panStartOffset == nil {
                    panStartOffset = offset
                }
                
                if let startOffset = panStartOffset {
                    offset = CGSize(
                        width: startOffset.width + translation.width,
                        height: startOffset.height + translation.height
                    )
                }
            }
            .onEnded { value in
                let translation = value.translation
                let dragMagnitude = hypot(translation.width, translation.height)
                
                let visibleNodes = viewModel.model.visibleNodes()
                let visibleEdges = viewModel.model.visibleEdges()
                
                // Handle as tap if below threshold (using startLocation for accurate position)
                if let tapScreenPos = startLocation, dragMagnitude < dragStartThreshold {
                    print("Processing as tap at screen: \(tapScreenPos)")  // Console info
                    
                    // Node hit test
                    if let hitNode = hitTestNodesInScreenSpace(at: tapScreenPos, visibleNodes: visibleNodes, zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: gestureStartCentroid) {
                        print("Tapped node: \(hitNode.label) at model position \(hitNode.position)")  // Console info as requested
                        if let currentNodeID = selectedNodeID {
                            if currentNodeID == hitNode.id {
                                selectedNodeID = nil  // Deselect if already selected
                            } else {
                                selectedNodeID = hitNode.id  // Select new
                                selectedEdgeID = nil
                            }
                        } else {
                            selectedNodeID = hitNode.id  // Select if none
                            selectedEdgeID = nil
                        }
                        // Removed: WKInterfaceDevice.current().play(.success)  // No haptics on select
                    } else {
                        // Edge hit test
                        if let hitEdge = hitTestEdgesInScreenSpace(at: tapScreenPos, visibleEdges: visibleEdges, visibleNodes: visibleNodes, zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: gestureStartCentroid) {
                            print("Tapped edge: from \(hitEdge.from.uuidString) to \(hitEdge.to.uuidString)")  // Console info
                            if let currentEdgeID = selectedEdgeID {
                                if currentEdgeID == hitEdge.id {
                                    selectedEdgeID = nil
                                } else {
                                    selectedEdgeID = hitEdge.id
                                    selectedNodeID = nil
                                }
                            } else {
                                selectedEdgeID = hitEdge.id
                                selectedNodeID = nil
                            }
                            // Removed: WKInterfaceDevice.current().play(.success)  // No haptics
                        } else {
                            // Miss: Deselect all
                            print("Tapped empty space at screen: \(tapScreenPos)")  // Console info
                            selectedNodeID = nil
                            selectedEdgeID = nil
                            // Removed: WKInterfaceDevice.current().play(.failure)  // Optional; remove if no feedback wanted on miss
                        }
                    }

                    // Existing diagnostic logs (kept; they use logger.debug)
                    #if DEBUG
                    let effectiveCentroid = viewModel.effectiveCentroid
                    let translated = CGPoint(x: tapScreenPos.x - viewSize.width / 2 - offset.width, y: tapScreenPos.y - viewSize.height / 2 - offset.height)
                    let unscaled = CGPoint(x: translated.x / zoomScale, y: translated.y / zoomScale)
                    let tapModelPos = unscaled + effectiveCentroid
                    logger.debug("--- Tap (.onEnded) Diagnostic ---")
                    logger.debug("Effective Centroid: \(String(describing: effectiveCentroid))")
                    logger.debug("Screen Pos: \(String(describing: tapScreenPos))")
                    logger.debug("Translated: \(String(describing: translated))")
                    logger.debug("Unscaled: \(String(describing: unscaled))")
                    logger.debug("Model Pos (tapModelPos): \(String(describing: tapModelPos))")
                    logger.debug("Visible Nodes Count: \(visibleNodes.count)")
                    logger.debug("--------------------------------")
                    #endif

                    Task { await viewModel.handleTap() }  // Kept: If this pauses simulation, etc.
                } else {
                    // Your existing non-tap logic (unchanged)
                    // ...
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
                startLocation = nil  // New: Reset for next gesture
                onUpdateZoomRanges()
                
                // Reset gesture centroid for next gesture
                gestureStartCentroid = .zero
            }

        content
            .highPriorityGesture(dragGesture)  // Kept as-is
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
        // Fixed: Explicit CGFloat literals to resolve type inference and conformance error
        let t = max(CGFloat(0), min(CGFloat(1), tUnclamped))
        let projection = from + (lineVec * t)
        return hypot(point.x - projection.x, point.y - projection.y)
    }
}
