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
    private var nextNodeLabel = 1  // Auto-increment for node labels
    
    private let storage: GraphStorage
    internal let physicsEngine: PhysicsEngine
    
    private var timer: Timer? = nil
    
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
            try? storage.save(nodes: nodes, edges: edges)  // Only here, for defaults
        } else {
            // Update nextLabel based on loaded nodes
            nextNodeLabel = (nodes.map { $0.label }.max() ?? 0) + 1
            // NO save here; loaded data doesn't need immediate save
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
        try? storage.save(nodes: nodes, edges: edges)
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
        try? storage.save(nodes: nodes, edges: edges)
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
        try? storage.save(nodes: nodes, edges: edges)
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
        if nodes.count < 5 { return }  // Skip for small graphs
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.objectWillChange.send()
            for _ in 0..<10 {  // 10 sub-steps per frame for faster real-time convergence
                if !self.physicsEngine.simulationStep(nodes: &self.nodes, edges: self.edges) {
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
