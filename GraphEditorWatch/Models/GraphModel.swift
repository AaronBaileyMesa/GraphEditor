// At top of GraphModel.swift
import os.log
private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "storage")

// Models/GraphModel.swift
import SwiftUI
import Combine
import Foundation
import GraphEditorShared
import WatchKit

public class GraphModel: ObservableObject {
    @Published var nodes: [Node] = []
    @Published var edges: [GraphEdge] = []
    
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    internal var nextNodeLabel = 1  // Internal for testability; auto-increments node labels
    
    private let storage: GraphStorage
    internal let physicsEngine: PhysicsEngine
    
    private var timer: Timer? = nil
    
    private var recentVelocities: [CGFloat] = []  // Track last 5 total velocities for early stopping
    private let velocityChangeThreshold: CGFloat = 0.01  // Relative change threshold (1%)
    private let velocityHistoryCount = 5  // Number of frames to check
    
    // Indicates if undo is possible.
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    // Indicates if redo is possible.
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    // Initializes the graph model, loading from persistence if available.
    public init(storage: GraphStorage = PersistenceManager(), physicsEngine: PhysicsEngine) {
        self.storage = storage
        self.physicsEngine = physicsEngine
        let loaded = storage.load()
        nodes = loaded.nodes
        edges = loaded.edges
        if nodes.isEmpty && edges.isEmpty {
            nodes = [
                Node(label: nextNodeLabel, position: CGPoint(x: 100, y: 100)),
                Node(label: nextNodeLabel + 1, position: CGPoint(x: 200, y: 200)),
                Node(label: nextNodeLabel + 2, position: CGPoint(x: 150, y: 300))
            ]
            nextNodeLabel += 3
            edges = [
                GraphEdge(from: nodes[0].id, to: nodes[1].id),
                GraphEdge(from: nodes[1].id, to: nodes[2].id),
                GraphEdge(from: nodes[2].id, to: nodes[0].id)
            ]
            do {
                try storage.save(nodes: nodes, edges: edges)  // Only here, for defaults
            } catch {
                logger.error("Failed to save default graph: \(error.localizedDescription)")
            }
        } else {
            // Update nextLabel based on loaded nodes
            nextNodeLabel = (nodes.map { $0.label }.max() ?? 0) + 1
            // NO save here; loaded data doesn't need immediate save
        }
    }
 
    // Test-only initializer
    #if DEBUG
    init(storage: GraphStorage = PersistenceManager(), physicsEngine: PhysicsEngine, nextNodeLabel: Int) {
        self.storage = storage
        self.physicsEngine = physicsEngine
        let loaded = storage.load()
        nodes = loaded.nodes
        edges = loaded.edges
        if nodes.isEmpty && edges.isEmpty {
            // Default graph setup (as in main init)
            nodes = [
                Node(label: nextNodeLabel, position: CGPoint(x: 100, y: 100)),
                Node(label: nextNodeLabel + 1, position: CGPoint(x: 200, y: 200)),
                Node(label: nextNodeLabel + 2, position: CGPoint(x: 150, y: 300))
            ]
            self.nextNodeLabel = nextNodeLabel + 3  // Update based on defaults
            edges = [
                GraphEdge(from: nodes[0].id, to: nodes[1].id),
                GraphEdge(from: nodes[1].id, to: nodes[2].id),
                GraphEdge(from: nodes[2].id, to: nodes[0].id)
            ]
            do {
                try storage.save(nodes: nodes, edges: edges)
            } catch {
                logger.error("Failed to save default graph: \(error.localizedDescription)")
            }
        } else {
            self.nextNodeLabel = (nodes.map { $0.label }.max() ?? 0) + 1
        }
    }
    #endif
    
    // Creates a snapshot of the current state for undo/redo and saves.
    func snapshot() {
        let state = GraphState(nodes: nodes, edges: edges)
        undoStack.append(state)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        do {
            try storage.save(nodes: nodes, edges: edges)
        } catch {
            logger.error("Failed to save snapshot: \(error.localizedDescription)")
        }
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
        self.physicsEngine.resetSimulation()  // Ready for new simulation
        WKInterfaceDevice.current().play(.success)
        do {
            try storage.save(nodes: nodes, edges: edges)
        } catch {
            logger.error("Failed to save after undo: \(error.localizedDescription)")
        }
        // REMOVE any redoStack.removeAll() here if present
    }
    
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
        self.physicsEngine.resetSimulation()  // Ready for new simulation
        WKInterfaceDevice.current().play(.success)
        do {
            try storage.save(nodes: nodes, edges: edges)
        } catch {
            logger.error("Failed to save after redo: \(error.localizedDescription)")
        }
        // Optionally add redoStack.removeAll() here if you want to prevent redo chains, but standard is not to
    }
    
    func deleteNode(withID id: NodeID) {
        snapshot()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
        self.physicsEngine.resetSimulation()
    }
    
    func deleteEdge(withID id: NodeID) {
        snapshot()
        edges.removeAll { $0.id == id }
        self.physicsEngine.resetSimulation()
    }
    
    func addNode(at position: CGPoint) {
        nodes.append(Node(label: nextNodeLabel, position: position))
        nextNodeLabel += 1
        self.physicsEngine.resetSimulation()
    }
    
    func startSimulation() {
        timer?.invalidate()
        self.physicsEngine.resetSimulation()
        recentVelocities.removeAll()  // Reset velocity history on start
        if nodes.count < 5 { return }  // Skip for small graphs
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.objectWillChange.send()
            
            let subSteps = nodes.count < 10 ? 5 : 10  // Dynamic: fewer sub-steps for small graphs
            var shouldContinue = true
            for _ in 0..<subSteps {
                if !self.physicsEngine.simulationStep(nodes: &self.nodes, edges: self.edges) {
                    shouldContinue = false
                    break
                }
            }
            
            if !shouldContinue {
                self.stopSimulation()
                return
            }
            
            // Compute total velocity after sub-steps for early stopping
            let totalVelocity = self.nodes.reduce(0.0) { $0 + hypot($1.velocity.x, $1.velocity.y) }
            recentVelocities.append(totalVelocity)
            if recentVelocities.count > velocityHistoryCount {
                recentVelocities.removeFirst()
            }
            
            // Check if velocity is stabilizing (relative change over history < threshold)
            if recentVelocities.count == velocityHistoryCount {
                let maxVel = recentVelocities.max() ?? 1.0  // Avoid div by zero
                let minVel = recentVelocities.min() ?? 0.0
                let relativeChange = (maxVel - minVel) / maxVel
                if relativeChange < velocityChangeThreshold {
                    self.stopSimulation()
                    return
                }
            }
        }
    }
    
    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }
    
    func boundingBox() -> CGRect {
        self.physicsEngine.boundingBox(nodes: nodes)
    }
}

extension GraphModel {
    func graphDescription(selectedID: NodeID?) -> String {
        var desc = "Graph with \(nodes.count) nodes and \(edges.count) edges."
        if let selectedID, let selectedNode = nodes.first(where: { $0.id == selectedID }) {
            let connectedLabels = edges
                .filter { $0.from == selectedID || $0.to == selectedID }
                .compactMap { edge in
                    let otherID = (edge.from == selectedID ? edge.to : edge.from)
                    return nodes.first { $0.id == otherID }?.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            desc += " Node \(selectedNode.label) selected, connected to nodes: \(connectedLabels.isEmpty ? "none" : connectedLabels)."
        } else {
            desc += " No node selected."
        }
        return desc
    }
}
