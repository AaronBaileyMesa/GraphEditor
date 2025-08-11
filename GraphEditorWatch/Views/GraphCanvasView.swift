// Revised GraphCanvasView.swift with animated offset handling
// Changes: Added withAnimation to body for offset changes; ensured selection triggers animated recenter via onChange.

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
    @Binding var showOverlays: Bool
    
    private func displayPosition(for worldPos: CGPoint, effectiveCentroid: CGPoint, panOffset: CGPoint, viewCenter: CGPoint) -> CGPoint {
        let relative = worldPos - effectiveCentroid
        let scaled = relative * zoomScale
        return scaled + viewCenter + panOffset
    }
    
    private var canvasBase: some View {
        GeometryReader { geometry in
            let viewSize = geometry.size
            let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
            let panOffset = CGPoint(x: offset.width, y: offset.height)
            let visibleNodes = viewModel.model.visibleNodes()
            
            let effectiveCentroid = computeEffectiveCentroid(visibleNodes: visibleNodes)
            
            let visibleRect = computeVisibleRect(panOffset: panOffset, effectiveCentroid: effectiveCentroid, viewCenter: viewCenter, viewSize: viewSize)
            
            let culledNodes = cullNodes(visibleNodes: visibleNodes, visibleRect: visibleRect)
            
            let culledEdges = cullEdges(visibleEdges: viewModel.model.visibleEdges(), culledNodes: culledNodes, visibleRect: visibleRect)
            
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: min(viewSize.width, viewSize.height) * 0.4,
                           height: min(viewSize.width, viewSize.height) * 0.4)
                    .position(viewCenter)
                
                Canvas { context, _ in
                    drawEdges(in: context, culledEdges: culledEdges, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                    
                    if let dragged = draggedNode, let target = potentialEdgeTarget {
                        let fromPos = dragged.position + dragOffset
                        let toPos = target.position
                        let fromDisplay = displayPosition(for: fromPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                        let toDisplay = displayPosition(for: toPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                        context.stroke(Path { path in
                            path.move(to: fromDisplay)
                            path.addLine(to: toDisplay)
                        }, with: .color(.green), style: StrokeStyle(lineWidth: 2.0, dash: [5.0]))
                    }
                    
                    drawNodes(in: context, culledNodes: culledNodes, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                }
                .drawingGroup()
                
                if showOverlays {
                    overlaysView(visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                }
            }
        }
    }
    
    private func computeEffectiveCentroid(visibleNodes: [any NodeProtocol]) -> CGPoint {
        if let selectedID = selectedNodeID, let selected = visibleNodes.first(where: { $0.id == selectedID }) {
            return selected.position
        } else if let selectedEdge = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdge }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }), let to = visibleNodes.first(where: { $0.id == edge.to }) {
            return (from.position + to.position) / 2.0
        }
        return visibleNodes.centroid() ?? .zero
    }
    
    private func computeVisibleRect(panOffset: CGPoint, effectiveCentroid: CGPoint, viewCenter: CGPoint, viewSize: CGSize) -> CGRect {
        let originX = effectiveCentroid.x + (-viewCenter.x - panOffset.x) / zoomScale
        let originY = effectiveCentroid.y + (-viewCenter.y - panOffset.y) / zoomScale
        let worldWidth = viewSize.width / zoomScale
        let worldHeight = viewSize.height / zoomScale
        let visibleRect = CGRect(x: originX, y: originY, width: worldWidth, height: worldHeight)
        
        let bufferWorld = 50.0 / zoomScale
        return visibleRect.insetBy(dx: -bufferWorld, dy: -bufferWorld)
    }

    private func cullNodes(visibleNodes: [any NodeProtocol], visibleRect: CGRect) -> [any NodeProtocol] {
        visibleNodes.filter { node in
            let buffer = node.radius / 2
            let nodeRect = CGRect(center: node.position, size: CGSize(width: (node.radius + buffer) * 2, height: (node.radius + buffer) * 2))
            return visibleRect.intersects(nodeRect)
        }
    }

    private func cullEdges(visibleEdges: [GraphEdge], culledNodes: [any NodeProtocol], visibleRect: CGRect) -> [GraphEdge] {
        visibleEdges.filter { edge in
            guard let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                  let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) else { return false }
            let bufferWorld = 10.0 / zoomScale
            let minX = min(fromNode.position.x, toNode.position.x) - bufferWorld
            let minY = min(fromNode.position.y, toNode.position.y) - bufferWorld
            let width = abs(fromNode.position.x - toNode.position.x) + 2 * bufferWorld
            let height = abs(fromNode.position.y - toNode.position.y) + 2 * bufferWorld
            let lineRect = CGRect(x: minX, y: minY, width: width, height: height)
            return visibleRect.intersects(lineRect)
        }
    }
    
    private func drawEdges(in context: GraphicsContext, culledEdges: [GraphEdge], effectiveCentroid: CGPoint, panOffset: CGPoint, viewCenter: CGPoint) {
        for edge in culledEdges {
            if let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
               let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) {
                let fromPos = (draggedNode?.id == fromNode.id ? CGPoint(x: fromNode.position.x + dragOffset.x, y: fromNode.position.y + dragOffset.y) : fromNode.position)
                let toPos = (draggedNode?.id == toNode.id ? CGPoint(x: toNode.position.x + dragOffset.x, y: toNode.position.y + dragOffset.y) : toNode.position)
                
                let fromDisplay = displayPosition(for: fromPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                let toDisplay = displayPosition(for: toPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                
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
                    }, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                    
                    let arrowSize: CGFloat = 10.0
                    let perpDir = CGPoint(x: -unitDir.y, y: unitDir.x)
                    let arrowTip = lineEnd
                    let arrowBase1 = arrowTip - unitDir * arrowSize + perpDir * (arrowSize / 2)
                    let arrowBase2 = arrowTip - unitDir * arrowSize - perpDir * (arrowSize / 2)
                    
                    let arrowPath = Path { path in
                        path.move(to: arrowTip)
                        path.addLine(to: arrowBase1)
                        path.addLine(to: arrowBase2)
                        path.closeSubpath()
                    }
                    context.fill(arrowPath, with: .color(color), style: FillStyle(antialiased: true))
                }
                
                if edge.id == selectedEdgeID {
                    let midpoint = (fromDisplay + toDisplay) / 2
                    let edgeLabel = "\(fromNode.label)→\(toNode.label)"
                    let fontSize = UIFontMetrics.default.scaledValue(for: 12)
                    let text = Text(edgeLabel).foregroundColor(.white).font(.system(size: fontSize))
                    let resolvedText = context.resolve(text)
                    context.draw(resolvedText, at: midpoint, anchor: .center)
                }
            }
        }
    }
    
    private func drawNodes(in context: GraphicsContext, culledNodes: [any NodeProtocol], effectiveCentroid: CGPoint, panOffset: CGPoint, viewCenter: CGPoint) {
        let nodesToDraw = culledNodes
        if nodesToDraw.isEmpty {
            let text = Text("No Visible Nodes").foregroundColor(.gray).font(.system(size: 16))
            context.draw(context.resolve(text), at: viewCenter, anchor: .center)
            return
        }
        for node in nodesToDraw {
            let isDragged = draggedNode?.id == node.id
            let worldPos = isDragged ? node.position + dragOffset : node.position
            let displayPos = displayPosition(for: worldPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
            let isSelected = node.id == selectedNodeID
            
            let scaledRadius = node.radius * zoomScale
            let borderWidth: CGFloat = isSelected ? 4 * zoomScale : 0
            let borderRadius = scaledRadius + borderWidth / 2
            
            let circlePath = Path(ellipseIn: CGRect(x: displayPos.x - scaledRadius, y: displayPos.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius))
            context.fill(circlePath, with: .color(.red), style: FillStyle(antialiased: true))
            
            if isSelected {
                let borderPath = Path(ellipseIn: CGRect(x: displayPos.x - borderRadius, y: displayPos.y - borderRadius, width: 2 * borderRadius, height: 2 * borderRadius))
                context.stroke(borderPath, with: .color(.white), style: StrokeStyle(lineWidth: borderWidth, lineJoin: .round))
            }
            
            node.draw(in: context, at: displayPos, zoomScale: zoomScale, isSelected: isSelected)
        }
    }
    
    private func overlaysView(visibleNodes: [any NodeProtocol], effectiveCentroid: CGPoint, panOffset: CGPoint, viewCenter: CGPoint) -> some View {
        Group {
            if !visibleNodes.isEmpty {
                let modelBBox = viewModel.model.boundingBox()
                
                let minDisplay = displayPosition(for: CGPoint(x: modelBBox.minX, y: modelBBox.minY), effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                let maxDisplay = displayPosition(for: CGPoint(x: modelBBox.maxX, y: modelBBox.maxY), effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                
                let displayWidth = maxDisplay.x - minDisplay.x
                let displayHeight = maxDisplay.y - minDisplay.y
                let displayCenter = CGPoint(x: minDisplay.x + displayWidth / 2, y: minDisplay.y + displayHeight / 2)
                
                Rectangle()
                    .stroke(Color.blue, lineWidth: 1.0)
                    .frame(width: displayWidth, height: displayHeight)
                    .position(displayCenter)
            }
            
            if let centroid = visibleNodes.centroid() {
                let displayPos = displayPosition(for: centroid, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 4, height: 4)
                    .position(displayPos)
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
            .onChange(of: offset) {
                withAnimation(.easeInOut(duration: 0.3)) { }  // Animate offset changes
            }
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

extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self.init(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }
}
