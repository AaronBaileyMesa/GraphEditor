import SwiftUI
import WatchKit
import GraphEditorShared

class CrownHandler: ObservableObject {
    @Published var accumulator: Double = 0.0  // Persistent crown value
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
    @State private var snapshotNodes: [any NodeProtocol] = []  // New: Stable snapshot for rendering
    @Binding var selectedEdgeID: UUID?
    @Binding var showOverlays: Bool
    
    // Persistent crown handler
    @StateObject private var crownHandler = CrownHandler()
    // Re-added for focus management
    @FocusState private var isCrownFocused: Bool
    
    // New: Define zoomLevels array
    private let zoomLevels: [CGFloat] = {
        let minZoom: CGFloat = 0.5
        let maxZoom: CGFloat = 2.5
        let steps = Constants.App.numZoomLevels
        let stepSize = (maxZoom - minZoom) / CGFloat(steps - 1)
        return (0..<steps).map { minZoom + CGFloat($0) * stepSize }
    }()
    
    // New: Define simulationBounds
    private let simulationBounds: CGSize = CGSize(width: 300, height: 300)  // Match PhysicsEngine bounds
    
    // New: Clamp function to cap extreme offsets
    private func clampOffset(_ offset: CGSize) -> CGSize {
        let maxOffset: CGFloat = 500.0  // Arbitrary cap; adjust based on graph size
        return CGSize(
            width: max(-maxOffset, min(offset.width, maxOffset)),
            height: max(-maxOffset, min(offset.height, maxOffset))
        )
    }
    
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
                
                // Use snapshot for stability (update via onReceive or similar)
                let visibleNodes = snapshotNodes.filter { $0.isVisible }  // Assuming NodeProtocol has isVisible
                
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
                        let worldPos = isDragged ? node.position + dragOffset : node.position  // Add offset during drag
                        NodeView(node: node, isSelected: selectedNodeID == node.id, zoomScale: zoomScale)
                            .position(displayPosition(for: worldPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter))  // Use worldPos
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.1, anchor: .center).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .animation(.easeInOut(duration: 0.3), value: node.id)  // Trigger on appearance/change
                    }
                    
                    // Keep edges in Canvas for performance
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
                    }
                    .drawingGroup()
                    
                    if showOverlays {
                        overlaysView(visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)  // Moved here
                .offset(x: offset.width, y: offset.height)  // Moved here
                .scaleEffect(zoomScale)  // Moved here
                .focusable(true)  // Enable crown focus
            }
            .scrollDisabled(true)
        }
        .ignoresSafeArea()  // Helps with watch layout
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
        var processedEdges = Set<UUID>()  // Avoid duplicate bidirectional draws
        
        for edge in culledEdges {
            if processedEdges.contains(edge.id) { continue }
            processedEdges.insert(edge.id)
            
            guard let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                  let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }) else { continue }
            
            let fromPos = (draggedNode?.id == fromNode.id ? fromNode.position + dragOffset : fromNode.position)
            let toPos = (draggedNode?.id == toNode.id ? toNode.position + dragOffset : toNode.position)
            
            let fromDisplay = displayPosition(for: fromPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
            let toDisplay = displayPosition(for: toPos, effectiveCentroid: effectiveCentroid, panOffset: panOffset, viewCenter: viewCenter)
            
            let direction = toDisplay - fromDisplay
            let length = hypot(direction.x, direction.y)
            if length <= 0 { continue }
            
            let unitDir = direction / length
            let scaledFromRadius = fromNode.radius * zoomScale + 2  // Slight inset
            let scaledToRadius = toNode.radius * zoomScale + 2
            let lineStart = fromDisplay + unitDir * scaledFromRadius
            let lineEnd = toDisplay - unitDir * scaledToRadius
            
            let isSelected = edge.id == selectedEdgeID
            let lineWidth = isSelected ? 4.0 : 2.0
            let color = isSelected ? Color.red : Color.blue
            
            // Bidirectional check
            if let reverseEdge = viewModel.model.edges.first(where: { $0.from == edge.to && $0.to == edge.from }) {
                processedEdges.insert(reverseEdge.id)  // Skip reverse
                
                // Draw two curved lines
                let midPoint = (fromDisplay + toDisplay) / 2
                let perpDir = CGPoint(x: -unitDir.y, y: unitDir.x) * (8.0 * zoomScale)  // Curve offset scaled
                
                // Forward curve
                let control1 = midPoint + perpDir
                context.stroke(Path { path in
                    path.move(to: lineStart)
                    path.addQuadCurve(to: lineEnd, control: control1)
                }, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                drawArrowhead(in: context, at: lineEnd, direction: unitDir, size: 8.0 * min(zoomScale, 1.0), color: color)
                
                // Reverse curve (opposite offset)
                let control2 = midPoint + CGPoint(x: -perpDir.x, y: -perpDir.y)  // Proper negation
                let revStart = toDisplay + CGPoint(x: -unitDir.x * scaledToRadius, y: -unitDir.y * scaledToRadius)  // Swap and negate
                let revEnd = fromDisplay + unitDir * scaledFromRadius
                let revDir = CGPoint(x: -unitDir.x, y: -unitDir.y)
                context.stroke(Path { path in
                    path.move(to: revStart)
                    path.addQuadCurve(to: revEnd, control: control2)
                }, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                drawArrowhead(in: context, at: revEnd, direction: revDir, size: 8.0 * min(zoomScale, 1.0), color: color)
                if isSelected {
                    let midpoint = (fromDisplay + toDisplay) / 2
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
                let midpoint = (fromDisplay + toDisplay) / 2
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
        let arrowBase1 = arrowTip - direction * arrowSize + perpDir * (arrowSize / 2)
        let arrowBase2 = arrowTip - direction * arrowSize - perpDir * (arrowSize / 2)
        
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
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $crownHandler.accumulator,
            from: 0.0,
            through: Double(Constants.App.numZoomLevels - 1),
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownHandler.accumulator) { oldValue, newValue in
            let targetZoomIndex = Int(newValue)
            let targetZoom = zoomLevels[targetZoomIndex]
            let oldZoom = zoomScale
            
            if abs(targetZoom - oldZoom) < 0.01 { return }  // Debounce tiny changes
            
            viewModel.pauseSimulation()
            
            let screenCenter = CGPoint(x: simulationBounds.width / 2, y: simulationBounds.height / 2)
            let modelCenterBefore = CGPoint(
                x: (screenCenter.x - offset.width) / oldZoom,
                y: (screenCenter.y - offset.height) / oldZoom
            )
            
            withAnimation(.easeInOut(duration: 0.25)) {
                zoomScale = targetZoom
                offset = CGSize(
                    width: screenCenter.x - modelCenterBefore.x * targetZoom,
                    height: screenCenter.y - modelCenterBefore.y * targetZoom
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onUpdateZoomRanges()
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            viewModel.resumeSimulation()
                        }
                    }
                    .onChange(of: offset) { oldOffset, newOffset in
                        let clamped = clampOffset(newOffset)
                        if clamped != newOffset {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                offset = clamped
                            }
                        }
                    }
                    .onReceive(viewModel.model.$nodes) { newNodes in  // New: Update snapshot on nodes change
                        DispatchQueue.main.async {
                            self.snapshotNodes = newNodes  // Copy to local state for render stability
                        }
                    }
                    .onAppear {
                        isCrownFocused = true
                        snapshotNodes = viewModel.model.nodes  // Initial snapshot
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
