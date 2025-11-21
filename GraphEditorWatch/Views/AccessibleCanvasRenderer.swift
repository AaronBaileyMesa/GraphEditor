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

struct AccessibleCanvasRenderer {
    
    // MARK: - Desaturation Helper (unchanged)
    static func desaturatedColor(_ color: Color, saturation: Double) -> Color {
        switch color {
        case .red:   return Color(hue: 0,          saturation: saturation, brightness: 1)
        case .green: return Color(hue: 120/360.0,  saturation: saturation, brightness: 1)
        case .blue:  return Color(hue: 240/360.0,  saturation: saturation, brightness: 1)
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
        renderContext: RenderContext,                // ← now the shared one
        graphicsContext: GraphicsContext,            // ← passed separately for mutability
        node: any NodeProtocol,
        saturation: Double,
        isSelected: Bool,
        logger: Logger? = nil
    ) {
        let screenPos = modelToScreen(node.position, renderContext: renderContext)
        let scaledRadius = node.radius * renderContext.zoomScale
        let borderWidth: CGFloat = isSelected ? max(3.0, 4 * renderContext.zoomScale) : 1.0
        
        let nodeRect = CGRect(
            x: screenPos.x - scaledRadius,
            y: screenPos.y - scaledRadius,
            width: scaledRadius * 2,
            height: scaledRadius * 2
        ).insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        
        let nodePath = Circle().path(in: nodeRect)
        
        var ctx = graphicsContext
        var fill = node.fillColor
        if saturation < 1.0 {
            fill = desaturatedColor(fill, saturation: saturation)
        }
        ctx.fill(nodePath, with: .color(fill))
        ctx.stroke(nodePath, with: .color(isSelected ? .white : .gray.opacity(0.5)), lineWidth: borderWidth)
        
        // Label
        let labelText = Text("\(node.label)")
            .font(.system(size: max(8, 10 * renderContext.zoomScale)))
            .foregroundStyle(.white)
        ctx.draw(ctx.resolve(labelText), at: screenPos, anchor: .center)
                
        #if DEBUG
        if let logger {
            logger.debug("Drawing node \(node.label) at screen x=\(screenPos.x), y=\(screenPos.y)")
        }
        #endif
    }
    
    // MARK: - Single Edge Line
    static func drawSingleEdgeLine(
        renderContext: RenderContext,
        graphicsContext: GraphicsContext,
        edge: GraphEdge,
        visibleNodes: [any NodeProtocol],
        saturation: Double,
        isSelected: Bool,
        logger: Logger? = nil
    ) {
        guard
            let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
            let toNode = visibleNodes.first(where: { $0.id == edge.target })
        else { return }
        
        let fromScreen = modelToScreen(fromNode.position, renderContext: renderContext)
        let toScreen   = modelToScreen(toNode.position,   renderContext: renderContext)
        
        let dx = toScreen.x - fromScreen.x
        let dy = toScreen.y - fromScreen.y
        let length = hypot(dx, dy)
        guard length > 0 else { return }
        
        let unitDx = dx / length
        let unitDy = dy / length
        
        let fromRadius = fromNode.radius * renderContext.zoomScale
        let toRadius   = toNode.radius   * renderContext.zoomScale
        
        let start = CGPoint(x: fromScreen.x + unitDx * fromRadius,
                            y: fromScreen.y + unitDy * fromRadius)
        let end   = CGPoint(x: toScreen.x   - unitDx * toRadius,
                            y: toScreen.y   - unitDy * toRadius)
        
        let path = Path { $0.move(to: start); $0.addLine(to: end) }
        
        let color = desaturatedColor(isSelected ? .red : .white, saturation: saturation)
        let width: CGFloat = isSelected ? 3.0 : 1.0
        
        graphicsContext.stroke(path, with: .color(color), lineWidth: width)
        
        #if DEBUG
        if let logger {
            logger.debug("Drawing line for edge \(edge.id.uuidString.prefix(8)) from x=\(start.x), y=\(start.y) to x=\(end.x), y=\(end.y)")
        }
        #endif
    }
    
    // MARK: - Single Arrowhead
    static func drawSingleArrow(
        renderContext: RenderContext,
        graphicsContext: GraphicsContext,
        edge: GraphEdge,
        visibleNodes: [any NodeProtocol],
        saturation: Double,
        isSelected: Bool,
        logger: Logger? = nil
    ) {
        guard
            let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
            let toNode = visibleNodes.first(where: { $0.id == edge.target })
        else { return }
        
        let fromScreen = modelToScreen(fromNode.position, renderContext: renderContext)
        let toScreen   = modelToScreen(toNode.position,   renderContext: renderContext)
        
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
        
        let p1 = CGPoint(x: boundary.x - arrowLen * cos(angle - arrowAngle),
                         y: boundary.y - arrowLen * sin(angle - arrowAngle))
        let p2 = CGPoint(x: boundary.x - arrowLen * cos(angle + arrowAngle),
                         y: boundary.y - arrowLen * sin(angle + arrowAngle))
        
        let path = Path { path in
            path.move(to: boundary); path.addLine(to: p1)
            path.move(to: boundary); path.addLine(to: p2)
        }
        
        let color = desaturatedColor(isSelected ? .red : .white, saturation: saturation)
        graphicsContext.stroke(path, with: .color(color), lineWidth: 3.0)
        
        #if DEBUG
        if let logger {
            logger.debug("Drawing arrow for edge \(edge.id.uuidString.prefix(8)) to boundary x=\(boundary.x), y=\(boundary.y)")
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
            drawSingleEdgeLine(renderContext: renderContext,
                               graphicsContext: graphicsContext,
                               edge: edge,
                               visibleNodes: visibleNodes,
                               saturation: saturation,
                               isSelected: isSelected,
                               logger: logger)
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
            drawSingleArrow(renderContext: renderContext,
                            graphicsContext: graphicsContext,
                            edge: edge,
                            visibleNodes: visibleNodes,
                            saturation: saturation,
                            isSelected: isSelected,
                            logger: logger)
        }
    }
}
