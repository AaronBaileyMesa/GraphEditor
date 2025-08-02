// Models/GraphModel.swift
import SwiftUI
import Combine
import Foundation
import GraphEditorShared

class GraphModel: ObservableObject {
    @Published var nodes: [Node] = []
    @Published var edges: [GraphEdge] = []
    
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    private var nextNodeLabel = 1  // Auto-increment for node labels
    
    private let storage: GraphStorage = PersistenceManager()
    private let physicsEngine = PhysicsEngine()
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
    init() {
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
            storage.save(nodes: nodes, edges: edges)  // Save default graph
        } else {
            // Update nextLabel based on loaded nodes
            nextNodeLabel = (nodes.map { $0.label }.max() ?? 0) + 1
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
        storage.save(nodes: nodes, edges: edges)
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
        physicsEngine.resetSimulation()  // Ready for new simulation
        WKInterfaceDevice.current().play(.success)
        storage.save(nodes: nodes, edges: edges)
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
        physicsEngine.resetSimulation()  // Ready for new simulation
        WKInterfaceDevice.current().play(.success)
        storage.save(nodes: nodes, edges: edges)
    }
    
    // Deletes a node and its connected edges, snapshotting first.
    func deleteNode(withID id: NodeID) {
        snapshot()
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.from == id || $0.to == id }
        physicsEngine.resetSimulation()
    }
    
    // Deletes an edge, snapshotting first.
    func deleteEdge(withID id: NodeID) {
        snapshot()
        edges.removeAll { $0.id == id }
        physicsEngine.resetSimulation()
    }
    
    // Adds a new node with auto-incremented label.
    func addNode(at position: CGPoint) {
        nodes.append(Node(label: nextNodeLabel, position: position))
        nextNodeLabel += 1
        physicsEngine.resetSimulation()
    }

    func startSimulation() {
        timer?.invalidate()
        physicsEngine.resetSimulation()
        timer = Timer.scheduledTimer(withTimeInterval: Constants.timeStep, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.objectWillChange.send()
            if !self.physicsEngine.simulationStep(nodes: &self.nodes, edges: self.edges) {
                self.stopSimulation()
            }
        }
    }

    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }

    func boundingBox() -> CGRect {
        physicsEngine.boundingBox(nodes: nodes)
    }
}
