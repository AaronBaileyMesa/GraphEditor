//
//  AccessibleCanvasRenderer.swift
//  GraphEditor
//
//  Created by handcart on 11/6/25.
//  Updated: Nov 19, 2025 – fully migrated to shared RenderContext
//

import SwiftUI
import GraphEditorShared
import os

struct EdgeDrawingConfig {
    let renderContext: RenderContext
    let graphicsContext: GraphicsContext
    let saturation: Double
    let isSelected: Bool
    let logger: Logger?
}

struct AccessibleCanvasRenderer {
    
    // MARK: - Desaturation Helper (unchanged)
    static func desaturatedColor(_ color: Color, saturation: Double) -> Color {
        switch color {
        case .red: return Color(hue: 0, saturation: saturation, brightness: 1)
        case .green: return Color(hue: 120/360.0, saturation: saturation, brightness: 1)
        case .blue: return Color(hue: 240/360.0, saturation: saturation, brightness: 1)
        case .gray, .white: return color
        default: return color
        }
    }
    
    // MARK: - Convenience: one single source of truth for model → screen
    private static func modelToScreen(_ modelPos: CGPoint, renderContext: RenderContext) -> CGPoint {
        CoordinateTransformer.modelToScreen(modelPos, in: renderContext)
    }
    
    // MARK: - Floating Chevron (unchanged – only needs zoomScale)
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
            
            let half = size * 0.4
            let path = Path { path in
                path.move(to: CGPoint(x: center.x - half, y: center.y - half))
                path.addLine(to: CGPoint(x: center.x + half, y: center.y))
                path.move(to: CGPoint(x: center.x - half, y: center.y + half))
                path.addLine(to: CGPoint(x: center.x + half, y: center.y))
            }
            layer.stroke(path, with: .color(.white), lineWidth: max(2.5, 3.5 * zoomScale))
        }
    }
    
    // MARK: - Border Styling Helper
    private static func borderStyling(
        isEdgeCreationSource: Bool,
        isEdgeCreationTarget: Bool,
        isSelected: Bool,
        zoomScale: CGFloat
    ) -> (width: CGFloat, color: Color) {
        if isEdgeCreationSource {
            return (max(4.0, 5 * zoomScale), .yellow)
        } else if isEdgeCreationTarget {
            return (max(2.5, 3 * zoomScale), .cyan.opacity(0.8))
        } else if isSelected {
            return (max(3.0, 4 * zoomScale), .white)
        } else {
            return (1.0, .gray.opacity(0.5))
        }
    }
    
    // MARK: - Node Shape Rendering
    private static func drawNodeShape(
        context: GraphicsContext,
        node: any NodeProtocol,
        screenPos: CGPoint,
        scaledRadius: CGFloat,
        fill: Color,
        borderWidth: CGFloat,
        borderColor: Color,
        zoomScale: CGFloat
    ) {
        if let table = node as? TableNode {
            let tableRect = CGRect(
                x: screenPos.x - (table.tableWidth * zoomScale) / 2,
                y: screenPos.y - (table.tableLength * zoomScale) / 2,
                width: table.tableWidth * zoomScale,
                height: table.tableLength * zoomScale
            )
            let cornerRadius = 8 * zoomScale
            let tablePath = RoundedRectangle(cornerRadius: cornerRadius).path(in: tableRect)
            context.fill(tablePath, with: .color(fill))
            context.stroke(tablePath, with: .color(borderColor), lineWidth: borderWidth)
        } else {
            let nodeRect = CGRect(
                x: screenPos.x - scaledRadius,
                y: screenPos.y - scaledRadius,
                width: scaledRadius * 2,
                height: scaledRadius * 2
            ).insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
            let nodePath = Circle().path(in: nodeRect)
            context.fill(nodePath, with: .color(fill))
            context.stroke(nodePath, with: .color(borderColor), lineWidth: borderWidth)
        }
    }
    
    // MARK: - Node Label Rendering
    private static func drawNodeLabels(
        context: GraphicsContext,
        node: any NodeProtocol,
        screenPos: CGPoint,
        zoomScale: CGFloat,
        tablePosition: CGPoint?,
        logger: Logger?
    ) {
        if let control = node as? ControlNode {
            drawControlIcon(context: context, control: control, screenPos: screenPos, zoomScale: zoomScale, logger: logger)
        } else if let person = node as? PersonNode {
            drawPersonLabel(context: context, person: person, node: node, screenPos: screenPos, zoomScale: zoomScale, tablePosition: tablePosition)
        } else if let table = node as? TableNode {
            drawTableLabel(context: context, table: table, node: node, screenPos: screenPos, zoomScale: zoomScale)
        } else {
            drawRegularNodeLabels(context: context, node: node, screenPos: screenPos, zoomScale: zoomScale)
        }
    }
    
    private static func drawControlIcon(
        context: GraphicsContext,
        control: ControlNode,
        screenPos: CGPoint,
        zoomScale: CGFloat,
        logger: Logger?
    ) {
        let iconSize = max(8.0, 12.0 * zoomScale)
        let iconRect = CGRect(
            x: screenPos.x - iconSize / 2,
            y: screenPos.y - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        
        let icon = Image(systemName: control.kind.systemImage)
        context.drawLayer { layer in
            layer.addFilter(.colorMultiply(.white))
            layer.draw(icon, in: iconRect)
        }
        
        #if DEBUG
        logger?.debug("Drew control node icon '\(control.kind.systemImage)' at (x: \(screenPos.x, privacy: .public), y: \(screenPos.y, privacy: .public))")
        #endif
    }
    
    private static func drawPersonLabel(
        context: GraphicsContext,
        person: PersonNode,
        node: any NodeProtocol,
        screenPos: CGPoint,
        zoomScale: CGFloat,
        tablePosition: CGPoint?
    ) {
        guard !node.contents.isEmpty, zoomScale >= 0.5 else { return }
        
        let contentText = node.contents[0].displayText
        let contentLabel = Text(contentText)
            .font(.system(size: max(6, 9 * zoomScale)))
            .foregroundColor(.white.opacity(0.8))
        
        let contentPos: CGPoint
        if let tablePos = tablePosition {
            let dx = person.position.x - tablePos.x
            let dy = person.position.y - tablePos.y
            let distance = sqrt(dx * dx + dy * dy)
            
            #if DEBUG
            print("🧍 Person '\(contentText)' at model(\(person.position.x),\(person.position.y)) near table at model(\(tablePos.x),\(tablePos.y))")
            print("   Distance from table center: \(distance)pt, dx=\(dx), dy=\(dy)")
            print("   Screen position: (\(screenPos.x),\(screenPos.y)), zoom=\(zoomScale)")
            #endif
            if distance > 0.1 {
                let dirX = dx / distance
                let dirY = dy / distance
                let labelOffset = (node.radius + 10) * zoomScale
                contentPos = CGPoint(
                    x: screenPos.x + dirX * labelOffset,
                    y: screenPos.y + dirY * labelOffset
                )
            } else {
                contentPos = CGPoint(x: screenPos.x, y: screenPos.y + (node.radius + 10) * zoomScale)
            }
        } else {
            contentPos = CGPoint(x: screenPos.x, y: screenPos.y + (node.radius + 10) * zoomScale)
        }
        context.draw(contentLabel, at: contentPos, anchor: .center)
    }
    
    private static func drawTableLabel(
        context: GraphicsContext,
        table: TableNode,
        node: any NodeProtocol,
        screenPos: CGPoint,
        zoomScale: CGFloat
    ) {
        guard !node.contents.isEmpty, zoomScale >= 0.5 else { return }
        
        let contentText = node.contents[0].displayText
        let contentLabel = Text(contentText)
            .font(.system(size: max(6, 9 * zoomScale)))
            .foregroundColor(.white.opacity(0.8))
        let contentPos = CGPoint(x: screenPos.x, y: screenPos.y + (table.tableLength / 2 + 10) * zoomScale)
        context.draw(contentLabel, at: contentPos, anchor: .center)
    }
    
    private static func drawRegularNodeLabels(
        context: GraphicsContext,
        node: any NodeProtocol,
        screenPos: CGPoint,
        zoomScale: CGFloat
    ) {
        let labelText = Text("\(node.label)")
            .font(.system(size: max(8, 12 * zoomScale), weight: .bold))
            .foregroundColor(.white)
        let labelPos = CGPoint(x: screenPos.x, y: screenPos.y - (node.radius + 12) * zoomScale)
        context.draw(labelText, at: labelPos, anchor: .center)
        
        if !node.contents.isEmpty, zoomScale >= 0.5 {
            let contentText = node.contents[0].displayText
            let contentLabel = Text(contentText)
                .font(.system(size: max(6, 9 * zoomScale)))
                .foregroundColor(.white.opacity(0.8))
            let contentPos = CGPoint(x: screenPos.x, y: screenPos.y + (node.radius + 10) * zoomScale)
            context.draw(contentLabel, at: contentPos, anchor: .center)
        }
    }
    
    // MARK: - Single Node
    static func drawSingleNode(
        renderContext: RenderContext,
        graphicsContext: GraphicsContext,
        node: any NodeProtocol,
        saturation: Double,
        isSelected: Bool,
        isEdgeCreationSource: Bool = false,
        isEdgeCreationTarget: Bool = false,
        tablePosition: CGPoint? = nil,  // If person is seated, this is the table's position
        logger: Logger? = nil
    ) {
        let screenPos = modelToScreen(node.position, renderContext: renderContext)
        
        // For seated person nodes, scale to 24 inches (2 feet) in model space
        // For unattached person nodes, keep original radius of 12 inches
        let effectiveRadius: CGFloat
        if let person = node as? PersonNode, tablePosition != nil {
            // Seated person: 24 inches diameter = 12 inches radius, scaled to table
            effectiveRadius = 12.0
        } else {
            effectiveRadius = node.radius
        }
        let scaledRadius = effectiveRadius * renderContext.zoomScale
        
        #if DEBUG
        if let person = node as? PersonNode {
            print("🎨 Drawing person '\(person.name)': modelRadius=\(node.radius), effectiveRadius=\(effectiveRadius), scaledRadius=\(scaledRadius), zoom=\(renderContext.zoomScale), seated=\(tablePosition != nil)")
        }
        #endif
        
        // Determine border styling
        let (borderWidth, borderColor) = borderStyling(
            isEdgeCreationSource: isEdgeCreationSource,
            isEdgeCreationTarget: isEdgeCreationTarget,
            isSelected: isSelected,
            zoomScale: renderContext.zoomScale
        )
        
        // Apply saturation to fill color
        var fill = node.fillColor
        if saturation < 1.0 {
            fill = desaturatedColor(fill, saturation: saturation)
        }
        
        // Draw node shape
        drawNodeShape(
            context: graphicsContext,
            node: node,
            screenPos: screenPos,
            scaledRadius: scaledRadius,
            fill: fill,
            borderWidth: borderWidth,
            borderColor: borderColor,
            zoomScale: renderContext.zoomScale
        )
        
        // Draw node labels
        drawNodeLabels(
            context: graphicsContext,
            node: node,
            screenPos: screenPos,
            zoomScale: renderContext.zoomScale,
            tablePosition: tablePosition,
            logger: logger
        )
        
        #if DEBUG
        if let logger = logger {
            logger.debug("Drew node \(node.id.uuidString.prefix(8), privacy: .public) at screen (x: \(screenPos.x, privacy: .public), y: \(screenPos.y, privacy: .public)), model (x: \(node.position.x, privacy: .public), y: \(node.position.y, privacy: .public))")
        }
        #endif
    }
    
    // MARK: - Single Edge Line
    static func drawSingleEdgeLine(
        config: EdgeDrawingConfig,
        edge: GraphEdge,
        visibleNodes: [any NodeProtocol]
    ) {
        let renderContext = config.renderContext
        let ctx = config.graphicsContext
        
        guard
            let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
            let toNode = visibleNodes.first(where: { $0.id == edge.target })
        else { return }
        
        let fromScreen = modelToScreen(fromNode.position, renderContext: renderContext)
        let toScreen   = modelToScreen(toNode.position, renderContext: renderContext)
        
        let direction = CGVector(dx: toScreen.x - fromScreen.x, dy: toScreen.y - fromScreen.y)
        let length = hypot(direction.dx, direction.dy)
        guard length > 0 else { return }
        
        let unitDx = direction.dx / length
        let unitDy = direction.dy / length
        
        let fromRadius = fromNode.radius * renderContext.zoomScale
        let toRadius = toNode.radius * renderContext.zoomScale
        
        let start = CGPoint(x: fromScreen.x + unitDx * fromRadius,
                            y: fromScreen.y + unitDy * fromRadius)
        let end   = CGPoint(x: toScreen.x - unitDx * toRadius,
                            y: toScreen.y - unitDy * toRadius)
        
        // Customize styling based on edge type
        let isSpring = edge.type == .spring
        let isPrecedes = edge.type == .precedes
        
        let lineWidth: CGFloat = config.isSelected ? 3.0 : (isSpring ? 1.0 : 1.5)
        let color = desaturatedColor(config.isSelected ? .red : (isSpring ? .gray : .white), saturation: config.saturation)
        let dash: [CGFloat] = (isSpring || isPrecedes) ? [5, 3] : []  // Dashed for springs and precedes edges
        
        let path = Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, dash: dash))
        
        #if DEBUG
        if let logger = config.logger {
            logger.debug("Drew edge \(edge.id.uuidString.prefix(8), privacy: .public) from (x: \(start.x, privacy: .public), y: \(start.y, privacy: .public)) to (x: \(end.x, privacy: .public), y: \(end.y, privacy: .public))")
        }
        #endif
    }
    
    // MARK: - Single Arrowhead
    static func drawSingleArrow(
        config: EdgeDrawingConfig,
        edge: GraphEdge,
        visibleNodes: [any NodeProtocol]
    ) {
        let renderContext = config.renderContext
        let ctx = config.graphicsContext
        
        guard
            let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
            let toNode = visibleNodes.first(where: { $0.id == edge.target })
        else { return }
        
        let fromScreen = modelToScreen(fromNode.position, renderContext: renderContext)
        let toScreen   = modelToScreen(toNode.position, renderContext: renderContext)
        
        let direction = CGVector(dx: toScreen.x - fromScreen.x, dy: toScreen.y - fromScreen.y)
        let length = hypot(direction.dx, direction.dy)
        guard length > 0 else { return }
        
        let unitDx = direction.dx / length
        let unitDy = direction.dy / length
        
        let toRadius = toNode.radius * renderContext.zoomScale
        let boundary = CGPoint(x: toScreen.x - unitDx * toRadius,
                               y: toScreen.y - unitDy * toRadius)
        
        let angle = atan2(unitDy, unitDx)
        let arrowLen: CGFloat = 10.0
        let arrowAngle: CGFloat = .pi / 6
        
        let path1 = CGPoint(x: boundary.x - arrowLen * cos(angle - arrowAngle),
                            y: boundary.y - arrowLen * sin(angle - arrowAngle))
        let path2 = CGPoint(x: boundary.x - arrowLen * cos(angle + arrowAngle),
                            y: boundary.y - arrowLen * sin(angle + arrowAngle))
        
        let path = Path { path in
            path.move(to: boundary); path.addLine(to: path1)
            path.move(to: boundary); path.addLine(to: path2)
        }
        
        let color = desaturatedColor(config.isSelected ? .red : .white, saturation: config.saturation)
        ctx.stroke(path, with: .color(color), lineWidth: 3.0)
        
        #if DEBUG
        if let logger = config.logger {
            logger.debug("Drawing arrow for edge \(edge.id.uuidString.prefix(8), privacy: .public) to boundary x=\(boundary.x, privacy: .public), y=\(boundary.y, privacy: .public)")
        }
        #endif
    }
    // MARK: - Bulk Helpers (unchanged signatures – just forward)
    static func drawEdges(
        renderContext: RenderContext,
        graphicsContext: GraphicsContext,
        visibleEdges: [GraphEdge],
        visibleNodes: [any NodeProtocol],
        saturation: Double,
        isSelected: Bool = false,
        logger: Logger? = nil
    ) {
        for edge in visibleEdges {
            drawSingleEdgeLine(
                config: EdgeDrawingConfig(
                    renderContext: renderContext,
                    graphicsContext: graphicsContext,
                    saturation: saturation,
                    isSelected: isSelected,
                    logger: logger
                ),
                edge: edge,
                visibleNodes: visibleNodes
            )
        }
    }
    
    static func drawArrows(
        renderContext: RenderContext,
        graphicsContext: GraphicsContext,
        visibleEdges: [GraphEdge],
        visibleNodes: [any NodeProtocol],
        saturation: Double,
        isSelected: Bool = false,
        logger: Logger? = nil
    ) {
        for edge in visibleEdges {
            drawSingleArrow(
                config: EdgeDrawingConfig(
                    renderContext: renderContext,
                    graphicsContext: graphicsContext,
                    saturation: saturation,
                    isSelected: isSelected,
                    logger: logger
                ),
                edge: edge,
                visibleNodes: visibleNodes
            )
        }
    }
    
    // MARK: - Bounding Box Overlay (reuses computeBoundingBox)
    static func drawBoundingBox(
        nodes: [any NodeProtocol],
        in context: inout GraphicsContext,
        renderContext: RenderContext
    ) {
        let modelBounds = computeBoundingBox(for: nodes)  // Reuse global shared func (model space)

        guard !modelBounds.isEmpty else { return }

        // Convert model bounds corners to screen space
        let topLeftModel = CGPoint(x: modelBounds.minX, y: modelBounds.minY)
        let bottomRightModel = CGPoint(x: modelBounds.maxX, y: modelBounds.maxY)
        let topLeftScreen = modelToScreen(topLeftModel, renderContext: renderContext)  // Already private static here
        let bottomRightScreen = modelToScreen(bottomRightModel, renderContext: renderContext)  // Ditto

        let screenRect = CGRect(
            x: topLeftScreen.x,
            y: topLeftScreen.y,
            width: bottomRightScreen.x - topLeftScreen.x,
            height: bottomRightScreen.y - topLeftScreen.y
        )

        // Draw dashed overlay (match your BoundingBoxOverlay style)
        let path = Path(roundedRect: screenRect, cornerRadius: 4)
        context.stroke(
            path,
            with: .color(.yellow.opacity(0.5)),
            style: StrokeStyle(lineWidth: 2 * renderContext.zoomScale, dash: [5, 5])
        )
    }
}
