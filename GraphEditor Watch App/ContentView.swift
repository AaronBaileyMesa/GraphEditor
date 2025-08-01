import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject var viewModel = GraphViewModel(model: GraphModel())
    @State private var zoomScale: CGFloat = 1.0
    @State private var minZoom: CGFloat = 0.2
    @State private var maxZoom: CGFloat = 5.0
    @State private var crownPosition: Double = 2.5
    @State private var viewSize: CGSize = .zero
    @State private var offset: CGSize = .zero
    @State private var panStartOffset: CGSize?
    @State private var draggedNode: Node? = nil
    @State private var dragOffset: CGPoint = .zero  // Changed to CGPoint
    @State private var potentialEdgeTarget: Node? = nil
    @State private var ignoreNextCrownChange: Bool = false
    @State private var selectedNodeID: UUID? = nil
    @State private var showMenu = false
    
    let numZoomLevels = 6
    let nodeModelRadius: CGFloat = 10.0
    let hitScreenRadius: CGFloat = 30.0
    let tapThreshold: CGFloat = 10.0
    
    var body: some View {
        GeometryReader { geo in
            let _ = print("GeometryReader rendered. Size: \(geo.size)")
            Canvas { context, size in
                print("Rendering Canvas. Size: \(size), Scale: \(zoomScale), Offset: \(offset)")
                let transform = CGAffineTransform(translationX: offset.width, y: offset.height)
                    .scaledBy(x: zoomScale, y: zoomScale)
                
                // Draw edges and their labels
                for edge in viewModel.model.edges {
                    if let fromNode = viewModel.model.nodes.first(where: { $0.id == edge.from }),
                       let toNode = viewModel.model.nodes.first(where: { $0.id == edge.to }),
                       let fromIndex = viewModel.model.nodes.firstIndex(where: { $0.id == edge.from }),
                       let toIndex = viewModel.model.nodes.firstIndex(where: { $0.id == edge.to }) {
                        let fromPos = (draggedNode?.id == fromNode.id ? fromNode.position + dragOffset : fromNode.position).applying(transform)
                        let toPos = (draggedNode?.id == toNode.id ? toNode.position + dragOffset : toNode.position).applying(transform)
                        context.stroke(Path { path in
                            path.move(to: fromPos)
                            path.addLine(to: toPos)
                        }, with: .color(.blue), lineWidth: 2 * zoomScale)
                        
                        // Draw edge label at midpoint
                        let midpoint = CGPoint(x: (fromPos.x + toPos.x) / 2, y: (fromPos.y + toPos.y) / 2)
                        let fromLabel = fromIndex + 1
                        let toLabel = toIndex + 1
                        let edgeLabel = "\(min(fromLabel, toLabel))-\(max(fromLabel, toLabel))"
                        let fontSize = UIFontMetrics.default.scaledValue(for: 12) * zoomScale
                        let text = Text(edgeLabel).foregroundColor(.white).font(.system(size: fontSize))
                        let resolvedText = context.resolve(text)
                        context.draw(resolvedText, at: midpoint, anchor: .center)
                    }
                }
                
                // Draw potential new edge during drag
                if let dragged = draggedNode, let target = potentialEdgeTarget {
                    let fromPos = (dragged.position + dragOffset).applying(transform)
                    let toPos = target.position.applying(transform)
                    context.stroke(Path { path in
                        path.move(to: fromPos)
                        path.addLine(to: toPos)
                    }, with: .color(.green), style: StrokeStyle(lineWidth: 2 * zoomScale, dash: [5 * zoomScale]))
                }
                
                // Draw nodes
                for (index, node) in viewModel.model.nodes.enumerated() {
                    let pos = (draggedNode?.id == node.id ? node.position + dragOffset : node.position).applying(transform)
                    let scaledRadius = nodeModelRadius * zoomScale
                    context.fill(Path(ellipseIn: CGRect(x: pos.x - scaledRadius, y: pos.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius)), with: .color(.red))
                    if node.id == selectedNodeID {
                        let borderWidth = 4 * zoomScale
                        let borderRadius = scaledRadius + borderWidth / 2
                        context.stroke(Path(ellipseIn: CGRect(x: pos.x - borderRadius, y: pos.y - borderRadius, width: 2 * borderRadius, height: 2 * borderRadius)), with: .color(.white), lineWidth: borderWidth)
                    }
                    // Draw node number
                    let fontSize = UIFontMetrics.default.scaledValue(for: 12) * zoomScale
                    let text = Text("\(index + 1)").foregroundColor(.white).font(.system(size: fontSize))
                    let resolvedText = context.resolve(text)
                    context.draw(resolvedText, at: pos, anchor: .center)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(graphDescription())
            .accessibilityHint("Double-tap for menu. Long press to delete selected.")
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    print("Drag changed. Translation: \(value.translation)")
                    let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                        .scaledBy(x: zoomScale, y: zoomScale)
                        .inverted()
                    if draggedNode == nil {
                        let touchPos = value.startLocation.applying(inverseTransform)
                        if let hitNode = viewModel.model.nodes.first(where: { distance($0.position, touchPos) < hitScreenRadius / zoomScale }) {
                            draggedNode = hitNode
                        }
                    }
                    if let dragged = draggedNode {
                        dragOffset = CGPoint(x: value.translation.width / zoomScale, y: value.translation.height / zoomScale)  // Converted to CGPoint
                        let currentPos = value.location.applying(inverseTransform)
                        potentialEdgeTarget = viewModel.model.nodes.first {
                            $0.id != dragged.id && distance($0.position, currentPos) < hitScreenRadius / zoomScale
                        }
                    }
                }
                .onEnded { value in
                    print("Drag ended. Translation: \(value.translation)")
                    let dragDistance = hypot(value.translation.width, value.translation.height)
                    if let node = draggedNode,
                       let index = viewModel.model.nodes.firstIndex(where: { $0.id == node.id }) {
                        viewModel.snapshot()
                        if dragDistance < tapThreshold {
                            if selectedNodeID == node.id {
                                selectedNodeID = nil
                            } else {
                                selectedNodeID = node.id
                                WKInterfaceDevice.current().play(.click)
                                if zoomScale < maxZoom * 0.8 {
                                    crownPosition = Double(numZoomLevels - 1)
                                }
                                let viewCenter = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
                                let worldPoint = node.position
                                offset = CGSize(width: viewCenter.x - worldPoint.x * zoomScale, height: viewCenter.y - worldPoint.y * zoomScale)
                            }
                        } else {
                            if let target = potentialEdgeTarget, target.id != node.id,
                               !viewModel.model.edges.contains(where: { ($0.from == node.id && $0.to == target.id) || ($0.from == target.id && $0.to == node.id) }) {
                                viewModel.model.edges.append(Edge(from: node.id, to: target.id))
                                viewModel.model.startSimulation()
                            } else {
                                var updatedNode = viewModel.model.nodes[index]
                                updatedNode.position = updatedNode.position + dragOffset  // Using + on CGPoint
                                viewModel.model.nodes[index] = updatedNode
                            }
                        }
                    } else {
                        if dragDistance < tapThreshold {
                            selectedNodeID = nil
                            viewModel.snapshot()
                            let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                                .scaledBy(x: zoomScale, y: zoomScale)
                                .inverted()
                            let touchPos = value.location.applying(inverseTransform)
                            viewModel.model.nodes.append(Node(position: touchPos))
                            viewModel.model.startSimulation()
                        }
                    }
                    updateZoomRanges()
                    draggedNode = nil
                    dragOffset = .zero
                    potentialEdgeTarget = nil
                }
            )
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if draggedNode == nil {
                        if panStartOffset == nil {
                            panStartOffset = offset
                        }
                        offset = panStartOffset! + CGSize(width: value.translation.width / zoomScale, height: value.translation.height / zoomScale)
                    }
                }
                .onEnded { _ in
                    panStartOffset = nil
                }
            )
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if let id = selectedNodeID {
                        viewModel.deleteNode(withID: id)
                        selectedNodeID = nil
                        WKInterfaceDevice.current().play(.success)
                    }
                }
            )
            .simultaneousGesture(TapGesture(count: 2)
                .onEnded {
                    showMenu = true
                }
            )
            .onAppear {
                viewSize = geo.size
                updateZoomRanges()
                print("GeometryReader onAppear. View size: \(viewSize)")
            }
        }
        .sheet(isPresented: $showMenu) {
            VStack {
                Button("New Graph") {
                    viewModel.snapshot()
                    viewModel.model.nodes = []
                    viewModel.model.edges = []
                    showMenu = false
                }
                if let selected = selectedNodeID {
                    Button("Delete Selected") {
                        viewModel.deleteNode(withID: selected)
                        selectedNodeID = nil
                        showMenu = false
                    }
                }
                Button("Undo") {
                    viewModel.undo()
                    showMenu = false
                }
                Button("Redo") {
                    viewModel.redo()
                    showMenu = false
                }
            }
        }
        .focusable()
        .digitalCrownRotation($crownPosition, from: 0.0, through: Double(numZoomLevels - 1), sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crownPosition) { oldValue, newValue in
            if ignoreNextCrownChange {
                ignoreNextCrownChange = false
                updateZoomScale(oldCrown: oldValue, adjustOffset: false)
                return
            }
            
            let maxCrown = Double(numZoomLevels - 1)
            let clampedValue = newValue.clamped(to: 0...maxCrown)
            if clampedValue != newValue {
                ignoreNextCrownChange = true
                crownPosition = clampedValue
                return
            }
            
            if floor(newValue) != floor(oldValue) {
                WKInterfaceDevice.current().play(.click)
            }
            updateZoomScale(oldCrown: oldValue, adjustOffset: true)
        }
        .ignoresSafeArea()
        .onAppear {
            viewModel.model.startSimulation()
            print("ContentView onAppear. Nodes: \(viewModel.model.nodes.count), Scale: \(zoomScale), Offset: \(offset)")
        }
        .onDisappear {
            viewModel.model.stopSimulation()
            print("ContentView onDisappear")
        }
    }
    
    private func graphDescription() -> String {
        "Graph with \(viewModel.model.nodes.count) nodes and \(viewModel.model.edges.count) edges. \(selectedNodeID != nil ? "Node selected." : "No node selected.")"
    }
    
    private func updateZoomRanges() {
        guard viewSize != .zero else { return }
        print("Updating zoom ranges. View size: \(viewSize)")
        
        if viewModel.model.nodes.isEmpty {
            minZoom = 0.5
            maxZoom = 2.0
            let midCrown = Double(numZoomLevels - 1) / 2.0
            if midCrown != crownPosition {
                ignoreNextCrownChange = true
                crownPosition = midCrown
            }
            return
        }
        
        let bbox = viewModel.model.boundingBox()
        let graphWidth = Swift.max(bbox.width, CGFloat(20)) + CGFloat(20)
        let graphHeight = Swift.max(bbox.height, CGFloat(20)) + CGFloat(20)
        let graphDia = Swift.max(graphWidth, graphHeight)
        let targetDia = Swift.min(viewSize.width, viewSize.height) / CGFloat(3)
        let newMinZoom = targetDia / graphDia
        
        let nodeDia = 2 * nodeModelRadius
        let targetNodeDia = Swift.min(viewSize.width, viewSize.height) * (CGFloat(2) / CGFloat(3))
        let newMaxZoom = targetNodeDia / nodeDia
        
        minZoom = newMinZoom
        maxZoom = Swift.max(newMaxZoom, newMinZoom * CGFloat(2))
        
        let currentScale = zoomScale
        var progress: CGFloat = 0.5
        if minZoom < currentScale && currentScale < maxZoom && minZoom > 0 && maxZoom > minZoom {
            progress = CGFloat(log(Double(currentScale / minZoom)) / log(Double(maxZoom / minZoom)))
        } else if currentScale <= minZoom {
            progress = 0.0
        } else {
            progress = 1.0
        }
        let newCrown = Double(progress * CGFloat(numZoomLevels - 1))
        if abs(newCrown - crownPosition) > 1e-6 {
            ignoreNextCrownChange = true
            crownPosition = newCrown
        }
    }
    
    private func updateZoomScale(oldCrown: Double, adjustOffset: Bool) {
        let oldProgress = oldCrown / Double(numZoomLevels - 1)
        let oldScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), oldProgress))
        
        let newProgress = crownPosition / Double(numZoomLevels - 1)
        let newScale = minZoom * CGFloat(pow(Double(maxZoom / minZoom), newProgress))
        
        if adjustOffset && oldScale != newScale && viewSize != .zero {
            let focus = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
            let worldFocus = CGPoint(x: (focus.x - offset.width) / oldScale, y: (focus.y - offset.height) / oldScale)
            offset = CGSize(width: focus.x - worldFocus.x * newScale, height: focus.y - worldFocus.y * newScale)
        }
        
        zoomScale = newScale
        print("Zoom updated. New scale: \(zoomScale), Offset: \(offset)")
    }
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

#Preview {
    ContentView()
}
