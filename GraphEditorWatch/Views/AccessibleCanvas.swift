//
//  AccessibleCanvas.swift
//  GraphEditorWatch
//

import SwiftUI
import GraphEditorShared
import os

// NEW: Subview for Canvas content to force updates by depending on context.date
struct AnimatedCanvasContent: View {
    let contextDate: Date  // Changes every tick (animated) or fixed (static), for logging and .id if needed
    let viewModel: GraphViewModel
    let zoomScale: CGFloat
    let offset: CGSize
    let draggedNode: (any NodeProtocol)?
    let dragOffset: CGPoint
    let potentialEdgeTarget: (any NodeProtocol)?
    let selectedNodeID: NodeID?
    let viewSize: CGSize
    let selectedEdgeID: UUID?
    let showOverlays: Bool
    let saturation: Double
    let currentDragLocation: CGPoint?
    let isAddingEdge: Bool
    let dragStartNode: (any NodeProtocol)?
    let redrawTrigger: Int  // FIXED: Pass redrawTrigger to force recomputation
    
    var body: some View {
        Canvas { graphicsContext, _ in
            var gc = graphicsContext  // Single var for mutable GraphicsContext (use this for all draws)
            let allVisibleNodes = viewModel.model.visibleNodes  // Fresh capture every recompute
            let allVisibleEdges = viewModel.model.visibleEdges
            
            // Filter out control nodes - they're rendered by SwiftUI overlay for immediate display
            let visibleNodes = allVisibleNodes.filter { node in
                !(node is ControlNode)
            }
            
            // Filter out control edges (spring edges to control nodes)
            let controlNodeIDs = Set(viewModel.model.ephemeralControlNodes.map { $0.id })
            let visibleEdges = allVisibleEdges.filter { edge in
                !controlNodeIDs.contains(edge.from) && !controlNodeIDs.contains(edge.target)
            }
            
            let effectiveCentroid = viewModel.effectiveCentroid
            
            // ONE source of truth – used by every drawing function and hit-testing
            let renderContext = RenderContext(
                effectiveCentroid: effectiveCentroid,
                zoomScale: zoomScale,      // already scaled to fill screen
                offset: offset,
                viewSize: viewSize         // full physical size → perfect hit-testing
            )
            
            // Split selected / non-selected for proper layering
            let nonSelectedNodes = visibleNodes.filter { $0.id != selectedNodeID }
            let selectedNode = visibleNodes.first { $0.id == selectedNodeID }
            let nonSelectedEdges = visibleEdges.filter { $0.id != selectedEdgeID }
            let selectedEdge = visibleEdges.first { $0.id == selectedEdgeID }
            
            // MARK: - Edges (non-selected)
            AccessibleCanvasRenderer.drawEdges(
                renderContext: renderContext,
                graphicsContext: gc,  // Change to gc
                visibleEdges: nonSelectedEdges,
                visibleNodes: visibleNodes,
                saturation: saturation
            )
            
            // MARK: - Arrows (non-selected)
            AccessibleCanvasRenderer.drawArrows(
                renderContext: renderContext,
                graphicsContext: gc,  // Change to gc
                visibleEdges: nonSelectedEdges,
                visibleNodes: visibleNodes,
                saturation: saturation
            )
            
            // MARK: - Nodes (non-selected)
            for node in nonSelectedNodes {
                AccessibleCanvasRenderer.drawSingleNode(
                    renderContext: renderContext,
                    graphicsContext: gc,
                    node: node,  // Draw using actual model position
                    saturation: saturation,
                    isSelected: false
                )
            }
            
            // NEW: Draw selected edge (if any) – was missing in animatedCanvas
            if let edge = selectedEdge {
                AccessibleCanvasRenderer.drawSingleEdgeLine(
                    config: EdgeDrawingConfig(
                        renderContext: renderContext,
                        graphicsContext: gc,
                        saturation: saturation,
                        isSelected: true,
                        logger: AccessibleCanvas.logger
                    ),
                    edge: edge,
                    visibleNodes: visibleNodes
                )
                AccessibleCanvasRenderer.drawSingleArrow(
                    config: EdgeDrawingConfig(
                        renderContext: renderContext,
                        graphicsContext: gc,
                        saturation: saturation,
                        isSelected: true,
                        logger: AccessibleCanvas.logger
                    ),
                    edge: edge,
                    visibleNodes: visibleNodes
                )
            }
            
            // MARK: - Selected Node (if any)
            if let node = selectedNode {
                AccessibleCanvasRenderer.drawSingleNode(
                    renderContext: renderContext,
                    graphicsContext: gc,
                    node: node,
                    saturation: saturation,
                    isSelected: true
                )
            }
            
            // MARK: - Overlays (unchanged)
            if showOverlays {
                AccessibleCanvasRenderer.drawBoundingBox(
                    nodes: visibleNodes,
                    in: &gc,  // Change to &gc for inout
                    renderContext: renderContext
                )
            }
            
            // MARK: - Drag Preview (assuming this is the truncated part; adjust as needed)
            drawDragPreview(in: &gc, renderContext: renderContext)
        }
        .id(redrawTrigger)  // FIXED: Force Canvas to recreate when redrawTrigger changes
    }
    
    // Shared drawDragPreview (now inside AnimatedCanvasContent since it's the only user)
    private func drawDragPreview(in context: inout GraphicsContext, renderContext: RenderContext) {
        // FIXED: Only draw drag preview if the node is actually being dragged with an offset
        // This prevents duplicate rendering when a node is selected but not dragged
        if let dragged = draggedNode, dragOffset != .zero {
            // Create a temporary node at the dragged position for rendering
            var draggedCopy = dragged
            draggedCopy.position = dragged.position + dragOffset
            
            AccessibleCanvasRenderer.drawSingleNode(
                renderContext: renderContext,
                graphicsContext: context,
                node: draggedCopy,
                saturation: saturation,
                isSelected: true
            )
        }
        // Add logic for currentDragLocation, isAddingEdge, etc., as in your original code
    }
}

struct AccessibleCanvas: View {
    let viewModel: GraphViewModel
    let zoomScale: CGFloat
    let offset: CGSize
    let draggedNode: (any NodeProtocol)?
    let dragOffset: CGPoint
    let potentialEdgeTarget: (any NodeProtocol)?
    let selectedNodeID: NodeID?
    let selectedEdgeID: UUID?
    let viewSize: CGSize
    let showOverlays: Bool
    let saturation: Double
    let currentDragLocation: CGPoint?
    let isAddingEdge: Bool
    let dragStartNode: (any NodeProtocol)?
    let onUpdateZoomRanges: (CGFloat, CGFloat) -> Void
    
    static let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "accessiblecanvas")
    
    var body: some View {
        ZStack {
            // Canvas layer (draws regular nodes and edges)
            Group {
                if viewModel.model.isSimulating {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                        AnimatedCanvasContent(
                            contextDate: context.date,
                            viewModel: viewModel,
                            zoomScale: zoomScale,
                            offset: offset,
                            draggedNode: draggedNode,
                            dragOffset: dragOffset,
                            potentialEdgeTarget: potentialEdgeTarget,
                            selectedNodeID: selectedNodeID,
                            viewSize: viewSize,
                            selectedEdgeID: selectedEdgeID,
                            showOverlays: showOverlays,
                            saturation: saturation,
                            currentDragLocation: currentDragLocation,
                            isAddingEdge: isAddingEdge,
                            dragStartNode: dragStartNode,
                            redrawTrigger: viewModel.redrawTrigger
                        )
                    }
                } else {
                    AnimatedCanvasContent(
                        contextDate: Date(),
                        viewModel: viewModel,
                        zoomScale: zoomScale,
                        offset: offset,
                        draggedNode: draggedNode,
                        dragOffset: dragOffset,
                        potentialEdgeTarget: potentialEdgeTarget,
                        selectedNodeID: selectedNodeID,
                        viewSize: viewSize,
                        selectedEdgeID: selectedEdgeID,
                        showOverlays: showOverlays,
                        saturation: saturation,
                        currentDragLocation: currentDragLocation,
                        isAddingEdge: isAddingEdge,
                        dragStartNode: dragStartNode,
                        redrawTrigger: viewModel.redrawTrigger
                    )
                }
            }
            .id(viewModel.redrawTrigger)
            
            // SwiftUI overlay for control nodes (immediate rendering)
            // Use @ObservedObject to ensure immediate updates
            ControlNodesOverlayWrapper(
                viewModel: viewModel,
                zoomScale: zoomScale,
                offset: offset,
                viewSize: viewSize
            )
            .id("\(zoomScale)-\(offset.width)-\(offset.height)")
        }
        .accessibilityIdentifier("graphCanvas")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Color.black)
    }
}

// Wrapper that observes ViewModel for immediate updates
struct ControlNodesOverlayWrapper: View {
    @ObservedObject var viewModel: GraphViewModel
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    
    var body: some View {
        let _ = print("ControlNodesOverlayWrapper rendering: \(viewModel.model.ephemeralControlNodes.count) nodes, redrawTrigger=\(viewModel.redrawTrigger)")
        
        return ControlNodesOverlay(
            controlNodes: viewModel.model.ephemeralControlNodes,
            controlEdges: viewModel.model.ephemeralControlEdges,
            visibleNodes: viewModel.model.visibleNodes,
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: viewSize,
            redrawTrigger: viewModel.redrawTrigger
        )
    }
}

// NEW: SwiftUI overlay for control nodes to bypass Canvas rendering lag
struct ControlNodesOverlay: View {
    let controlNodes: [ControlNode]
    let controlEdges: [GraphEdge]
    let visibleNodes: [any NodeProtocol]
    let effectiveCentroid: CGPoint
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    let redrawTrigger: Int
    
    var body: some View {
        let _ = print("ControlNodesOverlay rendering: \(controlNodes.count) nodes, redrawTrigger=\(redrawTrigger)")
        
        return ZStack {
            // Draw control edges first (behind the control nodes)
            ForEach(controlEdges, id: \.id) { edge in
                if let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                   let toNode = visibleNodes.first(where: { $0.id == edge.target }) {
                    let fromScreen = worldToScreen(
                        worldPos: fromNode.position,
                        effectiveCentroid: effectiveCentroid,
                        zoomScale: zoomScale,
                        offset: offset,
                        viewSize: viewSize
                    )
                    let toScreen = worldToScreen(
                        worldPos: toNode.position,
                        effectiveCentroid: effectiveCentroid,
                        zoomScale: zoomScale,
                        offset: offset,
                        viewSize: viewSize
                    )
                    
                    Path { path in
                        path.move(to: fromScreen)
                        path.addLine(to: toScreen)
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1.0)
                    .transition(.opacity)
                }
            }
            
            // Draw control nodes on top
            ForEach(controlNodes, id: \.id) { control in
                let screenPos = worldToScreen(
                    worldPos: control.position,
                    effectiveCentroid: effectiveCentroid,
                    zoomScale: zoomScale,
                    offset: offset,
                    viewSize: viewSize
                )
                
                ControlNodeView(control: control, zoomScale: zoomScale)
                    .position(screenPos)
                    .transition(.scale.combined(with: .opacity))
                    .animation(nil, value: screenPos)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: controlNodes.count)
        .id(controlNodes.first?.ownerID?.uuidString ?? "none")
    }
    
    private func worldToScreen(
        worldPos: CGPoint,
        effectiveCentroid: CGPoint,
        zoomScale: CGFloat,
        offset: CGSize,
        viewSize: CGSize
    ) -> CGPoint {
        let canvasCenterX = viewSize.width / 2
        let canvasCenterY = viewSize.height / 2
        
        let relativeX = (worldPos.x - effectiveCentroid.x) * zoomScale
        let relativeY = (worldPos.y - effectiveCentroid.y) * zoomScale
        
        let screenX = canvasCenterX + relativeX + offset.width
        let screenY = canvasCenterY + relativeY + offset.height
        
        return CGPoint(x: screenX, y: screenY)
    }
}

// NEW: SwiftUI view for individual control node
struct ControlNodeView: View {
    let control: ControlNode
    let zoomScale: CGFloat
    
    var body: some View {
        let iconName: String = switch control.kind {
        case .addChild: "plus.circle.fill"
        case .addEdge: "arrow.right.circle.fill"
        case .edit: "pencil"
        }
        
        ZStack {
            Circle()
                .fill(control.fillColor.opacity(0.9))
                .frame(width: control.radius * 2 * zoomScale, height: control.radius * 2 * zoomScale)
            
            Image(systemName: iconName)
                .font(.system(size: 16 * zoomScale, weight: .medium))
                .foregroundColor(.white)
        }
        .opacity(0.9)
    }
}
