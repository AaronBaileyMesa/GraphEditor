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
    @State private var zoomTimer: Timer? = nil  // New: For debouncing crown activity
    
    private var canvasBase: some View {
        
        ZStack {  // New: Wrap for overlay
            // New: Fixed grey circle at screen center
            Circle()
                .fill(Color.gray.opacity(0.2))  // Semi-transparent grey
                .frame(width: min(viewSize.width, viewSize.height) * 0.4,  // ~20% of smaller dimension
                       height: min(viewSize.width, viewSize.height) * 0.4)
                .position(x: viewSize.width / 2, y: viewSize.height / 2)  // Fixed at view center
            
            Canvas { context, size in
                let transform = CGAffineTransform(scaleX: zoomScale, y: zoomScale).translatedBy(x: offset.width, y: offset.height)
                
                // Draw edges (unchanged)
                for edge in viewModel.model.visibleEdges() {
                    if let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                       let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                        let fromPos = (draggedNode?.id == fromNode.id ? CGPoint(x: fromNode.position.x + dragOffset.x, y: fromNode.position.y + dragOffset.y) : fromNode.position).applying(transform)
                        let toPos = (draggedNode?.id == toNode.id ? CGPoint(x: toNode.position.x + dragOffset.x, y: toNode.position.y + dragOffset.y) : toNode.position).applying(transform)
                        
                        // Calculate direction and length (unchanged)
                        let direction = CGPoint(x: toPos.x - fromPos.x, y: toPos.y - fromPos.y)
                        let length = hypot(direction.x, direction.y)
                        if length > 0 {
                            let unitDir = CGPoint(x: direction.x / length, y: direction.y / length)
                            
                            // Shorten line to end at toNode's edge (unchanged)
                            let scaledToRadius = toNode.radius * zoomScale
                            let lineEnd = toPos - unitDir * scaledToRadius
                            
                            // Draw shortened line (unchanged)
                            context.stroke(Path { path in
                                path.move(to: fromPos)
                                path.addLine(to: lineEnd)
                            }, with: .color(.blue), lineWidth: 2 * zoomScale)
                            
                            // Draw arrowhead (unchanged)
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
                            }, with: .color(.blue))
                        }
                        
                        // Edge label (unchanged)
                        let midpoint = CGPoint(x: (fromPos.x + toPos.x) / 2, y: (fromPos.y + toPos.y) / 2)
                        let edgeLabel = "\(fromNode.label)→\(toNode.label)"
                        let fontSize = UIFontMetrics.default.scaledValue(for: 12) * zoomScale
                        let text = Text(edgeLabel).foregroundColor(.white).font(.system(size: fontSize))
                        let resolvedText = context.resolve(text)
                        context.draw(resolvedText, at: midpoint, anchor: .center)
                    }
                }
                
                // Draw potential new edge during drag (unchanged; assumes always visible)
                if let dragged = draggedNode, let target = potentialEdgeTarget {
                    let fromPos = CGPoint(x: dragged.position.x + dragOffset.x, y: dragged.position.y + dragOffset.y).applying(transform)
                    let toPos = target.position.applying(transform)
                    context.stroke(Path { path in
                        path.move(to: fromPos)
                        path.addLine(to: toPos)
                    }, with: .color(.green), style: StrokeStyle(lineWidth: 2 * zoomScale, dash: [5 * zoomScale]))
                }
                
                // Draw nodes (moved inside Canvas for unified rendering)
                for node in viewModel.model.visibleNodes() {
                    let isDragged = draggedNode?.id == node.id
                    let worldPos = isDragged ? CGPoint(x: node.position.x + dragOffset.x, y: node.position.y + dragOffset.y) : node.position
                    let screenPos = worldPos.applying(transform)
                    let isSelected = node.id == selectedNodeID
                    
                    node.draw(in: context, at: screenPos, zoomScale: zoomScale, isSelected: isSelected)
                }
            }
            .drawingGroup()  // Optional: Improves anti-aliasing consistency
        }
    }
    
    private var interactiveCanvas: some View {
        canvasBase
        /*
            .onChange(of: crownPosition) {
                viewModel.model.physicsEngine.isPaused = true  // Pause sim
                zoomTimer?.invalidate()  // Cancel previous timer
                zoomTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    viewModel.model.physicsEngine.isPaused = false  // Resume after inactivity
                }
            } */
    }
    
    private var accessibleCanvas: some View {
        interactiveCanvas
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.model.graphDescription(selectedID: selectedNodeID))
            .accessibilityHint("Double-tap for menu. Long press to delete selected.")
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
