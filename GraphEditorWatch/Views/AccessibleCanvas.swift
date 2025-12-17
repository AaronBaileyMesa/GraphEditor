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
    
    var body: some View {
        let _ = print("AnimatedCanvasContent recomputed at \(contextDate.timeIntervalSinceReferenceDate), visibleNodes count: \(viewModel.model.visibleNodes.count)")  // DEBUG: Confirm fresh recomputes
        
        Canvas { graphicsContext, _ in
            var gc = graphicsContext  // Single var for mutable GraphicsContext (use this for all draws)
            let visibleNodes = viewModel.model.visibleNodes  // Fresh capture every recompute
            let visibleEdges = viewModel.model.visibleEdges
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
    }
    
    // Shared drawDragPreview (now inside AnimatedCanvasContent since it's the only user)
    private func drawDragPreview(in context: inout GraphicsContext, renderContext: RenderContext) {
        // Your existing implementation here (e.g., drawing draggedNode, potential edge, etc.)
        // Example placeholder:
        if let dragged = draggedNode {
            AccessibleCanvasRenderer.drawSingleNode(
                renderContext: renderContext,
                graphicsContext: context,
                node: dragged,
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
        let bounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.visibleNodes)
            .insetBy(dx: -40, dy: -40)
        let minZoom = min(viewSize.width / bounds.width, viewSize.height / bounds.height).clamped(to: 0.2...1.0)
        let maxZoom = max(1.0, minZoom * 8.0).clamped(to: 1.0...5.0)
        
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
                        dragStartNode: dragStartNode
                    )
                }
            } else {
                // Static fallback: Use same content view with fixed date → immediate recomputes on model changes
                AnimatedCanvasContent(
                    contextDate: Date(),  // Fixed for logging; could use .now for timestamp accuracy
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
                    dragStartNode: dragStartNode
                )
            }
        }
        .id(viewModel.redrawTrigger)  // Apply at top level for full container recreation on trigger changes
        .accessibilityIdentifier("graphCanvas")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Color.black)
        .onChange(of: bounds) { _ in
            onUpdateZoomRanges(minZoom, maxZoom)
        }
    }
}
