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

struct GestureContext {
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    let effectiveCentroid: CGPoint
}

struct NodeDistanceInfo {
    let label: Int
    let screenPos: CGPoint
    let dist: CGFloat
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
    
    @State private var dragStartNode: (any NodeProtocol)?
    @State private var isMovingSelectedNode: Bool = false
    @State private var gestureStartCentroid: CGPoint = .zero
    @State private var startLocation: CGPoint?
    
    private let dragStartThreshold: CGFloat = 10.0  // Increased for better tap vs. drag distinction
    
    // Optimized logger
    private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "gestures")
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)  // Zero for immediate detection
            .onChanged { value in
                let visibleNodes = viewModel.model.visibleNodes()  // Or viewModel.model.nodes if no visibleNodes()
                let effectiveCentroid = viewModel.effectiveCentroid  // From ViewModel
                let context = GestureContext(zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: effectiveCentroid)
                handleDragChanged(value: value, visibleNodes: visibleNodes, context: context)
            }
            .onEnded { value in
                let visibleNodes = viewModel.model.visibleNodes()
                let visibleEdges = viewModel.model.visibleEdges()  // NEW: Get visible edges (assume method exists; use model.edges if not)
                let effectiveCentroid = viewModel.effectiveCentroid
                let context = GestureContext(zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: effectiveCentroid)
                handleDragEnded(value: value, visibleNodes: visibleNodes, visibleEdges: visibleEdges, context: context)
            }
        content
            .highPriorityGesture(dragGesture)
    }
}

extension GraphGesturesModifier {
    
    /*
    // Screen-space hit test for nodes (consistent usability)
    func hitTestNodesInScreenSpace(at screenPos: CGPoint, visibleNodes: [any NodeProtocol], context: GestureContext) -> (any NodeProtocol)? {
        var closestNode: (any NodeProtocol)?
        var minScreenDist: CGFloat = .infinity
        let minHitRadius: CGFloat = 10.0  // Minimum tappable radius in screen points for small zooms
        let padding: CGFloat = 5.0  // Extra padding in screen points for forgiveness

    #if DEBUG
        var nodeDistances: [NodeDistanceInfo] = []  // For logging
        logger.debug("Using centroid: \(String(describing: context.effectiveCentroid)) for this gesture")
    #endif

        for node in visibleNodes {
            let safeZoom = max(context.zoomScale, 0.1)
            let nodeScreenPos = CoordinateTransformer.modelToScreen(node.position, effectiveCentroid: context.effectiveCentroid, zoomScale: safeZoom, offset: context.offset, viewSize: context.viewSize)
            let dist = distance(screenPos, nodeScreenPos)

            let visibleRadius = node.radius * safeZoom
            let nodeHitRadius = max(minHitRadius, visibleRadius) + padding  // Matches visible size, with min and padding

    #if DEBUG
            nodeDistances.append(NodeDistanceInfo(label: node.label, screenPos: nodeScreenPos, dist: dist))
            // Optional: Log per-node hit radius for debugging
            logger.debug("Node \(node.label): visibleRadius \(visibleRadius), nodeHitRadius \(nodeHitRadius)")
    #endif

            if dist <= nodeHitRadius && dist < minScreenDist {
                minScreenDist = dist
                closestNode = node
            }
        }

    #if DEBUG
        // Log sorted by distance for verification
        nodeDistances.sort { $0.dist < $1.dist }
        logger.debug("Hit Test Diagnostics: Tap at screen \(String(describing: screenPos))")
        for info in nodeDistances.prefix(5) {  // Limit to top 5 closest
            logger.debug("Node \(info.label): screen pos \(String(describing: info.screenPos)), dist \(info.dist)")
        }
        if let closest = closestNode {
            logger.debug("Hit: Node \(closest.label) (dist \(minScreenDist))")
        } else {
            logger.debug("Miss: Closest dist \(nodeDistances.first?.dist ?? .infinity)")
        }
    #endif
        return closestNode
    }
    
    // Screen-space hit test for edges (for consistency with nodes)
    func hitTestEdgesInScreenSpace(at screenPos: CGPoint, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], context: GestureContext) -> GraphEdge? {
        var closestEdge: GraphEdge?
        var minScreenDist: CGFloat = .infinity
        let hitScreenRadius: CGFloat = Constants.App.hitScreenRadius / 2  // Smaller for edges to avoid overlapping node taps
        
#if DEBUG
        var edgeDistances: [(id: UUID, dist: CGFloat)] = []  // For logging
#endif
        
        for edge in visibleEdges {
            guard let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                  let toNode = visibleNodes.first(where: { $0.id == edge.target }) else { continue }
            
            let safeZoom = max(context.zoomScale, 0.1)
            let fromScreen = CoordinateTransformer.modelToScreen(fromNode.position, effectiveCentroid: context.effectiveCentroid, zoomScale: safeZoom, offset: context.offset, viewSize: context.viewSize)
            let toScreen = CoordinateTransformer.modelToScreen(toNode.position, effectiveCentroid: context.effectiveCentroid, zoomScale: safeZoom, offset: context.offset, viewSize: context.viewSize)
            let dist = pointToLineDistance(point: screenPos, from: fromScreen, endPoint: toScreen)
            
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
    */
     
    private func resetGestureState() {
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
    
    func handleTap(at location: CGPoint, visibleNodes: [any NodeProtocol], visibleEdges: [GraphEdge], context: GestureContext) -> Bool {
    #if DEBUG
        logger.debug("Hit Test Diagnostics: Tap at screen \(String(describing: location))")
        logger.debug("Visible Nodes Count: \(visibleNodes.count)")
        logger.debug("--------------------------------")
    #endif
      
        // Pause simulation first (mimics handleTap)
        Task { await viewModel.model.pauseSimulation() }
      
        let hitContext = HitTestContext(zoomScale: context.zoomScale, offset: context.offset, viewSize: context.viewSize, effectiveCentroid: context.effectiveCentroid)
        let hitNode = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, context: hitContext)
        if let node = hitNode {
            // Node hit: Handle toggle or selection (replicates viewModel.handleTap logic)
            if let toggleNode = node as? ToggleNode {
                // Toggle without selection
                let updated = toggleNode.handlingTap()
                if let index = viewModel.model.nodes.firstIndex(where: { $0.id == toggleNode.id }) {
                    viewModel.model.nodes[index] = AnyNode(updated)
                }
                selectedNodeID = nil
                selectedEdgeID = nil
                logger.debug("Toggled ToggleNode \(toggleNode.label)")
            } else {
                // Select regular node (toggle off if already)
                selectedNodeID = (node.id == selectedNodeID) ? nil : node.id
                selectedEdgeID = nil
                logger.debug("Selected regular Node \(node.label)")
            }
            // Sync with ViewModel (triggers onChange in ContentView)
            viewModel.objectWillChange.send()
          
            // Resume simulation after delay (mimics handleTap)
            Task { await viewModel.resumeSimulationAfterDelay() }
            return true  // Hit occurred
        } else {
            // No node: Check edges
            let hitEdge = HitTestHelper.closestEdge(at: location, visibleEdges: visibleEdges, visibleNodes: visibleNodes, context: hitContext)
            if let edge = hitEdge {
                // Select edge, clear node
                selectedEdgeID = edge.id
                selectedNodeID = nil
                logger.debug("Tap selected Edge \(edge.id.uuidString.prefix(8))")
              
                // Sync with ViewModel (triggers onChange in ContentView)
                viewModel.objectWillChange.send()
              
                // Resume simulation after delay (mimics handleTap)
                Task { await viewModel.resumeSimulationAfterDelay() }
                return true  // Hit occurred
            } else {
                // Miss: Clear all
                selectedNodeID = nil
                selectedEdgeID = nil
                logger.debug("Tap missed; cleared selections")
              
                // Sync with ViewModel (triggers onChange in ContentView)
                viewModel.objectWillChange.send()
              
                // Resume simulation after delay (mimics handleTap)
                Task { await viewModel.resumeSimulationAfterDelay() }
                return false  // No hit
            }
        }
    }
  
    private func handleDragChanged(value: DragGesture.Value, visibleNodes: [any NodeProtocol], context: GestureContext) {
        let location = value.location
        let translation = value.translation
        let dragMagnitude = distance(.zero, CGPoint(x: translation.width, y: translation.height))
      
        // Initial hit if no dragStartNode (start of drag)
        if dragStartNode == nil {
            let hitContext = HitTestContext(zoomScale: context.zoomScale, offset: context.offset, viewSize: context.viewSize, effectiveCentroid: context.effectiveCentroid)
            let hitNode = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, context: hitContext)
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
            gestureStartCentroid = context.effectiveCentroid
            return
        }
      
        // Ongoing drag: Update drag offset and check for potential target
        if let node = draggedNode {
            dragOffset = CGPoint(x: translation.width / zoomScale, y: translation.height / zoomScale)
            let hitContext = HitTestContext(zoomScale: context.zoomScale, offset: context.offset, viewSize: context.viewSize, effectiveCentroid: context.effectiveCentroid)
            let potential = HitTestHelper.closestNode(at: location, visibleNodes: visibleNodes, context: hitContext)
            potentialEdgeTarget = (potential?.id != node.id) ? potential : nil  // Avoid self-edges
            if let target = potentialEdgeTarget {
                logger.debug("Potential edge target: Node \(target.label)")
            }
        }
    }
    
    private func handleDragEnded(value: DragGesture.Value, visibleNodes: [any NodeProtocol], visibleEdges: [GraphEdge], context: GestureContext) {
        let location = value.location
        let translation = value.translation
        let dragMagnitude = distance(.zero, CGPoint(x: translation.width, y: translation.height))
        
        // Defer cleanup (ensures reset even on errors/taps)
        defer { resetGestureState() }
        
        // Early exit for taps (short drag) - enhanced for node/edge selection
        if let start = startLocation, dragMagnitude < dragStartThreshold, distance(start, location) < dragStartThreshold {
            let wasHit = handleTap(at: location, visibleNodes: visibleNodes, visibleEdges: visibleEdges, context: context)
            if wasHit {
                WKInterfaceDevice.current().play(.click)  // Subtler haptic feedback (short tick/tap) on successful hit
            }
            return  // Exit early
        }
        
        print("Processing as drag: magnitude \(dragMagnitude), translation \(translation)")
        
        if let dragged = draggedNode {
            Task { await viewModel.model.snapshot() }
            let modelDragOffset = CGPoint(x: translation.width / zoomScale, y: translation.height / zoomScale)
            print("Drag offset in model: \(modelDragOffset)")
            
            if let target = potentialEdgeTarget, target.id != dragged.id, isAddingEdge {
                handleEdgeCreation(from: dragged, to: target, translation: translation)
            } else {
                handleNodeMovement(for: dragged, with: modelDragOffset)
            }
        }
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            onUpdateZoomRanges()
        }
    }
    
    private func handleEdgeCreation(from dragged: any NodeProtocol, to target: any NodeProtocol, translation: CGSize) {
        // Duplicate check with logging
        let exists = viewModel.model.edges.contains { edge in
            (edge.from == dragged.id && edge.target == target.id) || (edge.from == target.id && edge.target == dragged.id)
        }
        if !exists {
            print("No duplicate; adding edge")
            // Heuristic: Downward = hierarchy
            let type = (translation.height > 0) ? .hierarchy : viewModel.pendingEdgeType
            viewModel.pendingEdgeType = type  // Update for UI
            Task {
                await viewModel.addEdge(from: dragged.id, target: target.id, type: type)  // Async call
            }
            print("Created edge of type \(type.rawValue) from node \(dragged.label) to \(target.label)")
            isAddingEdge = false
        } else {
            print("Duplicate edge ignored between \(dragged.label) and \(target.label)")
        }
    }
    
    private func handleNodeMovement(for dragged: any NodeProtocol, with modelDragOffset: CGPoint) {
        // No target: Move the node (with casts for .with, as it's not on protocol)
        if let index = viewModel.model.nodes.firstIndex(where: { $0.id == dragged.id }) {
            let oldNode = viewModel.model.nodes[index]
            let unwrapped = oldNode.unwrapped
            let newPos = unwrapped.position + modelDragOffset
            let updatedNode: AnyNode
            if let concrete = unwrapped as? Node {
                let concreteUpdated = concrete.with(position: newPos, velocity: .zero)
                updatedNode = AnyNode(concreteUpdated)
            } else if let concrete = unwrapped as? ToggleNode {
                let concreteUpdated = concrete.with(position: newPos, velocity: .zero)
                updatedNode = AnyNode(concreteUpdated)
            } else {
                logger.error("Unsupported node type for move: \(type(of: unwrapped))")
                return
            }
            viewModel.model.nodes[index] = updatedNode
            print("Moved node \(unwrapped.label) to new position \(newPos)")
            Task { await viewModel.model.startSimulation() }
        }
    }
}
extension GraphGesturesModifier {
    public func pointToLineDistance(point: CGPoint, from startPoint: CGPoint, endPoint: CGPoint) -> CGFloat {
        let pointX = Double(point.x), pointY = Double(point.y)
        let startX = Double(startPoint.x), startY = Double(startPoint.y)
        let endX = Double(endPoint.x), endY = Double(endPoint.y)
        
        let lineVecX = endX - startX
        let lineVecY = endY - startY
        let lineLen = hypot(lineVecX, lineVecY)
        
        if lineLen == 0 {
            return distance(point, startPoint)
        }
        
        let pointVecX = pointX - startX
        let pointVecY = pointY - startY
        let dot = pointVecX * lineVecX + pointVecY * lineVecY
        let denom = lineLen * lineLen
        let projectionParam = dot / denom
        let clampedParam = max(0.0, min(1.0, projectionParam))
        
        let projX = startX + lineVecX * clampedParam
        let projY = startY + lineVecY * clampedParam
        
        let proj = CGPoint(x: CGFloat(projX), y: CGFloat(projY))
        return distance(point, proj)
    }
}
