import SwiftUI
import WatchKit
import GraphEditorShared
import os  // Added for logging

// Reverted: Custom wrapper for reliable crown focus (without crown—handled in ContentView now)
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

struct GraphCanvasView: View {
    private static var logger: Logger {
        Logger(subsystem: "io.handcart.GraphEditor", category: "graphcanvasview")  // Changed to computed static for consistency
    }
    
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
                
                #if DEBUG
                Self.logger.debug("Visible: \(visibleNodes.count)")
                #endif
                
                let effectiveCentroid = viewModel.effectiveCentroid
                
                // Draw edges (Pass 1: Lines only)
                drawEdges(in: context, size: size, visibleEdges: visibleEdges, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid)
                
                // Draw nodes
                for node in visibleNodes {
                    let nodeScreen = CoordinateTransformer.modelToScreen(
                        node.position,
                        effectiveCentroid: effectiveCentroid,
                        zoomScale: zoomScale,
                        offset: offset,
                        viewSize: size
                    )
                    let nodeRadius = Constants.App.nodeModelRadius * zoomScale
                    
                    let isSelected = node.id == selectedNodeID
                    let nodeColor: Color = isSelected ? .red : .blue
                    let nodePath = Circle().path(in: CGRect(center: nodeScreen, size: CGSize(width: nodeRadius * 2, height: nodeRadius * 2)))
                    context.fill(nodePath, with: .color(nodeColor))
                    
                    // Draw label
                    let labelText = Text("\(node.label)").font(.system(size: 12 * zoomScale))
                    context.draw(labelText, at: nodeScreen, anchor: .center)
                }
                
                // Draw arrows (Pass 2: Over lines)
                drawArrows(in: context, size: size, visibleEdges: visibleEdges, visibleNodes: visibleNodes, effectiveCentroid: effectiveCentroid)
                
                // Draw dragged node and potential edge
                drawDraggedNodeAndPotentialEdge(in: context, size: size, effectiveCentroid: effectiveCentroid)
            }
            .frame(width: viewSize.width, height: viewSize.height)
            .accessibilityLabel(accessibilityLabel())
            .accessibilityIdentifier("GraphCanvas")
            
            if showOverlays {
                boundingBoxOverlay
            }
        }
    }
    
    var body: some View {
        FocusableView {
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
                    onUpdateZoomRanges: onUpdateZoomRanges,
                    isAddingEdge: $isAddingEdge
                ))
        }
    }
    
    private func accessibilityLabel() -> String {
        let nodeCount = viewModel.model.nodes.count
        let edgeCount = viewModel.model.edges.count

        // Selected node label
        let selectedNodeLabel: String = {
            guard let id = selectedNodeID,
                  let node = viewModel.model.nodes.first(where: { $0.id == id })
            else { return "No node selected" }
            return "Node \(node.label) selected"
        }()

        // Selected edge label
        let selectedEdgeLabel: String = {
            guard let id = selectedEdgeID,
                  let edge = viewModel.model.edges.first(where: { $0.id == id })
            else { return "No edge selected" }
            let fromLabel = viewModel.model.nodes.first(where: { $0.id == edge.from })?.label
            let toLabel = viewModel.model.nodes.first(where: { $0.id == edge.target })?.label
            let fromText = fromLabel.map { String(describing: $0) } ?? "?"
            let toText = toLabel.map { String(describing: $0) } ?? "?"
            return "Edge from \(fromText) to \(toText) selected"
        }()

        return "Graph with \(nodeCount) nodes and \(edgeCount) edges. \(selectedNodeLabel). \(selectedEdgeLabel)."
    }
    
    // Extracted: Draw edges (lines only)
    func drawEdges(in context: GraphicsContext, size: CGSize, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], effectiveCentroid: CGPoint) {
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
            
            let linePath = Path { path in
                path.move(to: fromScreen)
                path.addLine(to: toScreen)
            }
            
            let isSelected = edge.id == selectedEdgeID
            let edgeColor: Color = isSelected ? .red : .gray
            let lineWidth: CGFloat = 2.0
            
            context.stroke(linePath, with: .color(edgeColor), lineWidth: lineWidth)
            
            #if DEBUG
            Self.logger.debug("Drawing edge from x=\(fromScreen.x), y=\(fromScreen.y) to x=\(toScreen.x), y=\(toScreen.y) with color \(edgeColor.description)")
            #endif
        }
    }
    
    // Extracted: Draw arrows (over lines)
    func drawArrows(in context: GraphicsContext, size: CGSize, visibleEdges: [GraphEdge], visibleNodes: [any NodeProtocol], effectiveCentroid: CGPoint) {
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
            
            #if DEBUG
            Self.logger.debug("Drawing arrow for edge \(edge.id.uuidString.prefix(8)) to boundary x=\(boundaryPoint.x), y=\(boundaryPoint.y)")
            #endif
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
