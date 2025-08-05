// Updated GraphModel.swift with lazy simulator to avoid initialization issues with closures capturing self.

import os.log
private let logger = Logger(subsystem: "io.handcart.GraphEditor", category: "storage")

// Models/GraphModel.swift
import SwiftUI
import Combine
import Foundation
import GraphEditorShared
import WatchKit

public class GraphModel: ObservableObject {
    @Published var nodes: [any NodeProtocol] = []
    @Published var edges: [GraphEdge] = []
    
    private var undoStack: [GraphState] = []
    private var redoStack: [GraphState] = []
    private let maxUndo = 10
    internal var nextNodeLabel = 1  // Internal for testability; auto-increments node labels
    
    private let storage: GraphStorage
    internal let physicsEngine: PhysicsEngine
    
    private lazy var simulator: GraphSimulator = {
        GraphSimulator(
            getNodes: { [weak self] in (self?.nodes as? [Node]) ?? [] },  // Cast to [Node] for simulator
            setNodes: { [weak self] nodes in self?.nodes = nodes as [any NodeProtocol] },  // Cast back to existential
            getEdges: { [weak self] in self?.edges ?? [] },
            physicsEngine: self.physicsEngine
        )
    }()
    
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
        var tempNodes: [any NodeProtocol] = loaded.nodes  // Implicit conversion from [Node] to [any NodeProtocol]
        var tempEdges = loaded.edges
        var tempNextLabel = 1
        
        if tempNodes.isEmpty && tempEdges.isEmpty {
            let defaultNodes: [Node] = [
                Node(label: tempNextLabel, position: CGPoint(x: 100, y: 100)),
                Node(label: tempNextLabel + 1, position: CGPoint(x: 200, y: 200)),
                Node(label: tempNextLabel + 2, position: CGPoint(x: 150, y: 300))
            ]
            tempNodes = defaultNodes  // [Node] to [any NodeProtocol]
            tempNextLabel += 3
            tempEdges = [
                GraphEdge(from: defaultNodes[0].id, to: defaultNodes[1].id),
                GraphEdge(from: defaultNodes[1].id, to: defaultNodes[2].id),
                GraphEdge(from: defaultNodes[2].id, to: defaultNodes[0].id)
            ]
            do {
                try storage.save(nodes: defaultNodes, edges: tempEdges)  // Use concrete [Node] for save
            } catch {
                logger.error("Failed to save default graph: \(error.localizedDescription)")
            }
        } else {
            // Update nextLabel based on loaded nodes
            tempNextLabel = (tempNodes.map { $0.label }.max() ?? 0) + 1
            // NO save here; loaded data doesn't need immediate save
        }
        
        self.nodes = tempNodes
        self.edges = tempEdges
        self.nextNodeLabel = tempNextLabel
    }

    // Test-only initializer
    #if DEBUG
    init(storage: GraphStorage = PersistenceManager(), physicsEngine: PhysicsEngine, nextNodeLabel: Int) {
        self.storage = storage
        self.physicsEngine = physicsEngine
        
        let loaded = storage.load()
        var tempNodes: [any NodeProtocol] = loaded.nodes  // Implicit conversion
        var tempEdges = loaded.edges
        var tempNextLabel = nextNodeLabel
        
        if tempNodes.isEmpty && tempEdges.isEmpty {
            // Default graph setup (as in main init)
            let defaultNodes: [Node] = [
                Node(label: tempNextLabel, position: CGPoint(x: 100, y: 100)),
                Node(label: tempNextLabel + 1, position: CGPoint(x: 200, y: 200)),
                Node(label: tempNextLabel + 2, position: CGPoint(x: 150, y: 300))
            ]
            tempNodes = defaultNodes
            tempNextLabel += 3
            tempEdges = [
                GraphEdge(from: defaultNodes[0].id, to: defaultNodes[1].id),
                GraphEdge(from: defaultNodes[1].id, to: defaultNodes[2].id),
                GraphEdge(from: defaultNodes[2].id, to: defaultNodes[0].id)
            ]
            do {
                try storage.save(nodes: defaultNodes, edges: tempEdges)
            } catch {
                logger.error("Failed to save default graph: \(error.localizedDescription)")
            }
        } else {
            tempNextLabel = (tempNodes.map { $0.label }.max() ?? 0) + 1
        }
        
        self.nodes = tempNodes
        self.edges = tempEdges
        self.nextNodeLabel = tempNextLabel
    }
    #endif
    
    // Creates a snapshot of the current state for undo/redo and saves.
    func snapshot() {
        let state = GraphState(nodes: nodes as! [Node], edges: edges)  // Cast for GraphState (assumes all are Node)
        undoStack.append(state)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        do {
            try storage.save(nodes: nodes as! [Node], edges: edges)  // Cast for save
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
        let current = GraphState(nodes: nodes as! [Node], edges: edges)
        redoStack.append(current)
        let previous = undoStack.removeLast()
        nodes = previous.nodes as [any NodeProtocol]  // Conversion from [Node]
        edges = previous.edges
        self.physicsEngine.resetSimulation()  // Ready for new simulation
        WKInterfaceDevice.current().play(.success)
        do {
            try storage.save(nodes: nodes as! [Node], edges: edges)
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
        let current = GraphState(nodes: nodes as! [Node], edges: edges)
        undoStack.append(current)
        let next = redoStack.removeLast()
        nodes = next.nodes as [any NodeProtocol]
        edges = next.edges
        self.physicsEngine.resetSimulation()  // Ready for new simulation
        WKInterfaceDevice.current().play(.success)
        do {
            try storage.save(nodes: nodes as! [Node], edges: edges)
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
        nodes.append(Node(label: nextNodeLabel, position: position, radius: 10.0))  // Explicit radius; vary later if needed
        nextNodeLabel += 1
        if nodes.count >= 100 {
            // Trigger alert via view (e.g., publish @Published var showNodeLimitAlert = true)
            return
        }
        self.physicsEngine.resetSimulation()
    }
    
    func startSimulation() {
        simulator.startSimulation(onUpdate: { [weak self] in
            self?.objectWillChange.send()
        })
    }
    
    func stopSimulation() {
        simulator.stopSimulation()
    }
    
    func boundingBox() -> CGRect {
        self.physicsEngine.boundingBox(nodes: nodes as! [Node])  // Cast for physicsEngine
    }
}

extension GraphModel {
    func graphDescription(selectedID: NodeID?) -> String {
        var desc = "Graph with \(nodes.count) nodes and \(edges.count) directed edges."
        if let selectedID, let selectedNode = nodes.first(where: { $0.id == selectedID }) {
            let outgoingLabels = edges
                .filter { $0.from == selectedID }
                .compactMap { edge in
                    let toID = edge.to
                    return nodes.first { $0.id == toID }?.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            let incomingLabels = edges
                .filter { $0.to == selectedID }
                .compactMap { edge in
                    let fromID = edge.from
                    return nodes.first { $0.id == fromID }?.label
                }
                .sorted()
                .map { String($0) }
                .joined(separator: ", ")
            let outgoingText = outgoingLabels.isEmpty ? "none" : outgoingLabels
            let incomingText = incomingLabels.isEmpty ? "none" : incomingLabels
            desc += " Node \(selectedNode.label) selected, outgoing to: \(outgoingText); incoming from: \(incomingText)."
        } else {
            desc += " No node selected."
        }
        return desc
    }
}
