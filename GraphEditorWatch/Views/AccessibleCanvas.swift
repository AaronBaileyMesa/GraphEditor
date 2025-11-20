//
//  AccessibleCanvas.swift
//  GraphEditor
//
//  Updated: Nov 19, 2025 – fully migrated to shared RenderContext (no more AccessibleRenderContext)
//

import SwiftUI
import GraphEditorShared
import os

struct AccessibleCanvas: View {
    private static var logger: Logger {
        Logger(subsystem: "io.handcart.GraphEditor", category: "accessiblecanvas")
    }
    
    let viewModel: GraphViewModel
    let zoomScale: CGFloat
    let offset: CGSize
    let draggedNode: (any NodeProtocol)?
    let dragOffset: CGPoint
    let potentialEdgeTarget: (any NodeProtocol)?
    let selectedNodeID: NodeID?
    let viewSize: CGSize
    let logicalViewSize: CGSize
    let selectedEdgeID: UUID?
    let showOverlays: Bool
    let saturation: Double

    var body: some View {
        ZStack {
            Canvas { context, size in
                let visibleNodes = viewModel.model.visibleNodes
                let visibleEdges = viewModel.model.visibleEdges
                let effectiveCentroid = viewModel.effectiveCentroid

                // ONE SINGLE source of truth – used by EVERYTHING
                let renderContext = RenderContext(
                    effectiveCentroid: effectiveCentroid,
                    zoomScale: zoomScale,
                    offset: offset,
                    viewSize: logicalViewSize
                )

                // Split selected / non-selected
                let nonSelectedNodes = visibleNodes.filter { $0.id != selectedNodeID }
                let selectedNode = visibleNodes.first { $0.id == selectedNodeID }
                let nonSelectedEdges = visibleEdges.filter { $0.id != selectedEdgeID }
                let selectedEdge = visibleEdges.first { $0.id == selectedEdgeID }

                // MARK: - Edge lines (non-selected)
                AccessibleCanvasRenderer.drawEdges(
                    renderContext: renderContext,
                    graphicsContext: context,
                    visibleEdges: nonSelectedEdges,
                    visibleNodes: visibleNodes,
                    saturation: saturation,
                    isSelected: false,
                    logger: Self.logger
                )

                // MARK: - Selected edge line
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

                // MARK: - Dragged node + potential edge
                drawDraggedNodeAndPotentialEdge(in: context, renderContext: renderContext)

                // MARK: - Floating Chevron (now offset to the left)
                if let selectedID = selectedNodeID,
                   let selectedNode = visibleNodes.first(where: { $0.id == selectedID }) as? ToggleNode {
                    
                    let screenPos = CoordinateTransformer.modelToScreen(selectedNode.position, in: renderContext)
                    
                    // Offset the chevron to the left of the node
                    let nodeScreenRadius = selectedNode.radius * renderContext.zoomScale
                    let chevronOffsetX = -(nodeScreenRadius + 12 * renderContext.zoomScale)  // 12 model units ≈ good separation
                    let chevronCenter = CGPoint(x: screenPos.x + chevronOffsetX, y: screenPos.y)
                    
                    var mutableContext = context
                    AccessibleCanvasRenderer.drawFloatingChevron(
                        at: chevronCenter,
                        isExpanded: selectedNode.isExpanded,
                        in: &mutableContext,
                        zoomScale: renderContext.zoomScale
                    )
                }
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

    private func drawDraggedNodeAndPotentialEdge(
        in context: GraphicsContext,
        renderContext: RenderContext
    ) {
        guard let dragged = draggedNode else { return }

        let draggedModelPos = dragged.position + dragOffset
        let draggedScreen = CoordinateTransformer.modelToScreen(draggedModelPos, in: renderContext)
        let radius = Constants.App.nodeModelRadius * zoomScale

        let circleRect = CGRect(
            x: draggedScreen.x - radius,
            y: draggedScreen.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        context.fill(Circle().path(in: circleRect), with: .color(.green))

        if let target = potentialEdgeTarget {
            let targetScreen = CoordinateTransformer.modelToScreen(target.position, in: renderContext)
            let path = Path { path in
                path.move(to: draggedScreen)
                path.addLine(to: targetScreen)
            }
            context.stroke(path, with: .color(.green), lineWidth: 2.0)
        }
    }
}
