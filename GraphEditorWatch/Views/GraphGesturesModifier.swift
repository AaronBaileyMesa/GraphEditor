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
    @State private var longPressTimer: Timer? = nil
    @State private var isLongPressTriggered: Bool = false
    @State private var gestureStartCentroid: CGPoint = .zero  // New: Lock centroid at gesture start
    
    private let dragStartThreshold: CGFloat = 5.0
    
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
                return dist < modelHitRadius / 2  // Example usage if needed; adjust as per your logic
            }
        }
    }
    
    private func focalPointForCentering() -> CGPoint {
        let visibleNodes = viewModel.model.visibleNodes()
        guard !visibleNodes.isEmpty else { return .zero }
        var effectiveCentroid = centroid(of: visibleNodes) ?? .zero
        
        // Check if selectedNodeID is non-nil
        if let nodeID = selectedNodeID {
            // Find the selected node
            guard let selected = visibleNodes.first(where: { $0.id == nodeID }) else {
                return effectiveCentroid
            }
            effectiveCentroid = selected.position
        } else if let edgeID = selectedEdgeID {
            // Find the edge and its connected nodes
            guard let edge = viewModel.model.edges.first(where: { $0.id == edgeID }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }),
                  let to = visibleNodes.first(where: { $0.id == edge.to }) else {
                return effectiveCentroid
            }
            effectiveCentroid = (from.position + to.position) / 2
        }
        
        #if DEBUG
        logger.debug("Focal point calculated: \(String(describing: effectiveCentroid))")
        #endif
        
        return effectiveCentroid
    }
    
    func body(content: Content) -> some View {
        let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                Task { @MainActor in
                    gestureStartCentroid = focalPointForCentering()  // Lock at start if not already
                    
                    // Set panStartOffset early if no hit at current location (for immediate panning near nodes if not long-pressing)
                    let currentHit = hitTestNodesInScreenSpace(at: value.location, visibleNodes: viewModel.model.visibleNodes(), zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: gestureStartCentroid)
                    if currentHit == nil && !isLongPressTriggered {
                        if panStartOffset == nil {
                            panStartOffset = offset
                            #if DEBUG
                            logger.debug("Pan started: Initial offset \(String(describing: offset))")
                            #endif
                        }
                    }
                    
                    // Existing long press timer logic...
                    if longPressTimer == nil && !isLongPressTriggered {
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                            isLongPressTriggered = true
                            WKInterfaceDevice.current().play(.click)
                        }
                    }
                    
                    // Panning update (allow during gesture if no drag active)
                    if let startOffset = panStartOffset, draggedNode == nil {
                        offset = startOffset + CGSize(width: value.translation.width, height: value.translation.height)
                        #if DEBUG
                        logger.debug("Panning updated: New offset \(String(describing: offset)), Translation \(String(describing: value.translation))")
                        #endif
                    }
                    
                    if isLongPressTriggered {
                        // Initiate node drag only on long press
                        if let hitNode = hitTestNodesInScreenSpace(at: value.startLocation, visibleNodes: viewModel.model.visibleNodes(), zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: gestureStartCentroid) {
                            draggedNode = hitNode
                            dragStartNode = hitNode
                            dragOffset = .zero
                            if let currentID = selectedNodeID, currentID == hitNode.id {
                                isMovingSelectedNode = true
                            } else {
                                selectedNodeID = hitNode.id  // Select if not already
                            }
                            Task { await viewModel.model.pauseSimulation() }
                            Task { await viewModel.snapshot() }
                            showMenu = true  // Show menu only on long press
                        }
                        
                        if let node = draggedNode {
                            dragOffset = CGPoint(x: value.translation.width / zoomScale, y: value.translation.height / zoomScale)
                            let tempPos = node.position + dragOffset
                            let visibleNodes = viewModel.model.visibleNodes()
                            let nearby = viewModel.model.physicsEngine.queryNearby(position: tempPos, radius: Constants.Physics.minCollisionDist, nodes: visibleNodes)
                            potentialEdgeTarget = nearby.first { $0.id != node.id }
                        }
                    }
                    
                    // Existing diagnostic logs...
                    #if DEBUG
                    let effectiveCentroid = focalPointForCentering()
                    let translated = CGPoint(x: value.location.x - viewSize.width / 2 - offset.width, y: value.location.y - viewSize.height / 2 - offset.height)
                    let unscaled = CGPoint(x: translated.x / zoomScale, y: translated.y / zoomScale)
                    let touchPos = effectiveCentroid + unscaled
                    logger.debug("--- .onChanged Diagnostic ---")
                    logger.debug("Effective Centroid: \(String(describing: effectiveCentroid))")
                    logger.debug("Screen Pos: \(String(describing: value.location))")
                    logger.debug("Translated: \(String(describing: translated))")
                    logger.debug("Unscaled: \(String(describing: unscaled))")
                    logger.debug("Model Pos (touchPos): \(String(describing: touchPos))")
                    logger.debug("Visible Nodes Count: \(viewModel.model.visibleNodes().count)")
                    logger.debug("-----------------------------")
                    #endif
                }
            }
            .onEnded { value in
                        longPressTimer?.invalidate()
                        longPressTimer = nil
                        isLongPressTriggered = false

                        let translationMag = hypot(value.translation.width, value.translation.height)  // New: Magnitude for better tap detection
                        if translationMag < dragStartThreshold && !isLongPressTriggered {  // Updated condition (use hypot; ignores small jitter)
                            #if DEBUG
                            logger.debug("--- Entering Tap Block (mag: \(translationMag) < \(dragStartThreshold)) ---")  // New: Explicit log for entry
                            #endif

                            let tapScreenPos = value.startLocation
                            let effectiveCentroid = focalPointForCentering()  // Lock at gesture end for tap consistency
                            gestureStartCentroid = effectiveCentroid

                            let visibleNodes = viewModel.model.visibleNodes()
                            let visibleEdges = viewModel.model.visibleEdges()

                            // Screen-space node hit test
                            if let hitNode = hitTestNodesInScreenSpace(at: tapScreenPos, visibleNodes: visibleNodes, zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: gestureStartCentroid) {
                                #if DEBUG
                                logger.debug("Tap hit node: \(hitNode.label)")
                                #endif
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
                                WKInterfaceDevice.current().play(.success)  // UX: Confirm selection
                                #if DEBUG
                                logger.debug("Tap selection updated: selectedNodeID \(selectedNodeID?.uuidString ?? "nil")")
                                #endif
                            } else {
                                // Edge hit test (now screen-space for consistency)
                                if let hitEdge = hitTestEdgesInScreenSpace(at: tapScreenPos, visibleEdges: visibleEdges, visibleNodes: visibleNodes, zoomScale: zoomScale, offset: offset, viewSize: viewSize, effectiveCentroid: gestureStartCentroid) {
                                    #if DEBUG
                                    logger.debug("Tap hit edge: \(hitEdge.id)")
                                    #endif
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
                                    WKInterfaceDevice.current().play(.success)
                                    #if DEBUG
                                    logger.debug("Tap selection updated: selectedEdgeID \(selectedEdgeID?.uuidString ?? "nil")")
                                    #endif
                                } else {
                                    // Miss: Deselect all with feedback
                                    selectedNodeID = nil
                                    selectedEdgeID = nil
                                    WKInterfaceDevice.current().play(.failure)  // UX: Indicate miss
                                    #if DEBUG
                                    logger.debug("Tap miss: Deselected all")
                                    #endif
                                }
                            }

                            #if DEBUG
                            logger.debug("SelectedNodeID after tap: \(selectedNodeID?.uuidString ?? "nil"), SelectedEdgeID after: \(selectedEdgeID?.uuidString ?? "nil")")
                            #endif

                            // Diagnostic logs (gated and summarized)
                            #if DEBUG
//                            let effectiveCentroid = focalPointForCentering()
                            let translated = CGPoint(x: value.startLocation.x - viewSize.width / 2 - offset.width, y: value.startLocation.y - viewSize.height / 2 - offset.height)
                            let unscaled = CGPoint(x: translated.x / zoomScale, y: translated.y / zoomScale)
                            let tapModelPos = unscaled + effectiveCentroid  // Added: Define as unscaled (relative) + centroid for full model pos
                            logger.debug("--- Tap (.onEnded) Diagnostic ---")
                            logger.debug("Effective Centroid: \(String(describing: effectiveCentroid))")
                            logger.debug("Screen Pos: \(String(describing: value.startLocation))")
                            logger.debug("Translated: \(String(describing: translated))")
                            logger.debug("Unscaled: \(String(describing: unscaled))")
                            logger.debug("Model Pos (tapModelPos): \(String(describing: tapModelPos))")  // Note: tapModelPos not defined here; remove or define if needed
                            logger.debug("Visible Nodes Count: \(visibleNodes.count)")  // Summarized
                            logger.debug("--------------------------------")
                            #endif

                            Task { await viewModel.handleTap() }  // Restored: Pause/resume simulation on tap (optional; remove if unwanted)
                        } else {
                            // Your existing non-tap logic (unchanged; truncated for brevity)
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
                        onUpdateZoomRanges()
                    }

                content
                    .highPriorityGesture(dragGesture)  // Kept as-is; consider .gesture(dragGesture.simultaneously(with: TapGesture()...)) if issues persist
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
