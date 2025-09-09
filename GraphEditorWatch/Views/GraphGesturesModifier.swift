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
    
    private func screenToModel(_ screenPos: CGPoint, zoomScale: CGFloat, offset: CGSize, viewSize: CGSize, effectiveCentroid: CGPoint) -> CGPoint {
        let safeZoom = max(zoomScale, 0.1)
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let translated = screenPos - viewCenter - CGPoint(x: offset.width, y: offset.height)
        let unscaled = CGPoint(x: translated.x / safeZoom, y: translated.y / safeZoom)
        return unscaled + effectiveCentroid
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
        // Log sorted by distance
        edgeDistances.sort { $0.dist < $1.dist }
        logger.debug("Edge Hit Test at screen \(String(describing: screenPos))")
        for (id, dist) in edgeDistances.prefix(3) {
            logger.debug("Edge \(id): dist \(dist)")
        }
        if let closest = closestEdge {
            logger.debug("Hit: Edge \(closest.id) (dist \(minScreenDist) <= \(hitScreenRadius))")
        } else {
            logger.debug("Miss: Closest dist \(edgeDistances.first?.dist ?? .infinity) > \(hitScreenRadius)")
        }
#endif
        
        return closestEdge
    }
        
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)  // Zero for immediate detection
            .onChanged { value in
                let location = value.location
                let translation = value.translation
                let dragMagnitude = hypot(translation.width, translation.height)

                let visibleNodes = viewModel.model.visibleNodes()  // Or viewModel.model.nodes if no visibleNodes()
                let effectiveCentroid = viewModel.effectiveCentroid  // From ViewModel

                // Initial hit if no dragStartNode (start of drag)
                if dragStartNode == nil {
                    let hitNode = hitTestNodesInScreenSpace(at: location, visibleNodes: visibleNodes, zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: effectiveCentroid)
                    if let node = hitNode {
                        dragStartNode = node
                        draggedNode = node
                        dragOffset = .zero
                        isAddingEdge = true  // Enter edge creation mode
                        logger.debug("Drag of \(dragMagnitude) started from Node \(node.label)")
                    } else {
                        // Pan the canvas instead
                        if panStartOffset == nil {
                            panStartOffset = offset
                        }
                        let delta = CGSize(width: translation.width, height: translation.height)
                        offset = panStartOffset! + delta
                    }
                    startLocation = location  // For tap threshold in onEnded
                    gestureStartCentroid = effectiveCentroid
                    return
                }

                // Ongoing drag: Update drag offset and check for potential target
                if let node = draggedNode {
                    dragOffset = CGPoint(x: translation.width / zoomScale, y: translation.height / zoomScale)
                    let potential = hitTestNodesInScreenSpace(at: location, visibleNodes: visibleNodes, zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: effectiveCentroid)
                    potentialEdgeTarget = (potential?.id != node.id) ? potential : nil  // Avoid self-edges
                    if let target = potentialEdgeTarget {
                        logger.debug("Potential edge target: Node \(target.label)")
                    }
                }
            }
            .onEnded { value in
                let location = value.location  // Ensure scope
                let translation = value.translation
                let dragMagnitude = hypot(translation.width, translation.height)
                
                // Defer cleanup (ensures reset even on errors/taps)
                defer {
                    dragStartNode = nil
                    isMovingSelectedNode = false
                    draggedNode = nil
                    dragOffset = .zero
                    potentialEdgeTarget = nil
                    panStartOffset = nil
                    startLocation = nil
                    isAddingEdge = false
                    onUpdateZoomRanges()
                    gestureStartCentroid = .zero
                }
                
                // Early exit for taps (short drag) - fixed scope
                if let start = startLocation, dragMagnitude < dragStartThreshold, distance(start, location) < dragStartThreshold {
                    let tapScreenPos = location  // Now defined here, in scope for all uses below
                #if DEBUG
                    let visibleNodes = viewModel.model.visibleNodes()  // Replace with viewModel.model.nodes if needed
                    let effectiveCentroid = viewModel.effectiveCentroid
                    logger.debug("Hit Test Diagnostics: Tap at screen \(String(describing: tapScreenPos))")
                    logger.debug("Visible Nodes Count: \(visibleNodes.count)")
                    logger.debug("--------------------------------")
                #endif
                    let modelPos = screenToModel(tapScreenPos, zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: effectiveCentroid)
                    Task { await viewModel.handleTap(at: modelPos) }
                    // Quick reset for tap (defer handles full cleanup)
                    draggedNode = nil
                    potentialEdgeTarget = nil
                    isAddingEdge = false
                    dragStartNode = nil
                    return  // Exit early
                }
                
                print("Processing as drag: magnitude \(dragMagnitude), translation \(translation)")
                
                if let dragged = draggedNode {
                    Task { await viewModel.snapshot() }
                    let modelDragOffset = CGPoint(x: translation.width / zoomScale, y: translation.height / zoomScale)  // Define here for full scope
                    print("Drag offset in model: \(modelDragOffset)")
                    
                    if let target = potentialEdgeTarget, target.id != dragged.id, isAddingEdge {
                        // Duplicate check with logging
                        let exists = viewModel.model.edges.contains { edge in
                            (edge.from == dragged.id && edge.to == target.id) || (edge.from == target.id && edge.to == dragged.id)
                        }
                        if !exists {
                            print("No duplicate; adding edge")
                            // Heuristic: Downward = hierarchy
                            let type = (translation.height > 0) ? .hierarchy : viewModel.pendingEdgeType
                            viewModel.pendingEdgeType = type  // Update for UI
                            Task {
                                await viewModel.addEdge(from: dragged.id, to: target.id, type: type)  // Async call
                            }
                            print("Created edge of type \(type.rawValue) from node \(dragged.label) to \(target.label)")
                            isAddingEdge = false
                        } else {
                            print("Duplicate edge ignored between \(dragged.label) and \(target.label)")
                        }
                    } else {
                        // No target: Move the node (now properly in 'dragged' scope, protocol-safe)
                        if let index = viewModel.model.nodes.firstIndex(where: { $0.id == dragged.id }) {
                            let oldNode = viewModel.model.nodes[index]
                            let newPos = oldNode.position + modelDragOffset  // Uses local offset
                            let updatedNode = oldNode.with(position: newPos, velocity: .zero)
                            viewModel.model.nodes[index] = updatedNode
                            print("Moved node \(oldNode.label) to new position \(newPos)")
                            Task { await viewModel.model.startSimulation() }
                        }
                    }
                }  // Explicit closing brace for 'if let dragged' scope
                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                    onUpdateZoomRanges()
                }
            }
        content
            .highPriorityGesture(dragGesture)
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
