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
    // swiftlint:disable:next function_parameter_count
    private static func drawNodeShape(
        context: GraphicsContext,
        node: any NodeProtocol,
        screenPos: CGPoint,
        scaledRadius: CGFloat,
        fill: Color,
        borderWidth: CGFloat,
        borderColor: Color,
        zoomScale: CGFloat,
        isSelected: Bool
    ) {
        // NEW: Use node's type descriptor renderer for shape drawing
        // This eliminates type-casting and enables declarative rendering configuration
        var mutableContext = context
        node.typeDescriptor.renderer.renderShape(
            context: &mutableContext,
            node: node,
            screenPosition: screenPos,
            zoomScale: zoomScale,
            isSelected: isSelected
        )
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
        isInGrid: Bool = false,  // If person is in a PeopleListNode grid
        gridPosition: (row: Int, col: Int)? = nil,  // Grid position for staggered labels
        logger: Logger? = nil
    ) {
        let screenPos = modelToScreen(node.position, renderContext: renderContext)
        
        // For seated person nodes, scale to 24 inches (2 feet) in model space
        // For unattached person nodes, keep original radius of 12 inches
        let effectiveRadius: CGFloat
        if node is PersonNode, tablePosition != nil {
            // Seated person: 24 inches diameter = 12 inches radius, scaled to table
            effectiveRadius = 12.0
        } else {
            effectiveRadius = node.radius
        }
        let scaledRadius = effectiveRadius * renderContext.zoomScale
        

        
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
            zoomScale: renderContext.zoomScale,
            isSelected: isSelected
        )
        
        // Draw node labels
        drawNodeLabels(
            context: graphicsContext,
            node: node,
            screenPos: screenPos,
            zoomScale: renderContext.zoomScale,
            tablePosition: tablePosition,
            isInGrid: isInGrid,
            gridPosition: gridPosition,
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
        
        // Filter out hierarchy edges between PeopleListNode and PersonNode
        // These create visual clutter; grid layout provides sufficient visual grouping
        if edge.type == .hierarchy {
            let fromIsPeopleList = fromNode is PeopleListNode
            let toIsPerson = toNode is PersonNode
            let fromIsPerson = fromNode is PersonNode
            let toIsPeopleList = toNode is PeopleListNode
            
            if (fromIsPeopleList && toIsPerson) || (fromIsPerson && toIsPeopleList) {
                return  // Skip rendering this edge
            }
        }
        
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
        
        // Filter out hierarchy edges between PeopleListNode and PersonNode (same as line drawing)
        if edge.type == .hierarchy {
            let fromIsPeopleList = fromNode is PeopleListNode
            let toIsPerson = toNode is PersonNode
            let fromIsPerson = fromNode is PersonNode
            let toIsPeopleList = toNode is PeopleListNode
            
            if (fromIsPeopleList && toIsPerson) || (fromIsPerson && toIsPeopleList) {
                return  // Skip rendering this arrow
            }
        }
        
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
    
    // MARK: - Table Seat Indicators

    /// Draws seat position indicators around a table on the canvas.
    /// Empty seats show as outline circles; occupied seats show the person's avatar (photo or fill color).
    static func drawTableSeatIndicators(
        renderContext: RenderContext,
        graphicsContext: GraphicsContext,
        table: TableNode,
        allNodes: [AnyNode]
    ) {
        let tableScreenPos = modelToScreen(table.position, renderContext: renderContext)
        let zoom = renderContext.zoomScale

        // Person nodes at a table are rendered at 12pt model radius (24pt diameter)
        let personModelRadius: CGFloat = 12.0
        let personScreenRadius = personModelRadius * zoom

        // Only draw if seats would be visible at this zoom level
        guard personScreenRadius >= 3.0 else { return }

        for seatIndex in 0..<table.totalSeats {
            let offset = table.seatOffset(for: seatIndex)
            let seatScreenPos = CGPoint(
                x: tableScreenPos.x + offset.x * zoom,
                y: tableScreenPos.y + offset.y * zoom
            )

            if let personID = table.seatingAssignments[seatIndex],
               let personNode = allNodes.first(where: { $0.id == personID })?.unwrapped as? PersonNode {
                // Occupied seat: draw filled circle with person's fill color, then monogram/icon
                let seatRect = CGRect(
                    x: seatScreenPos.x - personScreenRadius,
                    y: seatScreenPos.y - personScreenRadius,
                    width: personScreenRadius * 2,
                    height: personScreenRadius * 2
                )
                let seatPath = Path(ellipseIn: seatRect)
                graphicsContext.fill(seatPath, with: .color(personNode.fillColor))
                graphicsContext.stroke(seatPath, with: .color(.white.opacity(0.6)), lineWidth: max(1.0, zoom))

                // Draw person name initial as monogram if zoom allows
                if zoom >= 0.4 {
                    let name = personNode.name
                    let initial = name.isEmpty ? "?" : String(name.prefix(1)).uppercased()
                    let fontSize = max(5.0, personScreenRadius * 0.85)
                    let monogram = Text(initial)
                        .font(.system(size: fontSize, weight: .semibold))
                        .foregroundColor(.white)
                    graphicsContext.draw(monogram, at: seatScreenPos, anchor: .center)
                }
            } else {
                // Empty seat: outline circle only
                let seatRect = CGRect(
                    x: seatScreenPos.x - personScreenRadius,
                    y: seatScreenPos.y - personScreenRadius,
                    width: personScreenRadius * 2,
                    height: personScreenRadius * 2
                )
                let seatPath = Path(ellipseIn: seatRect)
                graphicsContext.stroke(
                    seatPath,
                    with: .color(.white.opacity(0.35)),
                    style: StrokeStyle(lineWidth: max(1.0, zoom), dash: [3, 3])
                )
            }
        }
    }

    // MARK: - Table Background for PeopleListNode
    /// Draws a colored rectangle background behind PersonNode table when PeopleListNode is expanded
    /// Also highlights the row of the selected node if provided
    static func drawGridBackgrounds(
        renderContext: RenderContext,
        graphicsContext: GraphicsContext,
        nodes: [any NodeProtocol],
        selectedNodeID: NodeID? = nil
    ) {
        for node in nodes {
            guard let peopleList = node as? PeopleListNode,
                  peopleList.isExpanded,
                  !peopleList.children.isEmpty else {
                continue
            }
            
            // Table parameters (must match PeopleListNodeDescriptor)
            let rowHeight: CGFloat = 28.0  // Compact row spacing
            let offsetFromParent = CGPoint(x: -60, y: 50)  // Shifted right with extra margin for selection stroke
            
            // Find all PersonNodes in this list to measure their labels
            let personNodes = nodes.compactMap { n -> (NodeID, String)? in
                guard let person = n as? PersonNode,
                      peopleList.children.contains(person.id),
                      !person.contents.isEmpty else {
                    return nil
                }
                return (person.id, person.contents[0].displayText)
            }
            
            // Calculate max label width - very generous estimation to avoid truncation
            let fontSize: CGFloat = 11.0  // Must match label font size
            var maxLabelWidth: CGFloat = 100.0  // Minimum width
            
            for (_, name) in personNodes {
                // Very generous estimate to prevent truncation
                // SF font at 11pt needs ~6.5-7pt per character on average for mixed case
                // Use 8pt per character to ensure no truncation even for wide letters (W, M, etc)
                let estimatedWidth = CGFloat(name.count) * 8.0
                maxLabelWidth = max(maxLabelWidth, estimatedWidth)
            }
            
            // Table dimensions - reduced padding for snug fit
            let iconWidth: CGFloat = 24.0  // Node circle diameter
            let iconLabelSpacing: CGFloat = 8.0  // Reduced spacing
            let horizontalPadding: CGFloat = 8.0  // Reduced padding for snug fit
            let verticalPadding: CGFloat = 4.0  // Minimal padding
            
            let rectWidth = horizontalPadding + iconWidth + iconLabelSpacing + maxLabelWidth + horizontalPadding
            
            // Get actual nodes to use their positions (set by VerticalListConstraint during physics)
            let childNodes = peopleList.children.compactMap { childID in
                nodes.first(where: { $0.id == childID })
            }
            
            guard let firstNode = childNodes.first,
                  let lastNode = childNodes.last else {
                continue
            }
            
            // Use actual node positions from constraint system
            let firstNodeCenterY = firstNode.position.y
            let lastNodeCenterY = lastNode.position.y
            let nodeRadius = firstNode.radius
            
            // Content bounds must accommodate the full node circles
            // Use max(nodeRadius, rowHeight/2) to handle both small and large nodes
            let verticalExtent = max(nodeRadius, rowHeight / 2)
            let contentTopY = firstNodeCenterY - verticalExtent
            let contentBottomY = lastNodeCenterY + verticalExtent
            let contentHeight = contentBottomY - contentTopY
            
            // Rectangle dimensions with padding
            let rectHeight = contentHeight + verticalPadding * 2
            
            // Calculate table position (top-left aligned)
            // Use actual first node X position (all nodes should have same X from VerticalListConstraint)
            let rectModelTopLeft = CGPoint(
                x: firstNode.position.x - horizontalPadding,
                y: contentTopY - verticalPadding
            )
            

            let rectScreenTopLeft = modelToScreen(rectModelTopLeft, renderContext: renderContext)
            
            // Convert size to screen space
            let rectScreenWidth = rectWidth * renderContext.zoomScale
            let rectScreenHeight = rectHeight * renderContext.zoomScale
            
            let rectScreen = CGRect(
                x: rectScreenTopLeft.x,
                y: rectScreenTopLeft.y,
                width: rectScreenWidth,
                height: rectScreenHeight
            )
            

            
            // Draw rounded rectangle with semi-transparent blue fill
            let path = Path(roundedRect: rectScreen, cornerRadius: 12 * renderContext.zoomScale)
            graphicsContext.fill(path, with: .color(Color.blue.opacity(0.15)))
            
            // Optional: Add a subtle border
            graphicsContext.stroke(
                path,
                with: .color(Color.blue.opacity(0.3)),
                lineWidth: max(1.0, 1.5 * renderContext.zoomScale)
            )
            
            // Draw row highlight for selected PersonNode
            if let selectedID = selectedNodeID,
               let selectedNode = childNodes.first(where: { $0.id == selectedID }) {
                // Use actual node position from constraint system
                let nodeY = selectedNode.position.y
                
                // Calculate row box that's centered on the node
                let rowModelTopLeft = CGPoint(
                    x: selectedNode.position.x - horizontalPadding,
                    y: nodeY - rowHeight / 2
                )
                let rowScreenTopLeft = modelToScreen(rowModelTopLeft, renderContext: renderContext)
                
                let rowRect = CGRect(
                    x: rowScreenTopLeft.x,
                    y: rowScreenTopLeft.y,
                    width: rectScreenWidth,
                    height: rowHeight * renderContext.zoomScale
                )
                
                // Draw highlighted row with rounded corners
                let rowPath = Path(roundedRect: rowRect, cornerRadius: 8 * renderContext.zoomScale)
                graphicsContext.fill(rowPath, with: .color(Color.white.opacity(0.2)))
                graphicsContext.stroke(
                    rowPath,
                    with: .color(Color.white.opacity(0.5)),
                    lineWidth: max(1.0, 2.0 * renderContext.zoomScale)
                )
            }
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
