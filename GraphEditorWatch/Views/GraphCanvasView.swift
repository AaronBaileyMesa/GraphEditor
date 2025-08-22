import SwiftUI
import WatchKit
import GraphEditorShared

// New: Custom wrapper for reliable crown focus
struct FocusableView<Content: View>: View {
    let content: Content
    @FocusState private var isFocused: Bool
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .focused($isFocused)
            .onAppear {
                isFocused = true
            }
            .onChange(of: isFocused) { oldValue, newValue in  // Or just { _, newValue in
                if newValue {
                    print("View focused for crown")  // Optional debug
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
    @State private var zoomTimer: Timer? = nil
    @Binding var selectedEdgeID: UUID?
    @Binding var showOverlays: Bool
    
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
        onUpdateZoomRanges: @escaping() -> Void,
        selectedEdgeID: Binding<UUID?>,
        showOverlays: Binding<Bool>,
    //let onUpdateZoomRanges: @escaping () -> Void
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
    }
    
    private var boundingBoxOverlay: some View {
        let graphBounds = viewModel.model.physicsEngine.boundingBox(nodes: viewModel.model.nodes)
        let scaledBounds = CGRect(
            x: (graphBounds.minX - viewModel.effectiveCentroid.x) * zoomScale + viewSize.width / 2 + offset.width,
            y: (graphBounds.minY - viewModel.effectiveCentroid.y) * zoomScale + viewSize.height / 2 + offset.height,
            width: graphBounds.width * zoomScale,
            height: graphBounds.height * zoomScale
        )
        return Rectangle()
            .stroke(Color.blue, lineWidth: 2)
            .frame(width: scaledBounds.width, height: scaledBounds.height)
            .position(x: scaledBounds.midX, y: scaledBounds.midY)
            .opacity(0.5)
    }
    
    private var accessibleCanvas: some View {
        ZStack {
            Canvas { context, size in
                let visibleNodes = viewModel.model.visibleNodes()
                let visibleEdges = viewModel.model.visibleEdges()
                
                let effectiveCentroid = viewModel.effectiveCentroid
                
                // Draw edges first
                for edge in visibleEdges {
                    if let fromNode = visibleNodes.first(where: { $0.id == edge.from }),
                       let toNode = visibleNodes.first(where: { $0.id == edge.to }) {
                        let fromScreen = modelToScreen(fromNode.position, effectiveCentroid: effectiveCentroid, size: size)
                        let toScreen = modelToScreen(toNode.position, effectiveCentroid: effectiveCentroid, size: size)
                        
                        let path = Path { path in
                            path.move(to: fromScreen)
                            path.addLine(to: toScreen)
                        }
                        
                        context.stroke(path, with: .color(edge.id == selectedEdgeID ? .red : .gray), lineWidth: 2)
                        
                        // Arrowhead
                        let arrowLength: CGFloat = 10
                        let arrowAngle: CGFloat = .pi / 6
                        let lineAngle = atan2(toScreen.y - fromScreen.y, toScreen.x - fromScreen.x)
                        
                        let arrowPoint1 = CGPoint(
                            x: toScreen.x - arrowLength * cos(lineAngle - arrowAngle),
                            y: toScreen.y - arrowLength * sin(lineAngle - arrowAngle)
                        )
                        let arrowPoint2 = CGPoint(
                            x: toScreen.x - arrowLength * cos(lineAngle + arrowAngle),
                            y: toScreen.y - arrowLength * sin(lineAngle + arrowAngle)
                        )
                        
                        let arrowPath = Path { path in
                            path.move(to: toScreen)
                            path.addLine(to: arrowPoint1)
                            path.move(to: toScreen)
                            path.addLine(to: arrowPoint2)
                        }
                        
                        context.stroke(arrowPath, with: .color(edge.id == selectedEdgeID ? .red : .gray), lineWidth: 2)
                    }
                }
                
                // Draw nodes
                for node in visibleNodes {
                    let screenPos = modelToScreen(node.position, effectiveCentroid: effectiveCentroid, size: size)
                    node.draw(in: context, at: screenPos, zoomScale: zoomScale, isSelected: node.id == selectedNodeID)
                }
                
                // Draw dragged node and potential edge
                if let dragged = draggedNode {
                    let draggedScreen = modelToScreen(dragged.position + dragOffset, effectiveCentroid: effectiveCentroid, size: size)
                    context.fill(Circle().path(in: CGRect(center: draggedScreen, size: CGSize(width: Constants.App.nodeModelRadius * 2, height: Constants.App.nodeModelRadius * 2))), with: .color(.green))
                    
                    if let target = potentialEdgeTarget {
                        let targetScreen = modelToScreen(target.position, effectiveCentroid: effectiveCentroid, size: size)
                        context.stroke(Line(from: draggedScreen, to: targetScreen).path(in: CGRect(origin: .zero, size: size)), with: .color(.green), lineWidth: 2)
                    }
                }
            }
            .frame(width: viewSize.width, height: viewSize.height)
            
            if showOverlays {
                boundingBoxOverlay
            }
        }
    }
    
    private func modelToScreen(_ modelPos: CGPoint, effectiveCentroid: CGPoint, size: CGSize) -> CGPoint {
        let viewCenter = CGPoint(x: size.width / 2, y: size.height / 2)
        let relativePos = modelPos - effectiveCentroid
        let scaledPos = relativePos * zoomScale
        return viewCenter + scaledPos + CGPoint(x: offset.width, y: offset.height)
    }
    
    var body: some View {
        Group {
            FocusableView {
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

struct Line: Shape, Animatable {
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
