import SwiftUI
import WatchKit
import GraphEditorShared

// Reverted: Custom wrapper for reliable crown focus (without crown—handled in ContentView now)
struct FocusableView<Content: View>: View {
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
                print("Canvas focus changed: from \(oldValue) to \(newValue)")
                if !newValue {
                    isFocused = true  // Auto-recover focus loss
                }
            }
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
    @State private var zoomTimer: Timer?
    @Binding var selectedEdgeID: UUID?
    @Binding var showOverlays: Bool
    @Binding var isAddingEdge: Bool
    
    init(
        viewModel: GraphViewModel,
        zoomScale: Binding<CGFloat>,
        offset: Binding<CGSize>,
        draggedNode: Binding<(any NodeProtocol)?>,
        dragOffset: Binding<CGPoint>,
        potentialEdgeTarget: Binding<(any NodeProtocol)?>,
        selectedNodeID: Binding<NodeID?>,
        viewSize: CGSize,
        panStartOffset: Binding<CGSize?>,
        showMenu: Binding<Bool>,
        maxZoom: CGFloat,
        crownPosition: Binding<Double>,
        onUpdateZoomRanges: @escaping () -> Void,
        selectedEdgeID: Binding<UUID?>,
        showOverlays: Binding<Bool>,
        isAddingEdge: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self._zoomScale = zoomScale
        self._offset = offset
        self._draggedNode = draggedNode
        self._dragOffset = dragOffset
        self._potentialEdgeTarget = potentialEdgeTarget
        self._selectedNodeID = selectedNodeID
        self.viewSize = viewSize
        self._panStartOffset = panStartOffset
        self._showMenu = showMenu
        self.maxZoom = maxZoom
        self._crownPosition = crownPosition
        self.onUpdateZoomRanges = onUpdateZoomRanges
        self._selectedEdgeID = selectedEdgeID
        self._showOverlays = showOverlays
        self._isAddingEdge = isAddingEdge
    }
    
    private var boundingBoxOverlay: some View {
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
        return Rectangle()
            .stroke(Color.blue, lineWidth: 2)
            .frame(width: scaledBounds.width, height: scaledBounds.height)
            .position(x: scaledBounds.midX, y: scaledBounds.midY)
            .opacity(0.5)
    }
    
    private var accessibleCanvas: some View {
        ZStack {
            Canvas { context, size in
                // Define visibleNodes and visibleEdges
                let visibleNodes = viewModel.model.visibleNodes()
                let visibleEdges = viewModel.model.visibleEdges()  // Fix: Use visibleEdges() instead of all edges
                let hiddenIDs = viewModel.model.hiddenNodeIDs.map { $0.uuidString.prefix(8) }
                print("Visible: \(visibleNodes.count), Hidden IDs: \(hiddenIDs)")
                
                if visibleNodes.isEmpty {
                    print("Warning: No visible nodes")  // Transient; remove if desired
                    return
                }
                
                // Compute effectiveCentroid: True model center (fixes panning/offset)
                let effectiveCentroid = centroid(of: visibleNodes)  // Non-optional CGPoint
                
                print("Drawing: \(visibleNodes.count) nodes, \(visibleEdges.count) edges | Centroid: \(effectiveCentroid) | Zoom: \(zoomScale) | Offset: \(offset)")  // Debug
                
                // Draw elements using helpers
                drawNodes(in: context, size: size, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid)
                drawEdgeLines(in: context, size: size, visibleEdges: visibleEdges, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid)
                drawEdgeArrows(in: context, size: size, visibleEdges: visibleEdges, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid)
                drawDraggedNodeAndPotentialEdge(in: context, size: size, effectiveCentroid: effectiveCentroid)
            }
            .frame(width: viewSize.width, height: viewSize.height)
            .accessibilityLabel(viewModel.model.graphDescription(selectedID: selectedNodeID, selectedEdgeID: selectedEdgeID))
            .accessibilityIdentifier("GraphCanvas")  // Add this line
            .accessibilityHint("Tap menu button on bottom edge.")
            
            if showOverlays {
                boundingBoxOverlay
            }
            
            if let selectedID = selectedNodeID {
                Text("Selected: \(selectedID.uuidString.prefix(8))")  // Debug label
                    .position(x: 20, y: 10)
                    .foregroundColor(.yellow)
            }
        }
    }
    
    private func centroid(of nodes: [any NodeProtocol]) -> CGPoint {
        guard !nodes.isEmpty else { return .zero }  // Safe default (no optional)
        let sumX = nodes.reduce(0.0) { $0 + $1.position.x }
        let sumY = nodes.reduce(0.0) { $0 + $1.position.y }
        return CGPoint(x: sumX / CGFloat(nodes.count), y: sumY / CGFloat(nodes.count))
    }
    
    var body: some View {
        Group {
            FocusableView {  // Reverted: No crown params
                accessibleCanvas
            }
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
                onUpdateZoomRanges: onUpdateZoomRanges,
                isAddingEdge: $isAddingEdge  // Pass to modifier
            ))
        }
        .onChange(of: selectedNodeID) {
            viewModel.saveViewState()  // Existing: Triggers view state save on selection change
        }
        .onChange(of: selectedEdgeID) {
            viewModel.saveViewState()  // Existing
        }
        .onChange(of: offset) {  // NEW: Save on offset/zoom changes for full view persistence
            viewModel.saveViewState()
        }
        .onChange(of: zoomScale) {
            viewModel.saveViewState()
        }
        .ignoresSafeArea()
    }
}

extension GraphCanvasView {
    func drawNodes(in context: GraphicsContext, size: CGSize, visibleNodes: [any NodeProtocol], effectiveCentroid: CGPoint) {
        // Pass 0: Draw nodes FIRST (under edges/arrows)
        for node in visibleNodes {
            let screenPos = CoordinateTransformer.modelToScreen(
                node.position,
                effectiveCentroid: effectiveCentroid,
                zoomScale: zoomScale,
                offset: offset,
                viewSize: size
            )
            let isSelected = (node.id == selectedNodeID)
            print("Drawing node \(node.label) at screen \(screenPos), selected: \(isSelected)")  // Debug
            node.draw(in: context, at: screenPos, zoomScale: zoomScale, isSelected: isSelected)
        }
    }
    
    func drawEdgeLines(in context: GraphicsContext, size: CGSize, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], effectiveCentroid: CGPoint) {
        // Pass 1: Draw edges (lines only)
        for edge in visibleEdges {
            guard let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                  let toNode = visibleNodes.first(where: { $0.id == edge.target }) else { continue }
            
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
            if length <= 0 { continue }
            
            let unitDx = direction.dx / length
            let unitDy = direction.dy / length
            let fromRadiusScreen = fromNode.radius * zoomScale
            let toRadiusScreen = toNode.radius * zoomScale
            let margin: CGFloat = 3.0
            
            let isSelected = edge.id == selectedEdgeID
            let lineColor: Color = isSelected ? .red : .gray
            let lineWidth: CGFloat = 3.0
            
            let startPoint = CGPoint(x: fromScreen.x + unitDx * (fromRadiusScreen + margin),
                                     y: fromScreen.y + unitDy * (fromRadiusScreen + margin))
            let endPoint = CGPoint(x: toScreen.x - unitDx * (toRadiusScreen + margin),
                                   y: toScreen.y - unitDy * (toRadiusScreen + margin))
            
            let linePath = Path { path in
                path.move(to: startPoint)
                path.addLine(to: endPoint)
            }
            
            context.stroke(linePath, with: .color(lineColor), lineWidth: lineWidth)
            print("Drawing line for edge \(edge.id.uuidString.prefix(8)) from \(startPoint) to \(endPoint)")  // Debug
        }
    }
    
    func drawEdgeArrows(in context: GraphicsContext, size: CGSize, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], effectiveCentroid: CGPoint) {
        // Pass 2: Draw arrows (over lines)
        for edge in visibleEdges {
            guard let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                  let toNode = visibleNodes.first(where: { $0.id == edge.target }) else { continue }
            
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
            if length <= 0 { continue }
            
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
            
            let isSelected = edge.id == selectedEdgeID
            let arrowColor: Color = isSelected ? .red : .gray
            let arrowLineWidth: CGFloat = 3.0
            
            context.stroke(arrowPath, with: .color(arrowColor), lineWidth: arrowLineWidth)
            print("Drawing arrow for edge \(edge.id.uuidString.prefix(8)) to boundary \(boundaryPoint)")  // Debug
        }
    }
    
    func drawDraggedNodeAndPotentialEdge(in context: GraphicsContext, size: CGSize, effectiveCentroid: CGPoint) {
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
