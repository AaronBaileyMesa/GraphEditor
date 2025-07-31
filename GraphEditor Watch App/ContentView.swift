import SwiftUI

struct ContentView: View {
    @StateObject var graph = GraphModel()
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var panStartOffset: CGSize?  // New: for correct panning
    @State private var draggedNode: Node? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var potentialEdgeTarget: Node? = nil  // New: for edge creation
    
    var body: some View {
        Canvas { context, size in
            let transform = CGAffineTransform(translationX: offset.width, y: offset.height)
                .scaledBy(x: scale, y: scale)
            
            // Draw edges
            for edge in graph.edges {
                if let fromNode = graph.nodes.first(where: { $0.id == edge.from }),
                   let toNode = graph.nodes.first(where: { $0.id == edge.to }) {
                    let fromPos = (draggedNode?.id == fromNode.id ? fromNode.position + dragOffset : fromNode.position).applying(transform)
                    let toPos = (draggedNode?.id == toNode.id ? toNode.position + dragOffset : toNode.position).applying(transform)
                    context.stroke(Path { path in
                        path.move(to: fromPos)
                        path.addLine(to: toPos)
                    }, with: .color(.blue), lineWidth: 2 / scale)
                }
            }
            
            // Draw potential new edge during drag
            if let dragged = draggedNode, let target = potentialEdgeTarget {
                let fromPos = (dragged.position + dragOffset).applying(transform)
                let toPos = target.position.applying(transform)
                context.stroke(Path { path in
                    path.move(to: fromPos)
                    path.addLine(to: toPos)
                }, with: .color(.green), style: StrokeStyle(lineWidth: 2 / scale, dash: [5]))
            }
            
            // Draw nodes
            for node in graph.nodes {
                let pos = (draggedNode?.id == node.id ? node.position + dragOffset : node.position).applying(transform)
                context.fill(Circle().path(in: CGRect(x: pos.x - 10 / scale, y: pos.y - 10 / scale, width: 20 / scale, height: 20 / scale)), with: .color(.red))
            }
        }
        .gesture(DragGesture()
            .onChanged { value in
                let inverseTransform = CGAffineTransform(translationX: offset.width, y: offset.height)
                    .scaledBy(x: scale, y: scale)
                    .inverted()
                if draggedNode == nil {
                    let touchPos = value.startLocation.applying(inverseTransform)
                    if let hitNode = graph.nodes.first(where: { distance($0.position, touchPos) < 20 / scale }) {
                        draggedNode = hitNode
                    }
                }
                if let dragged = draggedNode {
                    dragOffset = CGSize(width: value.translation.width / scale, height: value.translation.height / scale)
                    // Check for potential edge target
                    let currentPos = (dragged.position + dragOffset).applying(inverseTransform)  // World pos of finger
                    potentialEdgeTarget = graph.nodes.first {
                        $0.id != dragged.id && distance($0.position, currentPos) < 20 / scale
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
                                .scaledBy(x: scale, y: scale)
                                .inverted()
                        )
                        graph.nodes.append(Node(position: touchPos))
                        graph.startSimulation()  // Re-run sim after add
                    }
                }
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
                    offset = panStartOffset! + CGSize(width: value.translation.width / scale, height: value.translation.height / scale)
                }
            }
            .onEnded { _ in
                panStartOffset = nil
            }
        )
        .focusable()
        .digitalCrownRotation($scale, from: 0.5, through: 2.0, sensitivity: .high, isContinuous: false)
        .ignoresSafeArea()
        .onAppear {
            graph.startSimulation()
        }
        .onDisappear {
            graph.stopSimulation()
        }
    }
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

#Preview {
    ContentView()
}
