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
    
    // MARK: - Single Node
    static func drawSingleNode(
        renderContext: RenderContext,
        graphicsContext: GraphicsContext,
        node: any NodeProtocol,
        saturation: Double,
        isSelected: Bool,
        logger: Logger? = nil
    ) {
        let screenPos = modelToScreen(node.position, renderContext: renderContext)
        let scaledRadius = node.radius * renderContext.zoomScale  // Assume ControlNode has smaller radius
        let borderWidth: CGFloat = isSelected ? max(3.0, 4 * renderContext.zoomScale) : 1.0
        
        let nodeRect = CGRect(
            x: screenPos.x - scaledRadius,
            y: screenPos.y - scaledRadius,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        ).insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        
        let nodePath = Circle().path(in: nodeRect)
        
        let ctx = graphicsContext
        var fill = node.fillColor
        if saturation < 1.0 {
            fill = desaturatedColor(fill, saturation: saturation)
        }
        ctx.fill(nodePath, with: .color(fill))
        ctx.stroke(nodePath, with: .color(isSelected ? .white : .gray.opacity(0.5)), lineWidth: borderWidth)
        
        // NEW: Handle ControlNode (no label, add icon)
        if let control = node as? ControlNode {
            let iconSize = max(8.0, 12.0 * renderContext.zoomScale)
            let iconRect = CGRect(
                x: screenPos.x - iconSize / 2,
                y: screenPos.y - iconSize / 2,
                width: iconSize,
                height: iconSize
            )
            
            let icon = Image(systemName: control.kind.systemImage)  // Plain Image (systemName only)
            
            ctx.drawLayer { layer in
                layer.addFilter(.colorMultiply(.white))  // Apply white tint
                layer.draw(icon, in: iconRect)           // Draw sized in rect
            }  // No need for removeFilter() – it's scoped to the layer
            
            #if DEBUG
            logger?.debug("Drew control node icon '\(control.kind.systemImage)' at (x: \(screenPos.x, privacy: .public), y: \(screenPos.y, privacy: .public))")
            #endif
        } else {
            // Existing label for regular nodes
            let labelText = Text("\(node.label)")
                .font(.system(size: max(8, 12 * renderContext.zoomScale), weight: .bold))
                .foregroundColor(.white)
            let labelPos = CGPoint(x: screenPos.x, y: screenPos.y - (node.radius + 12) * renderContext.zoomScale)
            ctx.draw(labelText, at: labelPos, anchor: .center)
            
            // Existing +/- for ToggleNode
            if let toggleNode = node as? ToggleNode {
                var chevronContext = ctx
                drawFloatingChevron(
                    at: screenPos,
                    isExpanded: toggleNode.isExpanded,
                    in: &chevronContext,
                    zoomScale: renderContext.zoomScale
                )
            }
        }
        
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
        
        // NEW: Customize for spring edges (dashed, thinner, gray)
        let isSpring = edge.type == .spring  // Assume .spring in EdgeType
        let lineWidth: CGFloat = config.isSelected ? 3.0 : (isSpring ? 1.0 : 1.5)
        let color = desaturatedColor(config.isSelected ? .red : (isSpring ? .gray : .white), saturation: config.saturation)
        let dash: [CGFloat] = isSpring ? [5, 3] : []  // Dashed for springs
        
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
}

