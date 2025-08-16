import SwiftUI
import WatchKit
import GraphEditorShared

// New: Custom wrapper for reliable crown focus
struct FocusableView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .focusable(true) { focused in  // Add closure to handle focus changes
                if focused {
                    print("View focused for crown")  // Optional debug
                }
            }
            .onAppear {
                // No need for extra; .focusable handles
            }
    }
}

class CrownHandler: NSObject, ObservableObject, WKCrownDelegate {
    @Published var accumulator: Double = 0.0
    
    func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
        accumulator += Double(rotationalDelta) * 10.0  // Sensitivity; adjust
    }
}

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
    
    // Define zoomLevels array
    private let zoomLevels: [CGFloat] = {
        let minZoom: CGFloat = 0.5
        let maxZoom: CGFloat = 2.5
        let steps = Constants.App.numZoomLevels
        let stepSize = (maxZoom - minZoom) / CGFloat(steps - 1)
        return (0..<steps).map { minZoom + CGFloat($0) * stepSize }
    }()
    
    // Define simulationBounds
    private let simulationBounds: CGSize = CGSize(width: 300, height: 300)  // Match PhysicsEngine bounds
    
    // Clamp function to cap extreme offsets
    private func clampOffset(_ offset: CGSize) -> CGSize {
        let maxOffset: CGFloat = 500.0  // Arbitrary cap; adjust based on graph size
        return CGSize(
            width: max(-maxOffset, min(offset.width, maxOffset)),
            height: max(-maxOffset, min(offset.height, maxOffset))
        )
    }
    
    private func displayPosition(for worldPos: CGPoint, effectiveCentroid: CGPoint, panOffset: CGPoint, viewCenter: CGPoint) -> CGPoint {
        let relative = CGPoint(x: worldPos.x - effectiveCentroid.x, y: worldPos.y - effectiveCentroid.y)
        let scaled = CGPoint(x: relative.x * zoomScale, y: relative.y * zoomScale)
        return CGPoint(x: scaled.x + viewCenter.x + panOffset.x, y: scaled.y + viewCenter.y + panOffset.y)
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
            
            ScrollView {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: min(viewSize.width, viewSize.height) * 0.4,
                               height: min(viewSize.width, viewSize.height) * 0.4)
                        .position(viewCenter)
                    
                    // Render nodes as Views for transitions
                    ForEach(culledNodes, id: \.id) { node in
                        let isDragged = draggedNode?.id == node.id
                        let worldPos = isDragged ? CGPoint(x: node.position.x + dragOffset.x, y: node.position.y + dragOffset.y) : node.position
                        NodeView(node: node, isSelected: selectedNodeID == node.id, zoomScale: zoomScale)
                            .position(displayPosition(for: worldPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter))  // Use worldPos
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.1, anchor: .center).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .animation(.easeInOut(duration: 0.3), value: node.id)  // Trigger on appearance/change
                    }
                    
                    // Keep edges in Canvas for performance, but add animation for sync
                    Canvas { context, _ in
                        drawEdges(in: context, culledEdges: culledEdges, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                        
                        if let dragged = draggedNode, let target = potentialEdgeTarget {
                            let fromPos = CGPoint(x: dragged.position.x + dragOffset.x, y: dragged.position.y + dragOffset.y)
                            let toPos = target.position
                            let fromDisplay = displayPosition(for: fromPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                            let toDisplay = displayPosition(for: toPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                            context.stroke(Path { path in
                                path.move(to: fromDisplay)
                                path.addLine(to: toDisplay)
                            }, with: .color(.green), style: StrokeStyle(lineWidth: 2.0, dash: [5.0]))
                        }
                    }
                    .drawingGroup()
                    .animation(.easeInOut(duration: 0.3), value: culledEdges.map { $0.id })  // Sync animation with edge IDs
                    
                    if showOverlays {
                        overlaysView(visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .offset(x: offset.width, y: offset.height)
                .scaleEffect(zoomScale)
             
            }
            .scrollDisabled(true)
        }
        .ignoresSafeArea()
    }
    
    private func computeEffectiveCentroid(visibleNodes: [any NodeProtocol]) -> CGPoint {
        if let selectedID = selectedNodeID, let selected = visibleNodes.first(where: { $0.id == selectedID }) {
            return selected.position
        } else if let selectedEdge = selectedEdgeID, let edge = viewModel.model.edges.first(where: { $0.id == selectedEdge }),
                  let from = visibleNodes.first(where: { $0.id == edge.from }), let to = visibleNodes.first(where: { $0.id == edge.to }) {
            return CGPoint(x: (from.position.x + to.position.x) / 2, y: (from.position.y + to.position.y) / 2)
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
            let nodeRectOrigin = CGPoint(x: node.position.x - (node.radius + buffer), y: node.position.y - (node.radius + buffer))
            let nodeRectSize = CGSize(width: (node.radius + buffer) * 2, height: (node.radius + buffer) * 2)
            let nodeRect = CGRect(origin: nodeRectOrigin, size: nodeRectSize)
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
        var processedEdges = Set<UUID>()  // Avoid duplicate bidirectional draws
        
        for edge in culledEdges {
            if processedEdges.contains(edge.id) { continue }
            processedEdges.insert(edge.id)
            
            guard let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                  let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) else { continue }
            
            let fromPos = (draggedNode?.id == fromNode.id ? CGPoint(x: fromNode.position.x + dragOffset.x, y: fromNode.position.y + dragOffset.y) : fromNode.position)
            let toPos = (draggedNode?.id == toNode.id ? CGPoint(x: toNode.position.x + dragOffset.x, y: toNode.position.y + dragOffset.y) : toNode.position)
            
            let fromDisplay = displayPosition(for: fromPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
            let toDisplay = displayPosition(for: toPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
            
            let direction = CGPoint(x: toDisplay.x - fromDisplay.x, y: toDisplay.y - fromDisplay.y)
            let length = hypot(direction.x, direction.y)
            if length <= 0 { continue }
            
            let unitDir = CGPoint(x: direction.x / length, y: direction.y / length)
            let scaledFromRadius = fromNode.radius * zoomScale + 2  // Slight inset
            let scaledToRadius = toNode.radius * zoomScale + 2
            let lineStart = CGPoint(x: fromDisplay.x + unitDir.x * scaledFromRadius, y: fromDisplay.y + unitDir.y * scaledFromRadius)
            let lineEnd = CGPoint(x: toDisplay.x - unitDir.x * scaledToRadius, y: toDisplay.y - unitDir.y * scaledToRadius)
            
            let isSelected = edge.id == selectedEdgeID
            let lineWidth = isSelected ? 4.0 : 2.0
            let color = isSelected ? Color.red : Color.blue
            
            // Bidirectional check
            if let reverseEdge = viewModel.model.edges.first(where: { $0.from == edge.to && $0.to == edge.from }) {
                processedEdges.insert(reverseEdge.id)  // Skip reverse
                
                // Draw two curved lines
                let midPoint = CGPoint(x: (fromDisplay.x + toDisplay.x) / 2, y: (fromDisplay.y + toDisplay.y) / 2)
                let perpDir = CGPoint(x: -unitDir.y * (8.0 * zoomScale), y: unitDir.x * (8.0 * zoomScale))  // Break up
                let control1 = CGPoint(x: midPoint.x + perpDir.x, y: midPoint.y + perpDir.y)
                context.stroke(Path { path in
                    path.move(to: lineStart)
                    path.addQuadCurve(to: lineEnd, control: control1)
                }, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                drawArrowhead(in: context, at: lineEnd, direction: unitDir, size: 8.0 * min(zoomScale, 1.0), color: color)
                
                // Reverse curve (opposite offset)
                let control2 = CGPoint(x: midPoint.x - perpDir.x, y: midPoint.y - perpDir.y)
                let revStart = CGPoint(x: toDisplay.x - unitDir.x * scaledToRadius, y: toDisplay.y - unitDir.y * scaledToRadius)
                let revEnd = CGPoint(x: fromDisplay.x + unitDir.x * scaledFromRadius, y: fromDisplay.y + unitDir.y * scaledFromRadius)
                let revDir = CGPoint(x: -unitDir.x, y: -unitDir.y)
                context.stroke(Path { path in
                    path.move(to: revStart)
                    path.addQuadCurve(to: revEnd, control: control2)
                }, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                drawArrowhead(in: context, at: revEnd, direction: revDir, size: 8.0 * min(zoomScale, 1.0), color: color)
                if isSelected {
                    let midpoint = midPoint
                    let fromLabel = fromNode.label
                    let toLabel = toNode.label
                    let edgeLabel = "\(min(fromLabel, toLabel))↔\(max(fromLabel, toLabel))"  // Combined bidirectional label
                    let fontSize = max(8.0, 12.0 * zoomScale)  // Min size for readability
                    let text = Text(edgeLabel).foregroundColor(.white).font(.system(size: fontSize))
                    context.draw(context.resolve(text), at: midpoint, anchor: .center)
                }
            } else {
                // Single straight line
                context.stroke(Path { path in
                    path.move(to: lineStart)
                    path.addLine(to: lineEnd)
                }, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                drawArrowhead(in: context, at: lineEnd, direction: unitDir, size: 8.0 * min(zoomScale, 1.0), color: color)
            }
            
            if isSelected {
                let midpoint = CGPoint(x: (fromDisplay.x + toDisplay.x) / 2, y: (fromDisplay.y + toDisplay.y) / 2)
                let edgeLabel = "\(fromNode.label)→\(toNode.label)"
                let fontSize = max(8.0, 12.0 * zoomScale)  // Min size for readability
                let text = Text(edgeLabel).foregroundColor(.white).font(.system(size: fontSize))
                context.draw(context.resolve(text), at: midpoint, anchor: .center)
            }
        }
    }
    
    private func drawArrowhead(in context: GraphicsContext, at point: CGPoint, direction: CGPoint, size: CGFloat, color: Color) {
        let arrowSize = size * min(zoomScale, 1.0)  // Scale with zoom, cap at 1x
        let perpDir = CGPoint(x: -direction.y, y: direction.x)
        let arrowTip = point
        let arrowBase1X = arrowTip.x - direction.x * arrowSize + perpDir.x * (arrowSize / 2)
        let arrowBase1Y = arrowTip.y - direction.y * arrowSize + perpDir.y * (arrowSize / 2)
        let arrowBase1 = CGPoint(x: arrowBase1X, y: arrowBase1Y)
        let arrowBase2X = arrowTip.x - direction.x * arrowSize - perpDir.x * (arrowSize / 2)
        let arrowBase2Y = arrowTip.y - direction.y * arrowSize - perpDir.y * (arrowSize / 2)
        let arrowBase2 = CGPoint(x: arrowBase2X, y: arrowBase2Y)
        
        let arrowPath = Path { path in
            path.move(to: arrowTip)
            path.addLine(to: arrowBase1)
            path.addLine(to: arrowBase2)
            path.closeSubpath()
        }
        context.fill(arrowPath, with: .color(color), style: FillStyle(antialiased: true))
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
            
            // New: Hierarchy indicators (dashed lines to hidden children)
            ForEach(viewModel.model.nodes.filter { !$0.isVisible && ($0 as? ToggleNode)?.isExpanded == false }, id: \.id) { hiddenNode in
                if let parentID = viewModel.model.edges.first(where: { $0.to == hiddenNode.id })?.from,
                   let parent = viewModel.model.nodes.first(where: { $0.id == parentID }) {
                    let fromDisplay = displayPosition(for: parent.position, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                    let toDisplay = displayPosition(for: hiddenNode.position, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                    Path { path in
                        path.move(to: fromDisplay)
                        path.addLine(to: toDisplay)
                    }
                    .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1.0, dash: [5.0]))
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
    
    struct AnimatableEdge: Shape {
        var from: CGPoint
        var to: CGPoint
        
        var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
            get { AnimatablePair(from.animatableData, to.animatableData) }
            set {
                from.animatableData = newValue.first
                to.animatableData = newValue.second
            }
        }
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            return path
        }
    }
    
    var body: some View {
        Group {
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
        .onChange(of: selectedNodeID) {
            viewModel.saveViewState()
        }
        .onChange(of: selectedEdgeID) {
            viewModel.saveViewState()
        }
        .ignoresSafeArea()
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
