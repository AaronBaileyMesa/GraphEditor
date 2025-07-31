import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject var graph = GraphModel()
    @State private var zoomScale: CGFloat = 1.0
    @State private var minZoom: CGFloat = 0.2
    @State private var maxZoom: CGFloat = 5.0
    @State private var crownPosition: Double = 2.5
    @State private var viewSize: CGSize = .zero
    @State private var offset: CGSize = .zero
    @State private var panStartOffset: CGSize?
    @State private var draggedNode: Node? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var potentialEdgeTarget: Node? = nil
    @State private var ignoreNextCrownChange: Bool = false
    
    let numZoomLevels = 6
    let nodeModelRadius: CGFloat = 10.0
    let hitScreenRadius: CGFloat = 30.0  // For easier tapping
    
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let transform = CGAffineTransform(translationX: offset.width, y: offset.height)
                    .scaledBy(x: zoomScale, y: zoomScale)
                
                // Draw edges
                for edge in graph.edges {
                    if let fromNode = graph.nodes.first(where: { $0.id == edge.from }),
                       let toNode = graph.nodes.first(where: { $0.id == edge.to }) {
                        let fromPos = (draggedNode?.id == fromNode.id ? fromNode.position + dragOffset : fromNode.position).applying(transform)
                        let toPos = (draggedNode?.id == toNode.id ? toNode.position + dragOffset : toNode.position).applying(transform)
                        context.stroke(Path { path in
                            path.move(to: fromPos)
                            path.addLine(to: toPos)
                        }, with: .color(.blue), lineWidth: 2 * zoomScale)
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
                for node in graph.nodes {
                    let pos = (draggedNode?.id == node.id ? node.position + dragOffset : node.position).applying(transform)
                    let scaledRadius = nodeModelRadius * zoomScale
                    context.fill(Path(ellipseIn: CGRect(x: pos.x - scaledRadius, y: pos.y - scaledRadius, width: 2 * scaledRadius, height: 2 * scaledRadius)), with: .color(.red))
                }
            }
            .gesture(DragGesture()
                .onChanged { value in
                    let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                        .scaledBy(x: zoomScale, y: zoomScale)
                        .inverted()
                    if draggedNode == nil {
                        let touchPos = value.startLocation.applying(inverseTransform)
                        if let hitNode = graph.nodes.first(where: { distance($0.position, touchPos) < hitScreenRadius / zoomScale }) {
                            draggedNode = hitNode
                        }
                    }
                    if let dragged = draggedNode {
                        dragOffset = CGSize(width: value.translation.width / zoomScale, height: value.translation.height / zoomScale)
                        // Check for potential edge target
                        let currentPos = value.location.applying(inverseTransform)
                        potentialEdgeTarget = graph.nodes.first {
                            $0.id != dragged.id && distance($0.position, currentPos) < hitScreenRadius / zoomScale
                        }
                    }
                }
                .onEnded { value in
                    if let node = draggedNode,
                       let index = graph.nodes.firstIndex(where: { $0.id == node.id }) {
                        if let target = potentialEdgeTarget, target.id != node.id,
                           !graph.edges.contains(where: { ($0.from == node.id && $0.to == target.id) || ($0.from == target.id && $0.to == node.id) }) {
                            // Add edge instead of moving
                            graph.edges.append(Edge(from: node.id, to: target.id))
                            graph.startSimulation()  // Re-run sim after edit
                        } else {
                            // Move node
                            var updatedNode = graph.nodes[index]
                            updatedNode.position += dragOffset
                            graph.nodes[index] = updatedNode
                        }
                    } else {
                        // Tap (short drag): add node
                        if value.translation.width == 0 && value.translation.height == 0 {
                            let touchPos = value.location.applying(
                                CGAffineTransform(translationX: offset.width, y: offset.height)
                                    .scaledBy(x: zoomScale, y: zoomScale)
                                    .inverted()
                            )
                            graph.nodes.append(Node(position: touchPos))
                            graph.startSimulation()  // Re-run sim after add
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
            .onAppear {
                viewSize = geo.size
                updateZoomRanges()
            }
            .onChange(of: geo.size) { oldSize, newSize in
                viewSize = newSize
                updateZoomRanges()
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
            graph.startSimulation()
        }
        .onDisappear {
            graph.stopSimulation()
        }
    }
    
    private func updateZoomRanges() {
        guard viewSize != .zero else { return }
        
        if graph.nodes.isEmpty {
            minZoom = 0.5
            maxZoom = 2.0
            let midCrown = Double(numZoomLevels - 1) / 2.0
            if midCrown != crownPosition {
                ignoreNextCrownChange = true
                crownPosition = midCrown
            }
            return
        }
        
        let bbox = graph.boundingBox()
        let graphWidth = Swift.max(bbox.width, CGFloat(20)) + CGFloat(20)
        let graphHeight = Swift.max(bbox.height, CGFloat(20)) + CGFloat(20)
        let graphDia = Swift.max(graphWidth, graphHeight)
        let targetDia = Swift.min(viewSize.width, viewSize.height) / CGFloat(3)
        let newMinZoom = targetDia / graphDia
        
        let nodeDia = 2 * nodeModelRadius
        let targetNodeDia = Swift.min(viewSize.width, viewSize.height) * (CGFloat(2) / CGFloat(3))
        let newMaxZoom = targetNodeDia / nodeDia
        
        minZoom = newMinZoom
        maxZoom = Swift.max(newMaxZoom, newMinZoom * CGFloat(2))  // Ensure max > min
        
        // Adjust crownPosition to keep current scale if possible
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
        if abs(newCrown - crownPosition) > 1e-6 {  // Avoid unnecessary set
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
