//
//  GraphCanvasView.swift
//  GraphEditor
//
//  Created by handcart on 8/1/25.
//


// Views/GraphCanvasView.swift
import SwiftUI
import WatchKit
import GraphEditorShared

struct GraphCanvasView: View {
    let viewModel: GraphViewModel
    @Binding var zoomScale: CGFloat
    @Binding var offset: CGSize
    @Binding var draggedNode: Node?
    @Binding var dragOffset: CGPoint
    @Binding var potentialEdgeTarget: Node?
    @Binding var selectedNodeID: NodeID?
    let viewSize: CGSize
    @Binding var panStartOffset: CGSize?
    @Binding var showMenu: Bool
    let maxZoom: CGFloat
    @Binding var crownPosition: Double
    let onUpdateZoomRanges: () -> Void
    
    var body: some View {
        Canvas { context, size in
            let transform = CGAffineTransform(translationX: offset.width, y: offset.height)
                .scaledBy(x: zoomScale, y: zoomScale)
            
            // Draw edges and their labels
            for edge in viewModel.model.edges {
                if let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                   let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                    let fromPos = (draggedNode?.id == fromNode.id ? CGPoint(x: fromNode.position.x + dragOffset.x, y: fromNode.position.y + dragOffset.y) : fromNode.position).applying(transform)
                    let toPos = (draggedNode?.id == toNode.id ? CGPoint(x: toNode.position.x + dragOffset.x, y: toNode.position.y + dragOffset.y) : toNode.position).applying(transform)
                    context.stroke(Path { path in
                        path.move(to: fromPos)
                        path.addLine(to: toPos)
                    }, with: .color(.blue), lineWidth: 2 * zoomScale)
                    
                    let midpoint = CGPoint(x: (fromPos.x + toPos.x) / 2, y: (fromPos.y + toPos.y) / 2)
                    let fromLabel = fromNode.label
                    let toLabel = toNode.label
                    let edgeLabel = "\(min(fromLabel, toLabel))-\(max(fromLabel, toLabel))"
                    let fontSize = UIFontMetrics.default.scaledValue(for: 12) * zoomScale
                    let text = Text(edgeLabel).foregroundColor(.white).font(.system(size: fontSize))
                    let resolvedText = context.resolve(text)
                    context.draw(resolvedText, at: midpoint, anchor: .center)
                }
            }
            
            // Draw potential new edge during drag
            if let dragged = draggedNode, let target = potentialEdgeTarget {
                let fromPos = CGPoint(x: dragged.position.x + dragOffset.x, y: dragged.position.y + dragOffset.y).applying(transform)
                let toPos = target.position.applying(transform)
                context.stroke(Path { path in
                    path.move(to: fromPos)
                    path.addLine(to: toPos)
                }, with: .color(.green), style: StrokeStyle(lineWidth: 2 * zoomScale, dash: [5 * zoomScale]))
            }
            
            // Draw nodes
            for node in viewModel.model.nodes {
                let pos = (draggedNode?.id == node.id ? CGPoint(x: node.position.x + dragOffset.x, y: node.position.y + dragOffset.y) : node.position).applying(transform)
                let scaledRadius = AppConstants.nodeModelRadius * zoomScale
                context.fill(Path(ellipseIn: CGRect(x: pos.x - scaledRadius, y: pos.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius)), with: .color(.red))
                if node.id == selectedNodeID {
                    let borderWidth = 4 * zoomScale
                    let borderRadius = scaledRadius + borderWidth / 2
                    context.stroke(Path(ellipseIn: CGRect(x: pos.x - borderRadius, y: pos.y - borderRadius, width: 2 * borderRadius, height: 2 * borderRadius)), with: .color(.white), lineWidth: borderWidth)
                }
                let fontSize = UIFontMetrics.default.scaledValue(for: 12) * zoomScale
                let text = Text("\(node.label)").foregroundColor(.white).font(.system(size: fontSize))
                let resolvedText = context.resolve(text)
                context.draw(resolvedText, at: pos, anchor: .center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(graphDescription())
        .accessibilityHint("Double-tap for menu. Long press to delete selected.")
        .accessibilityChildren {
            ForEach(viewModel.model.nodes) { node in
                Text("Node \(node.label) at (\(Int(node.position.x)), \(Int(node.position.y)))")
                    .accessibilityAction(named: "Select") {
                        selectedNodeID = node.id
                        WKInterfaceDevice.current().play(.click)
                    }
            }
        }
        .modifier(GraphGesturesModifier(
            viewModel: viewModel,
            zoomScale: $zoomScale,
            offset: $offset,
            draggedNode: $draggedNode,
            dragOffset: $dragOffset,
            potentialEdgeTarget: $potentialEdgeTarget,
            selectedNodeID: $selectedNodeID,
            viewSize: viewSize,
            panStartOffset: $panStartOffset,
            showMenu: $showMenu,
            maxZoom: maxZoom,
            crownPosition: $crownPosition,
            onUpdateZoomRanges: onUpdateZoomRanges
        ))
    }
    
    private func graphDescription() -> String {
        var desc = "Graph with \(viewModel.model.nodes.count) nodes and \(viewModel.model.edges.count) edges."
        if let selectedID = selectedNodeID,
           let selectedNode = viewModel.model.nodes.first(where: { $0.id == selectedID }) {
            let connectedLabels = viewModel.model.edges
                .filter { $0.from == selectedID || $0.to == selectedID }
                .compactMap { edge in
                    let otherID = (edge.from == selectedID ? edge.to : edge.from)
                    return viewModel.model.nodes.first { $0.id == otherID }?.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            desc += " Node \(selectedNode.label) selected, connected to nodes: \(connectedLabels.isEmpty ? "none" : connectedLabels)."
        } else {
            desc += " No node selected."
        }
        return desc
    }
}
