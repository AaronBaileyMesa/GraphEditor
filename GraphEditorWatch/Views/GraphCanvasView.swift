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
    
    private var canvasBase: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: min(viewSize.width, viewSize.height) * 0.4,
                       height: min(viewSize.width, viewSize.height) * 0.4)
                .position(x: viewSize.width / 2, y: viewSize.height / 2)
            
            Canvas { context, size in
                let transform = CGAffineTransform(scaleX: zoomScale, y: zoomScale).translatedBy(x: offset.width, y: offset.height)
                
                for edge in viewModel.model.visibleEdges() {
                    if let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                       let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                        let fromPos = (draggedNode?.id == fromNode.id ? CGPoint(x: fromNode.position.x + dragOffset.x, y: fromNode.position.y + dragOffset.y) : fromNode.position).applying(transform)
                        let toPos = (draggedNode?.id == toNode.id ? CGPoint(x: toNode.position.x + dragOffset.x, y: toNode.position.y + dragOffset.y) : toNode.position).applying(transform)
                        
                        let direction = CGPoint(x: toPos.x - fromPos.x, y: toPos.y - fromPos.y)
                        let length = hypot(direction.x, direction.y)
                        if length > 0 {
                            let unitDir = CGPoint(x: direction.x / length, y: direction.y / length)
                            let scaledToRadius = toNode.radius * zoomScale
                            let lineEnd = toPos - unitDir * scaledToRadius
                            
                            let isSelected = edge.id == selectedEdgeID
                            let lineWidth = isSelected ? 4 * zoomScale : 2 * zoomScale
                            let color = isSelected ? Color.red : Color.blue
                            
                            context.stroke(Path { path in
                                path.move(to: fromPos)
                                path.addLine(to: lineEnd)
                            }, with: .color(color), lineWidth: lineWidth)
                            
                            let arrowSize: CGFloat = 10 * zoomScale
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
                        
                        let midpoint = CGPoint(x: (fromPos.x + toPos.x) / 2, y: (fromPos.y + toPos.y) / 2)
                        let edgeLabel = "\(fromNode.label)→\(toNode.label)"
                        let fontSize = UIFontMetrics.default.scaledValue(for: 12) * zoomScale
                        let text = Text(edgeLabel).foregroundColor(.white).font(.system(size: fontSize))
                        let resolvedText = context.resolve(text)
                        context.draw(resolvedText, at: midpoint, anchor: .center)
                    }
                }
                
                if let dragged = draggedNode, let target = potentialEdgeTarget {
                    let fromPos = CGPoint(x: dragged.position.x + dragOffset.x, y: dragged.position.y + dragOffset.y).applying(transform)
                    let toPos = target.position.applying(transform)
                    context.stroke(Path { path in
                        path.move(to: fromPos)
                        path.addLine(to: toPos)
                    }, with: .color(.green), style: StrokeStyle(lineWidth: 2 * zoomScale, dash: [5 * zoomScale]))
                }
                
                for node in viewModel.model.visibleNodes() {
                    let isDragged = draggedNode?.id == node.id
                    let worldPos = isDragged ? CGPoint(x: node.position.x + dragOffset.x, y: node.position.y + dragOffset.y) : node.position
                    let screenPos = worldPos.applying(transform)
                    let isSelected = node.id == selectedNodeID
                    
                    node.draw(in: context, at: screenPos, zoomScale: zoomScale, isSelected: isSelected)
                }
            }
            .drawingGroup()
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
