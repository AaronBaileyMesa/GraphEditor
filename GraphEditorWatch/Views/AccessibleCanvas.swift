//
//  AccessibleCanvas.swift
//  GraphEditorWatch
//

import SwiftUI
import GraphEditorShared
import os

struct AccessibleCanvas: View {
    private static var logger: Logger {
        Logger(subsystem: "io.handcart.GraphEditor", category: "accessiblecanvas")
    }
    
    let viewModel: GraphViewModel
    let zoomScale: CGFloat          // already includes scaleToFit
    let offset: CGSize
    let draggedNode: (any NodeProtocol)?
    let dragOffset: CGPoint
    let potentialEdgeTarget: (any NodeProtocol)?
    let selectedNodeID: NodeID?
    let viewSize: CGSize            // full physical screen
    let selectedEdgeID: UUID?
    let showOverlays: Bool
    let saturation: Double
    let currentDragLocation: CGPoint?  // NEW (no @Binding needed here, as it's leaf view)
    let isAddingEdge: Bool  // NEW
    let dragStartNode: (any NodeProtocol)?  // NEW
    
    var body: some View {
        ZStack {
            if viewModel.isAnimating {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in  // Keep as-is; inference will handle
                    animatedCanvas(for: context)
                }
            } else {
                staticCanvas
            }
        }
    }
    
    @ViewBuilder
    private func animatedCanvas<S: TimelineSchedule>(for context: TimelineView<S, some View>.Context) -> some View {  // Add generic <S: TimelineSchedule> and use S
        Canvas { graphicsContext, _ in
            var gc = graphicsContext  // Single var for mutable GraphicsContext (use this for all draws)
            let visibleNodes = viewModel.model.visibleNodes
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
                        logger: Self.logger
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
                        logger: Self.logger
                    ),
                    edge: edge,
                    visibleNodes: visibleNodes
                )
            }
            
            // NEW: Draw selected node (if any) – was missing in animatedCanvas
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
                    in: &gc,  // Change to &gc
                    renderContext: renderContext
                )
            }
            
            // MARK: - Drag Preview (unchanged)
            drawDragPreview(in: &gc, renderContext: renderContext)  // Change to &gc
        }
    }
    
    @ViewBuilder
    private var staticCanvas: some View {
        Canvas { graphicsContext, _ in
            var context = graphicsContext  // Mutable copy
            
            let visibleNodes = viewModel.model.visibleNodes
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
                graphicsContext: context,
                visibleEdges: nonSelectedEdges,
                visibleNodes: visibleNodes,
                saturation: saturation
            )
            
            // MARK: - Arrows (non-selected)
            AccessibleCanvasRenderer.drawArrows(
                renderContext: renderContext,
                graphicsContext: context,
                visibleEdges: nonSelectedEdges,
                visibleNodes: visibleNodes,
                saturation: saturation
            )
            
            // MARK: - Nodes (non-selected)
            for node in nonSelectedNodes {
                AccessibleCanvasRenderer.drawSingleNode(
                    renderContext: renderContext,
                    graphicsContext: context,
                    node: node,
                    saturation: saturation,
                    isSelected: false
                )
            }
            
            // MARK: - Selected Edge (if any)
            if let edge = selectedEdge {
                AccessibleCanvasRenderer.drawSingleEdgeLine(
                    config: EdgeDrawingConfig(
                        renderContext: renderContext,
                        graphicsContext: context,
                        saturation: saturation,
                        isSelected: true,
                        logger: Self.logger
                    ),
                    edge: edge,
                    visibleNodes: visibleNodes
                )
                AccessibleCanvasRenderer.drawSingleArrow(
                    config: EdgeDrawingConfig(
                        renderContext: renderContext,
                        graphicsContext: context,
                        saturation: saturation,
                        isSelected: true,
                        logger: Self.logger
                    ),
                    edge: edge,
                    visibleNodes: visibleNodes
                )
            }
            
            // MARK: - Selected Node (if any)
            if let node = selectedNode {
                AccessibleCanvasRenderer.drawSingleNode(
                    renderContext: renderContext,
                    graphicsContext: context,
                    node: node,
                    saturation: saturation,
                    isSelected: true
                )
            }
            
            // MARK: - Overlays (unchanged)
            if showOverlays {
                AccessibleCanvasRenderer.drawBoundingBox(
                    nodes: visibleNodes,
                    in: &context,
                    renderContext: renderContext
                )
            }
            
            // MARK: - Drag Preview (unchanged)
            drawDragPreview(in: &context, renderContext: renderContext)
        }
    }
    
    // Existing drawDragPreview function (unchanged)
    private func drawDragPreview(in context: inout GraphicsContext, renderContext: RenderContext) {
        // 1. Dragged node preview (unchanged – already uses live position)
        if let dragged = draggedNode, let dragLocation = currentDragLocation {
            let liveModelPos = CoordinateTransformer.screenToModel(dragLocation, renderContext)
            let screenPos = CoordinateTransformer.modelToScreen(liveModelPos + dragOffset, renderContext)
            
            let nodeRect = CGRect(
                x: screenPos.x - dragged.displayRadius * renderContext.zoomScale,
                y: screenPos.y - dragged.displayRadius * renderContext.zoomScale,
                width: dragged.displayRadius * 2 * renderContext.zoomScale,
                height: dragged.displayRadius * 2 * renderContext.zoomScale
            )
            context.fill(Circle().path(in: nodeRect), with: .color(dragged.fillColor))
            
            let text = Text("\(dragged.label)")
                .font(.system(size: 14 * renderContext.zoomScale))
                .foregroundColor(.white)
            context.draw(text, at: CGPoint(x: screenPos.x, y: screenPos.y - (dragged.displayRadius + 14) * renderContext.zoomScale))
            
            if dragged is ToggleNode {
                let sign = Text((dragged as? ToggleNode)?.isExpanded == true ? "-" : "+")
                    .font(.system(size: 18 * renderContext.zoomScale, weight: .bold))
                    .foregroundColor(.white)
                context.draw(sign, at: screenPos)
            }
        }
        
        // 2. Potential edge preview (unchanged – already uses live position)
        if isAddingEdge,
           let target = potentialEdgeTarget,
           let dragLocation = currentDragLocation {
            
            let liveModelPos = CoordinateTransformer.screenToModel(dragLocation, renderContext)
            let fromScreen = CoordinateTransformer.modelToScreen(liveModelPos + dragOffset, renderContext)
            let toScreen = CoordinateTransformer.modelToScreen(target.position, renderContext)
            
            let path = Path { pathP in
                pathP.move(to: fromScreen)
                pathP.addLine(to: toScreen)
            }
            context.stroke(path, with: .color(.green.opacity(0.7)),
                           style: StrokeStyle(lineWidth: 4 * renderContext.zoomScale, dash: [8, 6]))
        }
    }
}
