import SwiftUI
import Combine

// Represents a node in the graph with position, velocity, and permanent label.
struct Node: Identifiable, Equatable, Codable {
    let id: UUID
    let label: Int  // Permanent label, assigned on creation
    var position: CGPoint
    var velocity: CGPoint = .zero
    
    enum CodingKeys: String, CodingKey {
        case id, label
        case positionX, positionY
        case velocityX, velocityY
    }
    
    init(id: UUID = UUID(), label: Int, position: CGPoint, velocity: CGPoint = .zero) {
        self.id = id
        self.label = label
        self.position = position
        self.velocity = velocity
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(Int.self, forKey: .label)
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
        try container.encode(label, forKey: .label)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        try container.encode(velocity.x, forKey: .velocityX)
        try container.encode(velocity.y, forKey: .velocityY)
    }
}

// Represents an edge connecting two nodes.
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

// Snapshot of the graph state for undo/redo.
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
    private var nextNodeLabel = 1  // Auto-increment for node labels
    
    // Configurable graph area for clamping and centering (e.g., approximate Watch screen)
    let graphArea: CGSize = CGSize(width: 300, height: 300)
    
    // Indicates if undo is possible.
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    // Indicates if redo is possible.
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    // Initializes the graph model, loading from persistence if available.
    init() {
        load()
        if nodes.isEmpty && edges.isEmpty {
            nodes = [
                Node(label: nextNodeLabel, position: CGPoint(x: 100, y: 100)),
                Node(label: nextNodeLabel + 1, position: CGPoint(x: 200, y: 200)),
                Node(label: nextNodeLabel + 2, position: CGPoint(x: 150, y: 300))
            ]
            nextNodeLabel += 3
            edges = [
                Edge(from: nodes[0].id, to: nodes[1].id),
                Edge(from: nodes[1].id, to: nodes[2].id),
                Edge(from: nodes[2].id, to: nodes[0].id)
            ]
            save()  // Save default graph
        } else {
            // Update nextLabel based on loaded nodes
            nextNodeLabel = (nodes.map { $0.label }.max() ?? 0) + 1
        }
    }
    
    // Starts the physics simulation timer at 60 FPS for smoothness.
    func startSimulation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            self?.applyPhysics()
        }
    }
    
    // Stops the physics simulation timer.
    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }
    
    // Calculates the bounding box of all nodes with padding.
    func boundingBox() -> CGRect {
        guard !nodes.isEmpty else { return .zero }
        let minX = nodes.map { $0.position.x }.min()! - 20
        let maxX = nodes.map { $0.position.x }.max()! + 20
        let minY = nodes.map { $0.position.y }.min()! - 20
        let maxY = nodes.map { $0.position.y }.max()! + 20
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // Applies one step of physics simulation to the graph.
    private func applyPhysics() {
        var forces: [UUID: CGPoint] = [:]
        let center = CGPoint(x: graphArea.width / 2, y: graphArea.height / 2)
        
        // Repulsion between all pairs
        for i in 0..<nodes.count {
            for j in i+1..<nodes.count {
                let deltaX = nodes[j].position.x - nodes[i].position.x
                let deltaY = nodes[j].position.y - nodes[i].position.y
                let dist = max(hypot(deltaX, deltaY), 1e-3)
                let forceMagnitude = repulsion / (dist * dist)
                let forceDirectionX = deltaX / dist
                let forceDirectionY = deltaY / dist
                let forceX = forceDirectionX * forceMagnitude
                let forceY = forceDirectionY * forceMagnitude
                let currentForceI = forces[nodes[i].id] ?? .zero
                forces[nodes[i].id] = CGPoint(x: currentForceI.x - forceX, y: currentForceI.y - forceY)
                let currentForceJ = forces[nodes[j].id] ?? .zero
                forces[nodes[j].id] = CGPoint(x: currentForceJ.x + forceX, y: currentForceJ.y + forceY)
            }
        }
        
        // Attraction on edges
        for edge in edges {
            guard let fromIdx = nodes.firstIndex(where: { $0.id == edge.from }),
                  let toIdx = nodes.firstIndex(where: { $0.id == edge.to }) else { continue }
            let deltaX = nodes[toIdx].position.x - nodes[fromIdx].position.x
            let deltaY = nodes[toIdx].position.y - nodes[fromIdx].position.y
            let dist = max(hypot(deltaX, deltaY), 1e-3)
            let forceMagnitude = stiffness * (dist - idealLength)
            let forceDirectionX = deltaX / dist
            let forceDirectionY = deltaY / dist
            let forceX = forceDirectionX * forceMagnitude
            let forceY = forceDirectionY * forceMagnitude
            let currentForceFrom = forces[nodes[fromIdx].id] ?? .zero
            forces[nodes[fromIdx].id] = CGPoint(x: currentForceFrom.x + forceX, y: currentForceFrom.y + forceY)
            let currentForceTo = forces[nodes[toIdx].id] ?? .zero
            forces[nodes[toIdx].id] = CGPoint(x: currentForceTo.x - forceX, y: currentForceTo.y - forceY)
        }
        
        // Weak centering force
        for i in 0..<nodes.count {
            let deltaX = center.x - nodes[i].position.x
            let deltaY = center.y - nodes[i].position.y
            let forceX = deltaX * centeringForce
            let forceY = deltaY * centeringForce
            let currentForce = forces[nodes[i].id] ?? .zero
            forces[nodes[i].id] = CGPoint(x: currentForce.x + forceX, y: currentForce.y + forceY)
        }
        
        // Apply forces
        for i in 0..<nodes.count {
            let id = nodes[i].id
            var node = nodes[i]
            let force = forces[id] ?? .zero
            node.velocity = CGPoint(x: node.velocity.x + force.x * (1/60), y: node.velocity.y + force.y * (1/60))
            node.velocity = CGPoint(x: node.velocity.x * damping, y: node.velocity.y * damping)
            node.position = CGPoint(x: node.position.x + node.velocity.x * (1/60), y: node.position.y + node.velocity.y * (1/60))
            node.position.x = max(0, min(graphArea.width, node.position.x))
            node.position.y = max(0, min(graphArea.height, node.position.y))
            nodes[i] = node
        }
        
        // Check if stable (lower threshold for quicker stop)
        let totalVelocity = nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
        if totalVelocity < 0.05 {
            stopSimulation()
        }
    }
    
    // Saves the current graph state to persistence.
    func save() {
        let encoder = JSONEncoder()
        if let nodeData = try? encoder.encode(nodes) {
            UserDefaults.standard.set(nodeData, forKey: "graphNodes")
        }
        if let edgeData = try? encoder.encode(edges) {
            UserDefaults.standard.set(edgeData, forKey: "graphEdges")
        }
    }
    
    // Loads the graph state from persistence.
    func load() {
        let decoder = JSONDecoder()
        if let nodeData = UserDefaults.standard.data(forKey: "graphNodes"),
           let loadedNodes = try? decoder.decode([Node].self, from: nodeData) {
            nodes = loadedNodes
        }
        if let edgeData = UserDefaults.standard.data(forKey: "graphEdges"),
           let loadedEdges = try? decoder.decode([Edge].self, from: edgeData) {
            edges = loadedEdges
        }
    }
    
    // Creates a snapshot of the current state for undo/redo and saves.
    func snapshot() {
        let state = GraphState(nodes: nodes, edges: edges)
        undoStack.append(state)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        save()
    }
    
    // Undoes the last action if possible, with haptic feedback.
    func undo() {
        guard !undoStack.isEmpty else {
            WKInterfaceDevice.current().play(.failure)
            return
        }
        let current = GraphState(nodes: nodes, edges: edges)
        redoStack.append(current)
        let previous = undoStack.removeLast()
        nodes = previous.nodes
        edges = previous.edges
        startSimulation()
        WKInterfaceDevice.current().play(.success)
        save()
    }
    
    // Redoes the last undone action if possible, with haptic feedback.
    func redo() {
        guard !redoStack.isEmpty else {
            WKInterfaceDevice.current().play(.failure)
            return
        }
        let current = GraphState(nodes: nodes, edges: edges)
        undoStack.append(current)
        let next = redoStack.removeLast()
        nodes = next.nodes
        edges = next.edges
        startSimulation()
        WKInterfaceDevice.current().play(.success)
        save()
    }
    
    // Deletes a node and its connected edges, snapshotting first.
    func deleteNode(withID id: UUID) {
        snapshot()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
        startSimulation()
    }
    
    // Deletes an edge, snapshotting first.
    func deleteEdge(withID id: UUID) {
        snapshot()
        edges.removeAll { $0.id == id }
        startSimulation()
    }
    
    // Adds a new node with auto-incremented label.
    func addNode(at position: CGPoint) {
        nodes.append(Node(label: nextNodeLabel, position: position))
        nextNodeLabel += 1
    }
}
