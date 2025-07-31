import SwiftUI
import Combine  // For Timer

struct Node: Identifiable, Equatable {
    let id: UUID = UUID()
    var position: CGPoint
    var velocity: CGPoint = .zero
}

struct Edge: Identifiable {
    let id: UUID = UUID()
    let from: UUID
    let to: UUID
}

class GraphModel: ObservableObject {
    @Published var nodes: [Node]
    @Published var edges: [Edge]
    
    // Physics constants (tuned for stability)
    let stiffness: CGFloat = 0.01
    let repulsion: CGFloat = 15000
    let damping: CGFloat = 0.95
    let idealLength: CGFloat = 100
    let centeringForce: CGFloat = 0.001  // Weak pull to center
    
    private var timer: Timer?
    
    init() {
        nodes = [
            Node(position: CGPoint(x: 100, y: 100)),
            Node(position: CGPoint(x: 200, y: 200)),
            Node(position: CGPoint(x: 150, y: 300))
        ]
        edges = []
        if nodes.count >= 3 {
            edges = [
                Edge(from: nodes[0].id, to: nodes[1].id),
                Edge(from: nodes[1].id, to: nodes[2].id),
                Edge(from: nodes[2].id, to: nodes[0].id)
            ]
        }
    }
    
    func startSimulation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            self?.applyPhysics()
        }
    }
    
    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }
    
    private func applyPhysics() {
        var forces: [UUID: CGPoint] = [:]
        let center = CGPoint(x: 150, y: 150)  // Approximate screen center
        
        // Repulsion between all pairs
        for i in 0..<nodes.count {
            for j in i+1..<nodes.count {
                let delta = nodes[j].position - nodes[i].position
                let dist = max(delta.magnitude, 1e-3)
                let forceMagnitude = repulsion / (dist * dist)
                let forceDirection = delta / dist
                let force = forceDirection * forceMagnitude
                forces[nodes[i].id, default: .zero] -= force  // Fixed: push away
                forces[nodes[j].id, default: .zero] += force  // Fixed: push away
            }
        }
        
        // Attraction on edges (springs with ideal length)
        for edge in edges {
            guard let fromIdx = nodes.firstIndex(where: { $0.id == edge.from }),
                  let toIdx = nodes.firstIndex(where: { $0.id == edge.to }) else { continue }
            let delta = nodes[toIdx].position - nodes[fromIdx].position
            let dist = max(delta.magnitude, 1e-3)
            let forceMagnitude = stiffness * (dist - idealLength)
            let forceDirection = delta / dist
            let force = forceDirection * forceMagnitude
            forces[nodes[fromIdx].id, default: .zero] += force
            forces[nodes[toIdx].id, default: .zero] -= force
        }
        
        // Weak centering force
        for i in 0..<nodes.count {
            let delta = center - nodes[i].position
            let force = delta * centeringForce
            forces[nodes[i].id, default: .zero] += force
        }
        
        // Apply forces (with implicit dt=1/60 via timer)
        for i in 0..<nodes.count {
            let id = nodes[i].id
            var node = nodes[i]
            let force = forces[id] ?? .zero
            node.velocity += force * (1/60)  // Scale by dt for stability
            node.velocity *= damping
            node.position += node.velocity * (1/60)  // Scale by dt
            // Loose bounds to prevent off-screen
            node.position.x = max(0, min(300, node.position.x))
            node.position.y = max(0, min(300, node.position.y))
            nodes[i] = node
        }
    }
}

// Extensions for arithmetic (unchanged)
extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    static func * (lhs: CGFloat, rhs: CGPoint) -> CGPoint {
        rhs * lhs
    }
    
    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }
    
    static func -= (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs - rhs
    }
    
    static func *= (lhs: inout CGPoint, rhs: CGFloat) {
        lhs = lhs * rhs
    }
    
    static func + (lhs: CGPoint, rhs: CGSize) -> CGPoint {
        CGPoint(x: lhs.x + rhs.width, y: lhs.y + rhs.height)
    }
    
    static func += (lhs: inout CGPoint, rhs: CGSize) {
        lhs = lhs + rhs
    }
    
    var magnitude: CGFloat {
        hypot(x, y)
    }
}

extension CGSize {
    static func / (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }
    
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
    
    static func += (lhs: inout CGSize, rhs: CGSize) {
        lhs = lhs + rhs
    }
}
