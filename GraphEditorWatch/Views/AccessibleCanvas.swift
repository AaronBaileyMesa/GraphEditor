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
            Canvas { context, size in
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
                    saturation: saturation,
                    isSelected: false,
                    logger: Self.logger
                )

                // MARK: - Selected edge
                if let edge = selectedEdge {
                    AccessibleCanvasRenderer.drawSingleEdgeLine(
                        renderContext: renderContext,
                        graphicsContext: context,
                        edge: edge,
                        visibleNodes: visibleNodes,
                        saturation: 1.0,
                        isSelected: true,
                        logger: Self.logger
                    )
                }

                // MARK: - Nodes (non-selected)
                for node in nonSelectedNodes {
                    AccessibleCanvasRenderer.drawSingleNode(
                        renderContext: renderContext,
                        graphicsContext: context,
                        node: node,
                        saturation: saturation,
                        isSelected: false,
                        logger: Self.logger
                    )
                }

                // MARK: - Selected node
                if let node = selectedNode {
                    AccessibleCanvasRenderer.drawSingleNode(
                        renderContext: renderContext,
                        graphicsContext: context,
                        node: node,
                        saturation: 1.0,
                        isSelected: true,
                        logger: Self.logger
                    )
                }

                // MARK: - Arrowheads (non-selected)
                AccessibleCanvasRenderer.drawArrows(
                    renderContext: renderContext,
                    graphicsContext: context,
                    visibleEdges: nonSelectedEdges,
                    visibleNodes: visibleNodes,
                    saturation: saturation,
                    isSelected: false,
                    logger: Self.logger
                )

                // MARK: - Selected arrowhead
                if let edge = selectedEdge {
                    AccessibleCanvasRenderer.drawSingleArrow(
                        renderContext: renderContext,
                        graphicsContext: context,
                        edge: edge,
                        visibleNodes: visibleNodes,
                        saturation: 1.0,
                        isSelected: true,
                        logger: Self.logger
                    )
                }

                // MARK: - Dragged node + potential edge preview
                drawDraggedNodeAndPotentialEdge(in: context, renderContext: renderContext)
            }

            if showOverlays {
                BoundingBoxOverlay(
                    viewModel: viewModel,
                    zoomScale: zoomScale,
                    offset: offset,
                    viewSize: viewSize
                )
            }
        }
    }

    private func drawDraggedNodeAndPotentialEdge(in context: GraphicsContext, renderContext: RenderContext) {
        // 1. Dragged node ghost
        if let dragged = draggedNode,
           let dragLocation = currentDragLocation {  // ← Use shared param
            
            let liveModelPos = CoordinateTransformer.screenToModel(dragLocation, renderContext)
            let livePos = liveModelPos + dragOffset
            let screenPos = CoordinateTransformer.modelToScreen(livePos, renderContext)
            
            // Bright green ring (slightly larger)
            let ringRect = CGRect(
                x: screenPos.x - dragged.displayRadius * renderContext.zoomScale - 6,
                y: screenPos.y - dragged.displayRadius * renderContext.zoomScale - 6,
                width: (dragged.displayRadius * 2 + 12) * renderContext.zoomScale,
                height: (dragged.displayRadius * 2 + 12) * renderContext.zoomScale
            )
            context.stroke(Circle().path(in: ringRect), with: .color(.green), lineWidth: 6 * renderContext.zoomScale)

            // Node fill
            let nodeRect = CGRect(
                x: screenPos.x - dragged.displayRadius * renderContext.zoomScale,
                y: screenPos.y - dragged.displayRadius * renderContext.zoomScale,
                width:  dragged.displayRadius * 2 * renderContext.zoomScale,
                height: dragged.displayRadius * 2 * renderContext.zoomScale
            )
            context.fill(Circle().path(in: nodeRect), with: .color(dragged.fillColor))

            // Label
            let text = Text("\(dragged.label)")
                .font(.system(size: 14 * renderContext.zoomScale))
                .foregroundColor(.white)
            context.draw(text, at: CGPoint(x: screenPos.x, y: screenPos.y - (dragged.displayRadius + 14) * renderContext.zoomScale))

            // +/- for ToggleNode
            if dragged is ToggleNode {
                let sign = Text((dragged as? ToggleNode)?.isExpanded == true ? "-" : "+")
                    .font(.system(size: 18 * renderContext.zoomScale, weight: .bold))
                    .foregroundColor(.white)
                context.draw(sign, at: screenPos)
            }
        }

        // 2. Potential edge preview (unchanged – already uses live position)
        if isAddingEdge,  // ← Use shared param
               let target = potentialEdgeTarget,
               let from = draggedNode ?? dragStartNode,  // ← Use shared param
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
