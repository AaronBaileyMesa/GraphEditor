//
//  GraphCanvasView.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//

import SwiftUI
import WatchKit
import GraphEditorShared

struct GraphCanvasView: View {
    let viewModel: GraphViewModel
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize
    @Binding var draggedNode: (any NodeProtocol)?
    @Binding var dragOffset: CGPoint
    @Binding var potentialEdgeTarget: (any NodeProtocol)?
    @Binding var selectedNodeID: NodeID?
    let viewSize: CGSize
    @Binding var panStartOffset: CGSize?
    @Binding var showMenu: Bool
    let maxZoom: CGFloat
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    @State private var previousZoomScale: CGFloat = 1.0
    @State private var zoomTimer: Timer? = nil
    @Binding var selectedEdgeID: UUID?
    @Binding var showOverlays: Bool  // New binding for overlays
    
    private var canvasBase: some View {
        let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        let panOffset = CGPoint(x: offset.width, y: offset.height)
        let visibleNodes = viewModel.model.visibleNodes()
        
        var effectiveCentroid = visibleNodes.centroid() ?? .zero
        if let selectedID = selectedNodeID, let selected = visibleNodes.first(where: { $0.id == selectedID }) {
            effectiveCentroid = selected.position
        } else if let selectedEdge = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdge }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }), let to = visibleNodes.first(where: { $0.id == edge.to }) {
            effectiveCentroid = (from.position + to.position) / 2.0
        }
        
        return ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: min(viewSize.width, viewSize.height) * 0.4,
                       height: min(viewSize.width, viewSize.height) * 0.4)
                .position(viewCenter)
            
            Canvas { context, size in
                for edge in viewModel.model.visibleEdges() {
                    if let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                       let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                        let fromPos = (draggedNode?.id == fromNode.id ? CGPoint(x: fromNode.position.x + dragOffset.x, y: fromNode.position.y + dragOffset.y) : fromNode.position)
                        let toPos = (draggedNode?.id == toNode.id ? CGPoint(x: toNode.position.x + dragOffset.x, y: toNode.position.y + dragOffset.y) : toNode.position)
                        
                        let fromDisplay = (fromPos - effectiveCentroid) * zoomScale + viewCenter + panOffset
                        let toDisplay = (toPos - effectiveCentroid) * zoomScale + viewCenter + panOffset
                        
                        let direction = toDisplay - fromDisplay
                        let length = hypot(direction.x, direction.y)
                        if length > 0 {
                            let unitDir = direction / length
                            let scaledToRadius = toNode.radius * zoomScale
                            let lineEnd = toDisplay - unitDir * scaledToRadius
                            
                            let isSelected = edge.id == selectedEdgeID
                            let lineWidth = isSelected ? 4.0 : 2.0
                            let color = isSelected ? Color.red : Color.blue
                            
                            context.stroke(Path { path in
                                path.move(to: fromDisplay)
                                path.addLine(to: lineEnd)
                            }, with: .color(color), lineWidth: lineWidth)
                            
                            let arrowSize: CGFloat = 10.0
                            let perpDir = CGPoint(x: -unitDir.y, y: unitDir.x)
                            let arrowTip = lineEnd
                            let arrowBase1 = arrowTip - unitDir * arrowSize + perpDir * (arrowSize / 2)
                            let arrowBase2 = arrowTip - unitDir * arrowSize - perpDir * (arrowSize / 2)
                            
                            context.fill(Path { path in
                                path.move(to: arrowTip)
                                path.addLine(to: arrowBase1)
                                path.addLine(to: arrowBase2)
                                path.closeSubpath()
                            }, with: .color(color))
                        }
                        
                        let midpoint = (fromDisplay + toDisplay) / 2
                        let edgeLabel = "\(fromNode.label)→\(toNode.label)"
                        let fontSize = UIFontMetrics.default.scaledValue(for: 12)
                        let text = Text(edgeLabel).foregroundColor(.white).font(.system(size: fontSize))
                        let resolvedText = context.resolve(text)
                        context.draw(resolvedText, at: midpoint, anchor: .center)
                    }
                }
                
                if let dragged = draggedNode, let target = potentialEdgeTarget {
                    let fromPos = dragged.position + dragOffset
                    let toPos = target.position
                    let fromDisplay = (fromPos - effectiveCentroid) * zoomScale + viewCenter + panOffset
                    let toDisplay = (toPos - effectiveCentroid) * zoomScale + viewCenter + panOffset
                    context.stroke(Path { path in
                        path.move(to: fromDisplay)
                        path.addLine(to: toDisplay)
                    }, with: .color(.green), style: StrokeStyle(lineWidth: 2.0, dash: [5.0]))
                }
                
                for node in visibleNodes {
                    let isDragged = draggedNode?.id == node.id
                    let worldPos = isDragged ? node.position + dragOffset : node.position
                    let relative = worldPos - effectiveCentroid
                    let scaled = relative * zoomScale
                    let displayPos = scaled + viewCenter + panOffset
                    let isSelected = node.id == selectedNodeID
                    
                    node.draw(in: context, at: displayPos, zoomScale: zoomScale, isSelected: isSelected)
                }
            }
            .drawingGroup()  // Moved here, attached to Canvas
            
            if showOverlays {
                if !visibleNodes.isEmpty {
                    // Compute model BBox (reuse existing method)
                    let modelBBox = viewModel.model.boundingBox()
                    
                    // Compute relative corners (to effectiveCentroid)
                    let minRel = CGPoint(x: modelBBox.minX, y: modelBBox.minY) - effectiveCentroid
                    let maxRel = CGPoint(x: modelBBox.maxX, y: modelBBox.maxY) - effectiveCentroid
                    
                    // Scale and position on screen
                    let minDisplay = minRel * zoomScale + viewCenter + panOffset
                    let maxDisplay = maxRel * zoomScale + viewCenter + panOffset
                    
                    let displayWidth = maxDisplay.x - minDisplay.x
                    let displayHeight = maxDisplay.y - minDisplay.y
                    let displayCenter = CGPoint(x: minDisplay.x + displayWidth / 2, y: minDisplay.y + displayHeight / 2)
                    
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 1.0)  // Keep thin, unscaled
                        .frame(width: displayWidth, height: displayHeight)
                        .position(displayCenter)
                }
                
                if let centroid = visibleNodes.centroid() {
                    let relative = centroid - effectiveCentroid  // Adjust for effective
                    let scaled = relative * zoomScale
                    let displayPos = scaled + viewCenter + panOffset
                    
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 4, height: 4)
                        .position(displayPos)
                }
            }
        }
    }
    
    private var interactiveCanvas: some View {
        canvasBase
    }
    
    private var accessibleCanvas: some View {
        interactiveCanvas
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.model.graphDescription(selectedID: selectedNodeID, selectedEdgeID: selectedEdgeID))
            .accessibilityHint("Long press for menu. Tap to select.")
            .accessibilityChildren {
                ForEach(viewModel.model.visibleNodes(), id: \.id) { node in
                    Text("Node \(node.label) at (\(Int(node.position.x)), \(Int(node.position.y)))")
                        .accessibilityAction(named: "Select") {
                            selectedNodeID = node.id
                            WKInterfaceDevice.current().play(.click)
                        }
                }
            }
    }
    
    var body: some View {
        accessibleCanvas
            .modifier(GraphGesturesModifier(
                viewModel: viewModel,
                zoomScale: $zoomScale,
                offset: $offset,
                draggedNode: $draggedNode,
                dragOffset: $dragOffset,
                potentialEdgeTarget: $potentialEdgeTarget,
                selectedNodeID: $selectedNodeID,
                selectedEdgeID: $selectedEdgeID,
                viewSize: viewSize,
                panStartOffset: $panStartOffset,
                showMenu: $showMenu,
                maxZoom: maxZoom,
                crownPosition: $crownPosition,
                onUpdateZoomRanges: onUpdateZoomRanges
            ))
    }
}

extension Array where Element == any NodeProtocol {
    func centroid() -> CGPoint? {
        guard !isEmpty else { return nil }
        var totalX: CGFloat = 0.0
        var totalY: CGFloat = 0.0
        for node in self {
            totalX += node.position.x
            totalY += node.position.y
        }
        return CGPoint(x: totalX / CGFloat(count), y: totalY / CGFloat(count))
    }
}
