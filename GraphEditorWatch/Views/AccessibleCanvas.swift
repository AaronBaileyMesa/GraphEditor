//
//  AccessibleCanvas.swift
//  GraphEditor
//
//  Created by handcart on 11/6/25.
//

import SwiftUI
import GraphEditorShared
import os

struct AccessibleRenderContext {
    let graphicsContext: GraphicsContext
    let size: CGSize
    let effectiveCentroid: CGPoint
    let zoomScale: CGFloat
    let offset: CGSize
    let visibleNodes: [any NodeProtocol]
}

struct AccessibleCanvasRenderer {
    // Proper desaturation by scaling original saturation (hardcoded for known colors on watchOS)
    static func desaturatedColor(_ color: Color, saturation: Double) -> Color {
        switch color {
        case .red:
            return Color(hue: 0, saturation: saturation, brightness: 1)
        case .green:
            return Color(hue: 120/360, saturation: saturation, brightness: 1)
        case .blue:
            return Color(hue: 240/360, saturation: saturation, brightness: 1)
        case .gray:
            return color
        case .white:
            return color
        default:
            return color
        }
    }

    static func drawFloatingChevron(
        at center: CGPoint,
        isExpanded: Bool,
        in context: inout GraphicsContext,
        zoomScale: CGFloat
    ) {
        let size = 20 * zoomScale
        context.drawLayer { layer in
            layer.translateBy(x: center.x, y: center.y)
            layer.rotate(by: isExpanded ? .degrees(90) : .zero)
            layer.translateBy(x: -center.x, y: -center.y)
            let path = Path { path in
                let half = size * 0.4
                path.move(to: CGPoint(x: center.x - half, y: center.y - half))
                path.addLine(to: CGPoint(x: center.x + half, y: center.y))
                path.move(to: CGPoint(x: center.x - half, y: center.y + half))
                path.addLine(to: CGPoint(x: center.x + half, y: center.y))
            }
            layer.stroke(
                path,
                with: .color(.white),
                lineWidth: max(2.5, 3.5 * zoomScale)
            )
        }
    }

    static func drawSingleNode(renderContext: AccessibleRenderContext, node: any NodeProtocol, saturation: Double, isSelected: Bool, logger: Logger?) {
        let screenPos = CoordinateTransformer.modelToScreen(
            node.position,
            effectiveCentroid: renderContext.effectiveCentroid,
            zoomScale: renderContext.zoomScale,
            offset: renderContext.offset,
            viewSize: renderContext.size
        )
        let scaledRadius = node.radius * renderContext.zoomScale
        let borderWidth: CGFloat = isSelected ? max(3.0, 4 * renderContext.zoomScale) : 1.0
        let nodeRect = CGRect(center: screenPos, size: CGSize(width: scaledRadius * 2, height: scaledRadius * 2)).insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let nodePath = Circle().path(in: nodeRect)

        var mutableContext = renderContext.graphicsContext

        var fillColor = node.fillColor
        if saturation < 1.0 {
            fillColor = desaturatedColor(fillColor, saturation: saturation)
        }
        mutableContext.fill(nodePath, with: .color(fillColor))

        let borderColor = isSelected ? Color.white : Color.gray.opacity(0.5)
        mutableContext.stroke(nodePath, with: .color(borderColor), lineWidth: borderWidth)

        let labelText = Text("\(node.label)")
            .font(.system(size: max(8, 10 * renderContext.zoomScale)))
            .foregroundStyle(.white)
        let resolvedText = mutableContext.resolve(labelText)
        mutableContext.draw(resolvedText, at: screenPos, anchor: .center)

        if !node.contents.isEmpty && renderContext.zoomScale > 0.5 {
            var yOffset = scaledRadius + 5 * renderContext.zoomScale
            let contentFontSize = max(6.0, 8.0 * renderContext.zoomScale)
            let maxItems = 3
            for content in node.contents.prefix(maxItems) {
                let contentText = Text(content.displayText).font(.system(size: contentFontSize)).foregroundColor(.gray)
                let resolved = mutableContext.resolve(contentText)
                let contentPosition = CGPoint(x: screenPos.x, y: screenPos.y + yOffset)
                mutableContext.draw(resolved, at: contentPosition, anchor: .center)
                yOffset += 10 * renderContext.zoomScale
            }
            if node.contents.count > maxItems {
                let moreText = Text("+\(node.contents.count - maxItems) more").font(.system(size: contentFontSize * 0.75)).foregroundColor(.gray)
                let resolved = mutableContext.resolve(moreText)
                mutableContext.draw(resolved, at: CGPoint(x: screenPos.x, y: screenPos.y + yOffset), anchor: .center)
            }
        }

        #if DEBUG
        if let logger { logger.debug("Drawing node \(node.label) at screen x=\(screenPos.x), y=\(screenPos.y)") }
        #endif
    }

    static func drawSingleEdgeLine(renderContext: AccessibleRenderContext, edge: GraphEdge, saturation: Double, isSelected: Bool, logger: Logger?) {
        let fromNode = renderContext.visibleNodes.first { $0.id == edge.from }!
        let toNode = renderContext.visibleNodes.first { $0.id == edge.target }!

        let fromScreen = CoordinateTransformer.modelToScreen(
            fromNode.position,
            effectiveCentroid: renderContext.effectiveCentroid,
            zoomScale: renderContext.zoomScale,
            offset: renderContext.offset,
            viewSize: renderContext.size
        )
        let toScreen = CoordinateTransformer.modelToScreen(
            toNode.position,
            effectiveCentroid: renderContext.effectiveCentroid,
            zoomScale: renderContext.zoomScale,
            offset: renderContext.offset,
            viewSize: renderContext.size
        )

        let direction = CGVector(dx: toScreen.x - fromScreen.x, dy: toScreen.y - fromScreen.y)
        let length = hypot(direction.dx, direction.dy)
        if length <= 0 { return }

        let unitDx = direction.dx / length
        let unitDy = direction.dy / length
        let fromRadiusScreen = fromNode.radius * renderContext.zoomScale
        let toRadiusScreen = toNode.radius * renderContext.zoomScale

        let startPoint = CGPoint(x: fromScreen.x + unitDx * fromRadiusScreen,
                                 y: fromScreen.y + unitDy * fromRadiusScreen)
        let endPoint = CGPoint(x: toScreen.x - unitDx * toRadiusScreen,
                               y: toScreen.y - unitDy * toRadiusScreen)

        let linePath = Path { path in
            path.move(to: startPoint)
            path.addLine(to: endPoint)
        }

        let baseColor: Color = isSelected ? .red : .white
        let lineColor = desaturatedColor(baseColor, saturation: saturation)
        let lineWidth: CGFloat = isSelected ? 3.0 : 1.0

        renderContext.graphicsContext.stroke(linePath, with: .color(lineColor), lineWidth: lineWidth)

        #if DEBUG
        if let logger { logger.debug("Drawing line for edge \(edge.id.uuidString.prefix(8)) from x=\(startPoint.x), y=\(startPoint.y) to x=\(endPoint.x), y=\(endPoint.y)") }
        #endif
    }

    static func drawSingleArrow(renderContext: AccessibleRenderContext, edge: GraphEdge, saturation: Double, isSelected: Bool, logger: Logger?) {
        let fromNode = renderContext.visibleNodes.first { $0.id == edge.from }!
        let toNode = renderContext.visibleNodes.first { $0.id == edge.target }!

        let fromScreen = CoordinateTransformer.modelToScreen(
            fromNode.position,
            effectiveCentroid: renderContext.effectiveCentroid,
            zoomScale: renderContext.zoomScale,
            offset: renderContext.offset,
            viewSize: renderContext.size
        )
        let toScreen = CoordinateTransformer.modelToScreen(
            toNode.position,
            effectiveCentroid: renderContext.effectiveCentroid,
            zoomScale: renderContext.zoomScale,
            offset: renderContext.offset,
            viewSize: renderContext.size
        )

        let direction = CGVector(dx: toScreen.x - fromScreen.x, dy: toScreen.y - fromScreen.y)
        let length = hypot(direction.dx, direction.dy)
        if length <= 0 { return }

        let unitDx = direction.dx / length
        let unitDy = direction.dy / length
        let toRadiusScreen = toNode.radius * renderContext.zoomScale
        let boundaryPoint = CGPoint(x: toScreen.x - unitDx * toRadiusScreen,
                                    y: toScreen.y - unitDy * toRadiusScreen)

        let lineAngle = atan2(unitDy, unitDx)
        let arrowLength: CGFloat = 10.0
        let arrowAngle: CGFloat = .pi / 6
        let arrowPoint1 = CGPoint(
            x: boundaryPoint.x - arrowLength * cos(lineAngle - arrowAngle),
            y: boundaryPoint.y - arrowLength * sin(lineAngle - arrowAngle)
        )
        let arrowPoint2 = CGPoint(
            x: boundaryPoint.x - arrowLength * cos(lineAngle + arrowAngle),
            y: boundaryPoint.y - arrowLength * sin(lineAngle + arrowAngle)
        )

        let arrowPath = Path { path in
            path.move(to: boundaryPoint)
            path.addLine(to: arrowPoint1)
            path.move(to: boundaryPoint)
            path.addLine(to: arrowPoint2)
        }

        let baseColor: Color = isSelected ? .red : .white
        let arrowColor = desaturatedColor(baseColor, saturation: saturation)
        let arrowLineWidth: CGFloat = 3.0

        renderContext.graphicsContext.stroke(arrowPath, with: .color(arrowColor), lineWidth: arrowLineWidth)

        #if DEBUG
        if let logger { logger.debug("Drawing arrow for edge \(edge.id.uuidString.prefix(8)) to boundary x=\(boundaryPoint.x), y=\(boundaryPoint.y)") }
        #endif
    }

    static func drawEdges(renderContext: AccessibleRenderContext, visibleEdges: [GraphEdge], saturation: Double, isSelected: Bool, logger: Logger?) {
        for edge in visibleEdges {
            drawSingleEdgeLine(renderContext: renderContext, edge: edge, saturation: saturation, isSelected: isSelected, logger: logger)
        }
    }

    static func drawArrows(renderContext: AccessibleRenderContext, visibleEdges: [GraphEdge], saturation: Double, isSelected: Bool, logger: Logger?) {
        for edge in visibleEdges {
            drawSingleArrow(renderContext: renderContext, edge: edge, saturation: saturation, isSelected: isSelected, logger: logger)
        }
    }

    static func drawChevron(
        for toggleNode: ToggleNode,
        at screenPos: CGPoint,
        in context: inout GraphicsContext,
        zoomScale: CGFloat
    ) {
        let chevronSize = toggleNode.radius * zoomScale * 0.6
        context.drawLayer { layer in
            layer.translateBy(x: screenPos.x, y: screenPos.y)
            let rotationAngle = toggleNode.isExpanded ? Angle.degrees(90) : .zero
            layer.rotate(by: rotationAngle)
            layer.translateBy(x: -screenPos.x, y: -screenPos.y)
            let path = Path { path in
                let half = chevronSize * 0.5
                let offset = chevronSize * 0.15
                path.move(to: CGPoint(x: screenPos.x - half + offset, y: screenPos.y - half))
                path.addLine(to: CGPoint(x: screenPos.x + half, y: screenPos.y))
                path.move(to: CGPoint(x: screenPos.x - half + offset, y: screenPos.y + half))
                path.addLine(to: CGPoint(x: screenPos.x + half, y: screenPos.y))
            }
            layer.stroke(
                path,
                with: .color(.white),
                lineWidth: max(2.0, 3.0 * zoomScale)
            )
        }
    }
}

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
