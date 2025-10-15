//
//  FocusableView.swift
//  GraphEditor
//
//  Created by handcart on 10/14/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared
import os  // Added for logging

struct FocusableView<Content: View>: View {
    private static var logger: Logger {
        Logger(subsystem: "io.handcart.GraphEditor", category: "focusableview")  // Changed to computed static
    }
    
    let content: Content
    @FocusState private var isFocused: Bool
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .id("CrownFocusableCanvas")
            .focused($isFocused)
            .onAppear {
                isFocused = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true  // Double-focus for WatchOS reliability
                }
            }
            .onChange(of: isFocused) { oldValue, newValue in
                #if DEBUG
                Self.logger.debug("Canvas focus changed: from \(oldValue) to \(newValue)")
                #endif
                
                if !newValue {
                    isFocused = true  // Auto-recover focus loss
                }
            }
    }
}

struct BoundingBoxOverlay: View {
    let viewModel: GraphViewModel
    let zoomScale: CGFloat
    let offset: CGSize
    let viewSize: CGSize
    
    var body: some View {
        let graphBounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.nodes)
        let minScreen = CoordinateTransformer.modelToScreen(
            CGPoint(x: graphBounds.minX, y: graphBounds.minY),
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: viewSize
        )
        let maxScreen = CoordinateTransformer.modelToScreen(
            CGPoint(x: graphBounds.maxX, y: graphBounds.maxY),
            effectiveCentroid: viewModel.effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: viewSize
        )
        let scaledBounds = CGRect(x: minScreen.x, y: minScreen.y, width: maxScreen.x - minScreen.x, height: maxScreen.y - minScreen.y)
        Rectangle()
            .stroke(Color.blue, lineWidth: 2)
            .frame(width: scaledBounds.width, height: scaledBounds.height)
            .position(x: scaledBounds.midX, y: scaledBounds.midY)
            .opacity(0.5)
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
                
                // NEW: Compute selected/non-selected sets
                let nonSelectedNodes = visibleNodes.filter { $0.id != selectedNodeID }
                let selectedNode = visibleNodes.first { $0.id == selectedNodeID }
                let nonSelectedEdges = visibleEdges.filter { $0.id != selectedEdgeID }
                let selectedEdge = visibleEdges.first { $0.id == selectedEdgeID }
                
                // Draw non-selected edges (lines) with desaturated color
                drawEdges(in: context, size: size, visibleEdges: nonSelectedEdges, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid, saturation: saturation, isSelected: false)
                
                // Draw selected edge (line) with full color if any
                if let edge = selectedEdge {
                    drawSingleEdgeLine(in: context, size: size, edge: edge, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid, saturation: 1.0, isSelected: true)
                }
                
                // Draw non-selected nodes with desaturated color
                for node in nonSelectedNodes {
                    drawSingleNode(in: context, size: size, node: node, effectiveCentroid: effectiveCentroid, saturation: saturation, isSelected: false)
                }
                
                // Draw selected node with full color if any
                if let node = selectedNode {
                    drawSingleNode(in: context, size: size, node: node, effectiveCentroid: effectiveCentroid, saturation: 1.0, isSelected: true)
                }
                
                // Draw non-selected arrows with desaturated color
                drawArrows(in: context, size: size, visibleEdges: nonSelectedEdges, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid, saturation: saturation, isSelected: false)
                
                // Draw selected arrow with full color if any
                if let edge = selectedEdge {
                    drawSingleArrow(in: context, size: size, edge: edge, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid, saturation: 1.0, isSelected: true)
                }
                
                // Draw dragged node and potential edge (keep full color)
                drawDraggedNodeAndPotentialEdge(in: context, size: size, effectiveCentroid: effectiveCentroid)
            }
            
            if showOverlays {
                BoundingBoxOverlay(viewModel: viewModel, zoomScale: zoomScale, offset: offset, viewSize: viewSize)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(graphAccessibilityLabel())
        .accessibilityHint("Double tap to select node or edge. Long press for menu.")
        .accessibilityAddTraits(.isButton)  // Makes it tappable for VoiceOver
    }
    
    private func graphAccessibilityLabel() -> String {
        let nodeCount = viewModel.model.nodes.count
        let edgeCount = viewModel.model.edges.count
        let selectedNodeLabel = selectedNodeID.flatMap { id in viewModel.model.nodes.first { $0.id == id }?.label }?.map { "Node \($0) selected." } ?? ""
        let selectedEdgeLabel = selectedEdgeID.flatMap { id in viewModel.model.edges.first { $0.id == id } }.map { edge in
            let fromLabel = viewModel.model.nodes.first { $0.id == edge.from }?.label ?? 0
            let toLabel = viewModel.model.nodes.first { $0.id == edge.target }?.label ?? 0
            return "Edge from \(fromLabel) to \(toLabel) selected."
        } ?? ""
        let selectionInfo = selectedNodeLabel + selectedEdgeLabel
        let defaultInfo = selectionInfo.isEmpty ? "No node or edge selected." : ""
        return "Graph with \(nodeCount) nodes and \(edgeCount) edges. \(selectionInfo)\(defaultInfo)"
    }
    
    // Helper to desaturate a color
    private func desaturatedColor(_ color: Color, saturation: Double) -> Color {
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).getHue(&hue, saturation: &sat, brightness: &brightness, alpha: &alpha)
        return Color(hue: Double(hue), saturation: saturation * Double(sat), brightness: Double(brightness), opacity: Double(alpha))
    }
    
    // NEW: Updated single node draw with saturation param
    private func drawSingleNode(in context: GraphicsContext, size: CGSize, node: any NodeProtocol, effectiveCentroid: CGPoint, saturation: Double, isSelected: Bool) {
        let nodeScreen = CoordinateTransformer.modelToScreen(
            node.position,
            effectiveCentroid: effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: size
        )
        let nodeRadius = Constants.App.nodeModelRadius * zoomScale
        
        let baseColor: Color = isSelected ? .red : .blue
        let nodeColor = desaturatedColor(baseColor, saturation: saturation)
        let nodePath = Circle().path(in: CGRect(center: nodeScreen, size: CGSize(width: nodeRadius * 2, height: nodeRadius * 2)))
        context.fill(nodePath, with: .color(nodeColor))
        
        // Draw label with desaturated color
        let labelColor = desaturatedColor(.black, saturation: saturation)  // Assuming labels are black; adjust if needed
        let labelText = Text("\(node.label)").foregroundColor(labelColor).font(.system(size: 12 * zoomScale))
        context.draw(labelText, at: nodeScreen, anchor: .center)
    }
    
    // NEW: Updated single edge line draw with saturation param
    private func drawSingleEdgeLine(in context: GraphicsContext, size: CGSize, edge: GraphEdge, visibleNodes: [any NodeProtocol], effectiveCentroid: CGPoint, saturation: Double, isSelected: Bool) {
        guard let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
              let toNode = visibleNodes.first(where: { $0.id == edge.target }) else { return }
        
        let fromScreen = CoordinateTransformer.modelToScreen(
            fromNode.position,
            effectiveCentroid: effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: size
        )
        let toScreen = CoordinateTransformer.modelToScreen(
            toNode.position,
            effectiveCentroid: effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: size
        )
        
        let linePath = Path { path in
            path.move(to: fromScreen)
            path.addLine(to: toScreen)
        }
        
        let baseColor: Color = isSelected ? .red : .gray
        let edgeColor = desaturatedColor(baseColor, saturation: saturation)
        let lineWidth: CGFloat = 2.0
        
        context.stroke(linePath, with: .color(edgeColor), lineWidth: lineWidth)
        
        #if DEBUG
        Self.logger.debug("Drawing edge from x=\(fromScreen.x), y=\(fromScreen.y) to x=\(toScreen.x), y=\(toScreen.y) with color \(edgeColor.description)")
        #endif
    }
    
    // NEW: Updated single arrow draw with saturation param
    private func drawSingleArrow(in context: GraphicsContext, size: CGSize, edge: GraphEdge, visibleNodes: [any NodeProtocol], effectiveCentroid: CGPoint, saturation: Double, isSelected: Bool) {
        guard let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
              let toNode = visibleNodes.first(where: { $0.id == edge.target }) else { return }
        
        let fromScreen = CoordinateTransformer.modelToScreen(
            fromNode.position,
            effectiveCentroid: effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: size
        )
        let toScreen = CoordinateTransformer.modelToScreen(
            toNode.position,
            effectiveCentroid: effectiveCentroid,
            zoomScale: zoomScale,
            offset: offset,
            viewSize: size
        )
        
        let direction = CGVector(dx: toScreen.x - fromScreen.x, dy: toScreen.y - fromScreen.y)
        let length = hypot(direction.dx, direction.dy)
        if length <= 0 { return }
        
        let unitDx = direction.dx / length
        let unitDy = direction.dy / length
        let toRadiusScreen = toNode.radius * zoomScale
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
        
        let baseColor: Color = isSelected ? .red : .gray
        let arrowColor = desaturatedColor(baseColor, saturation: saturation)
        let arrowLineWidth: CGFloat = 3.0
        
        context.stroke(arrowPath, with: .color(arrowColor), lineWidth: arrowLineWidth)
        
        #if DEBUG
        Self.logger.debug("Drawing arrow for edge \(edge.id.uuidString.prefix(8)) to boundary x=\(boundaryPoint.x), y=\(boundaryPoint.y)")
        #endif
    }
    
    // Updated drawEdges to accept saturation and isSelected
    private func drawEdges(in context: GraphicsContext, size: CGSize, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], effectiveCentroid: CGPoint, saturation: Double, isSelected: Bool) {
        for edge in visibleEdges {
            drawSingleEdgeLine(in: context, size: size, edge: edge, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid, saturation: saturation, isSelected: isSelected)
        }
    }
    
    // Updated drawArrows to accept saturation and isSelected
    private func drawArrows(in context: GraphicsContext, size: CGSize, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], effectiveCentroid: CGPoint, saturation: Double, isSelected: Bool) {
        for edge in visibleEdges {
            drawSingleArrow(in: context, size: size, edge: edge, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid, saturation: saturation, isSelected: isSelected)
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

struct Line: Shape, Animatable {
    var from: CGPoint
    var end: CGPoint
    
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(from.animatableData, end.animatableData) }
        set {
            from.animatableData = newValue.first
            end.animatableData = newValue.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        path.addLine(to: end)
        return path
    }
}

extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }
}
