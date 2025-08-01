import SwiftUI
import Combine

struct Node: Identifiable, Equatable, Codable {
    let id: UUID
    var position: CGPoint
    var velocity: CGPoint = .zero
    
    enum CodingKeys: String, CodingKey {
        case id
        case positionX
        case positionY
        case velocityX
        case velocityY
    }
    
    init(id: UUID = UUID(), position: CGPoint, velocity: CGPoint = .zero) {
        self.id = id
        self.position = position
        self.velocity = velocity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let posX = try container.decode(CGFloat.self, forKey: .positionX)
        let posY = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: posX, y: posY)
        let velX = try container.decode(CGFloat.self, forKey: .velocityX)
        let velY = try container.decode(CGFloat.self, forKey: .velocityY)
        velocity = CGPoint(x: velX, y: velY)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
    }
}

struct Edge: Identifiable, Equatable, Codable {
    let id: UUID
    let from: UUID
    let to: UUID
    
    init(id: UUID = UUID(), from: UUID, to: UUID) {
        self.id = id
        self.from = from
        self.to = to
    }
}

struct GraphState: Codable {
    let nodes: [Node]
    let edges: [Edge]
}

class GraphModel: ObservableObject {
    @Published var nodes: [Node] = []
    @Published var edges: [Edge] = []
    
    // Physics constants (tuned for stability)
    let stiffness: CGFloat = 0.01
    let repulsion: CGFloat = 15000
    let damping: CGFloat = 0.95
    let idealLength: CGFloat = 100
    let centeringForce: CGFloat = 0.001  // Weak pull to center
    
    private var timer: Timer?
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    init() {
        load()
        if nodes.isEmpty && edges.isEmpty {
            nodes = [
                Node(position: CGPoint(x: 100, y: 100)),
                Node(position: CGPoint(x: 200, y: 200)),
                Node(position: CGPoint(x: 150, y: 300))
            ]
            edges = [
                Edge(from: nodes[0].id, to: nodes[1].id),
                Edge(from: nodes[1].id, to: nodes[2].id),
                Edge(from: nodes[2].id, to: nodes[0].id)
            ]
        }
    }
    
    func startSimulation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/30, repeats: true) { [weak self] _ in  // Lower FPS for battery
            self?.applyPhysics()
        }
    }
    
    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }
    
    func boundingBox() -> CGRect {
        guard !nodes.isEmpty else { return .zero }
        let minX = nodes.map { $0.position.x }.min()!
        let maxX = nodes.map { $0.position.x }.max()!
        let minY = nodes.map { $0.position.y }.min()!
        let maxY = nodes.map { $0.position.y }.max()!
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func applyPhysics() {
        print("Starting physics step. Nodes: \(nodes.count)")
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
                forces[nodes[i].id, default: .zero] -= force  // Push away
                forces[nodes[j].id, default: .zero] += force  // Push away
            }
        }
        
        // Attraction on edges
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
        
        // Apply forces
        for i in 0..<nodes.count {
            let id = nodes[i].id
            var node = nodes[i]
            let force = forces[id] ?? .zero
            node.velocity += force * (1/60)
            node.velocity *= damping
            node.position += node.velocity * (1/60)
            node.position.x = max(0, min(300, node.position.x))
            node.position.y = max(0, min(300, node.position.y))
            nodes[i] = node
        }
        
        // Check if stable
        let totalVelocity = nodes.reduce(0.0) { $0 + $1.velocity.magnitude }
        if totalVelocity < 0.1 {
            stopSimulation()
        }
        
        print("Physics step complete. Total velocity: \(totalVelocity)")
    }
    
    func save() {
        let encoder = JSONEncoder()
        if let nodeData = try? encoder.encode(nodes) {
            UserDefaults.standard.set(nodeData, forKey: "graphNodes")
        }
        if let edgeData = try? encoder.encode(edges) {
            UserDefaults.standard.set(edgeData, forKey: "graphEdges")
        }
    }
    
    func load() {
        let decoder = JSONDecoder()
        let loadedNodes = UserDefaults.standard.data(forKey: "graphNodes").flatMap { try? decoder.decode([Node].self, from: $0) } ?? []
        nodes = loadedNodes
        let loadedEdges = UserDefaults.standard.data(forKey: "graphEdges").flatMap { try? decoder.decode([Edge].self, from: $0) } ?? []
        edges = loadedEdges
    }
    
    func snapshot() {
        let state = GraphState(nodes: nodes, edges: edges)
        undoStack.append(state)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }
    
    func undo() {
        if !undoStack.isEmpty {
            let current = GraphState(nodes: nodes, edges: edges)
            redoStack.append(current)
            let previous = undoStack.removeLast()
            nodes = previous.nodes
            edges = previous.edges
            startSimulation()
            WKInterfaceDevice.current().play(.success)
        } else {
            WKInterfaceDevice.current().play(.failure)
        }
    }
    
    func redo() {
        if !redoStack.isEmpty {
            let current = GraphState(nodes: nodes, edges: edges)
            undoStack.append(current)
            let next = redoStack.removeLast()
            nodes = next.nodes
            edges = next.edges
            startSimulation()
            WKInterfaceDevice.current().play(.success)
        } else {
            WKInterfaceDevice.current().play(.failure)
        }
    }
    
    func deleteNode(withID id: UUID) {
        snapshot()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
        startSimulation()
    }
    
    func deleteEdge(withID id: UUID) {
        snapshot()
        edges.removeAll { $0.id == id }
        startSimulation()
    }
}

// Extensions for arithmetic
// Add this at the end of GraphModel.swift

extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }
    
    static func -= (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs - rhs
    }
    
    static func += (lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }
    
    static func *= (lhs: inout CGPoint, rhs: CGFloat) {
        lhs = lhs * rhs
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
