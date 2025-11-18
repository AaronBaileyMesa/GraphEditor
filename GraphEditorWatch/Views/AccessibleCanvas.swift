//
//  AccessibleCanvas.swift
//  GraphEditor
//
//  Created by handcart on 11/6/25.
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
    let selectedEdgeID: UUID?
    let showOverlays: Bool
    let saturation: Double  // NEW: Add this

    var body: some View {
        ZStack {
            Canvas { context, size in
                // Define visibleNodes and visibleEdges
                let visibleNodes = viewModel.model.visibleNodes()
                let visibleEdges = viewModel.model.visibleEdges()  // Fix: Use visibleEdges() instead of all edges
                
#if DEBUG
                Self.logger.debug("Visible: \(visibleNodes.count)")
#endif
                
                let effectiveCentroid = viewModel.effectiveCentroid
                
                let renderContext = AccessibleRenderContext(
                    graphicsContext: context,
                    size: size,
                    effectiveCentroid: effectiveCentroid,
                    zoomScale: zoomScale,
                    offset: offset,
                    visibleNodes: visibleNodes
                )
                
                // NEW: Compute selected/non-selected sets
                let nonSelectedNodes = visibleNodes.filter { $0.id != selectedNodeID }
                let selectedNode = visibleNodes.first { $0.id == selectedNodeID }
                let nonSelectedEdges = visibleEdges.filter { $0.id != selectedEdgeID }
                let selectedEdge = visibleEdges.first { $0.id == selectedEdgeID }
                
                // Draw non-selected edges (lines) with desaturated color
                AccessibleCanvasRenderer.drawEdges(renderContext: renderContext, visibleEdges: nonSelectedEdges, saturation: saturation, isSelected: false, logger: Self.logger)
                
                // Draw selected edge (line) with full color if any
                if let edge = selectedEdge {
                    AccessibleCanvasRenderer.drawSingleEdgeLine(renderContext: renderContext, edge: edge, saturation: 1.0, isSelected: true, logger: Self.logger)
                }
                
                // Draw non-selected nodes with desaturated color
                for node in nonSelectedNodes {
                    AccessibleCanvasRenderer.drawSingleNode(renderContext: renderContext, node: node, saturation: saturation, isSelected: false, logger: Self.logger)
                }
                
                // Draw selected node with full color if any
                if let node = selectedNode {
                    AccessibleCanvasRenderer.drawSingleNode(renderContext: renderContext, node: node, saturation: 1.0, isSelected: true, logger: Self.logger)
                }
                
                // Draw non-selected arrows with desaturated color
                AccessibleCanvasRenderer.drawArrows(renderContext: renderContext, visibleEdges: nonSelectedEdges, saturation: saturation, isSelected: false, logger: Self.logger)
                
                // Draw selected arrow with full color if any
                if let edge = selectedEdge {
                    AccessibleCanvasRenderer.drawSingleArrow(renderContext: renderContext, edge: edge, saturation: 1.0, isSelected: true, logger: Self.logger)
                }
                
                // Draw dragged node and potential edge (keep full color)
                drawDraggedNodeAndPotentialEdge(in: context, size: size, effectiveCentroid: effectiveCentroid)
                
                // Floating chevrons for selected ToggleNodes
                var mutableContext = context
                if let selectedID = selectedNodeID,
                   let selectedToggleNode = visibleNodes.first(where: { $0.id == selectedID }) as? ToggleNode {
                    
                    let screenPos = CoordinateTransformer.modelToScreen(
                        selectedToggleNode.position,
                        effectiveCentroid: effectiveCentroid,
                        zoomScale: zoomScale,
                        offset: offset,
                        viewSize: size
                    )
                    
                    let nodeRadius = selectedToggleNode.radius * zoomScale
                    let chevronCenter = CGPoint(
                        x: screenPos.x + nodeRadius + 14 * zoomScale,
                        y: screenPos.y
                    )
                    
                    AccessibleCanvasRenderer.drawFloatingChevron(
                        at: chevronCenter,
                        isExpanded: selectedToggleNode.isExpanded,
                        in: &mutableContext,
                        zoomScale: zoomScale
                    )
                }
                
            }
            
            if showOverlays {
                BoundingBoxOverlay(viewModel: viewModel, zoomScale: zoomScale, offset: offset, viewSize: viewSize)
            }
            
        }
    }

    private func drawDraggedNodeAndPotentialEdge(in context: GraphicsContext, size: CGSize, effectiveCentroid: CGPoint) {
        // Draw dragged node and potential edge
        if let dragged = draggedNode {
            let draggedScreen = CoordinateTransformer.modelToScreen(
                dragged.position + dragOffset,
                effectiveCentroid: effectiveCentroid,
                zoomScale: zoomScale,
                offset: offset,
                viewSize: size
            )
            context.fill(Circle().path(in: CGRect(center: draggedScreen, size: CGSize(width: Constants.App.nodeModelRadius * 2 * zoomScale, height: Constants.App.nodeModelRadius * 2 * zoomScale))), with: .color(.green))
            
            if let target = potentialEdgeTarget {
                let targetScreen = CoordinateTransformer.modelToScreen(
                    target.position,
                    effectiveCentroid: effectiveCentroid,
                    zoomScale: zoomScale,
                    offset: offset,
                    viewSize: size
                )
                let tempLinePath = Path { path in
                    path.move(to: draggedScreen)
                    path.addLine(to: targetScreen)
                }
                context.stroke(tempLinePath, with: .color(.green), lineWidth: 2.0)
            }
        }
    }
}
