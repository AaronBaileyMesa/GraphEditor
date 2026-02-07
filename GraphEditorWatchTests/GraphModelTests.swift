//
//  GraphModelTests.swift
//  GraphEditorWatchTests
//
//  Created by handcart on 2025-10-15.
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct GraphModelTests {
    private func setupModel() async -> GraphModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        return await MainActor.run {
            GraphModel(storage: storage, physicsEngine: physicsEngine)
        }
    }
    
    @MainActor @Test func testSaveAndLoad() async throws {
        let model = await setupModel()
        let node1 = AnyNode(Node(label: 1, position: CGPoint(x: 0, y: 0)))
        let node2 = AnyNode(Node(label: 2, position: CGPoint(x: 100, y: 100)))
        let edge = GraphEdge(from: node1.id, target: node2.id)
        
        model.nodes = [node1, node2]
        model.edges = [edge]
        
        let state = GraphState(
            nodes: model.nodes,
            edges: model.edges,
            hierarchyEdgeColor: CodableColor(.blue),
            associationEdgeColor: CodableColor(.white),
            isSimulating: false
        )
        try await model.storage.saveGraphState(state, for: "default")
        
        model.nodes = []
        model.edges = []
        
        try await model.loadGraph()
        
        #expect(model.nodes.count == 2, "Nodes loaded")
        #expect(model.edges.count == 1, "Edges loaded")
    }
    
    @MainActor @Test func testClear() async throws {
        let model = await setupModel()
        model.nodes = [AnyNode(Node(label: 1, position: .zero))]
        model.edges = [GraphEdge(from: UUID(), target: UUID())]
        
        await model.resetGraph()
        
        #expect(model.nodes.isEmpty, "Nodes cleared")
        #expect(model.edges.isEmpty, "Edges cleared")
    }
    
    @MainActor @Test func testMultiGraphSupport() async throws {
        let model = await setupModel()
        
        // Populate default graph
        let node1 = AnyNode(Node(label: 1, position: .zero))
        let node2 = AnyNode(Node(label: 2, position: .zero))
        model.nodes = [node1, node2]
        
        let defaultState = GraphState(
            nodes: model.nodes,
            edges: [],
            hierarchyEdgeColor: CodableColor(.blue),
            associationEdgeColor: CodableColor(.white),
            isSimulating: false
        )
        try await model.storage.saveGraphState(defaultState, for: "default")
        
        // Create and switch to new graph
        try await model.createNewGraph(name: "testGraph")
        try await model.switchToGraph(named: "testGraph")
        _ = await model.addNode(at: .zero)
        #expect(model.nodes.count == 1, "Switched to testGraph – 1 node")
        
        // Delete the graph
        try await model.deleteGraph(named: "testGraph")
        
        // Attempt to load the deleted graph – expect fallback to default without throw
        try await model.loadGraph()
        #expect(model.currentGraphName == "default", "Falls back to default after deleting current")
        #expect(model.nodes.count == 2, "Loads default graph with previous nodes")
    }
    
    @MainActor @Test func testAddAndDeleteEdge() async {
        let model = await setupModel()
        let node1 = AnyNode(Node(label: 1, position: .zero))
        let node2 = AnyNode(Node(label: 2, position: .zero))
        model.nodes = [node1, node2]
        
        await model.addEdge(from: node1.id, target: node2.id, type: .association)
        #expect(model.edges.count == 1, "Edge should be added")
        
        let edgeID = model.edges[0].id
        await model.deleteEdge(withID: edgeID)
        #expect(model.edges.isEmpty, "Edge should be deleted")
    }
    
    @MainActor @Test func testAddNodeAndAddToggleNode() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        model.nextNodeLabel = 1
        
        _ = await model.addNode(at: CGPoint.zero)
        #expect(model.nodes.count == 1, "Node added")
        #expect(model.nodes[0].unwrapped.label == 1, "Label set correctly")
        #expect(model.nextNodeLabel == 2, "Label incremented")
        
        _ = await model.addToggleNode(at: CGPoint.zero)
        #expect(model.nodes.count == 2, "ToggleNode added")
        #expect(model.nodes[1].unwrapped.label == 2, "Label set correctly")
        #expect(model.nextNodeLabel == 3, "Label incremented")
    }
    
    @MainActor @Test func testAddEdgeCycleDetection() async {
        let storage = MockGraphStorage()
        let physics = PhysicsEngine(simulationBounds: CGSize(width: 300, height: 300))
        let model = GraphModel(storage: storage, physicsEngine: physics)
        let node1 = AnyNode(Node(label: 1, position: .zero))
        let node2 = AnyNode(Node(label: 2, position: .zero))
        let node3 = AnyNode(Node(label: 3, position: .zero))
        model.nodes = [node1, node2, node3]
        await model.addEdge(from: node1.id, target: node2.id, type: .hierarchy)
        await model.addEdge(from: node2.id, target: node3.id, type: .hierarchy)
        await model.addEdge(from: node3.id, target: node1.id, type: .hierarchy)  // Should prevent cycle
        #expect(model.edges.count == 2)  // Third edge not added
    }
    
    @MainActor @Test func testNextNodeLabelPersistence() async throws {
        // Use shared storage to test persistence
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        
        // Add some nodes to increment nextNodeLabel
        _ = await model.addNode(at: .zero)
        _ = await model.addNode(at: .zero)
        _ = await model.addNode(at: .zero)
        
        #expect(model.nextNodeLabel == 4, "nextNodeLabel should be 4 after adding 3 nodes")
        
        // Delete all nodes but nextNodeLabel should persist
        for node in model.nodes {
            await model.deleteNode(withID: node.id)
        }
        
        #expect(model.nextNodeLabel == 4, "nextNodeLabel should remain 4 after deleting nodes")
        
        // Save and reload
        try await model.saveGraph()
        
        // Create new model with same storage
        let physicsEngine2 = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let newModel = GraphModel(storage: storage, physicsEngine: physicsEngine2)
        try await newModel.loadGraph()
        
        #expect(newModel.nextNodeLabel == 4, "nextNodeLabel should persist after save/load")
        
        // Add a new node - should use label 4, not restart at 1
        let newNode = await newModel.addNode(at: .zero)
        #expect(newNode.unwrapped.label == 4, "New node should use saved nextNodeLabel")
        #expect(newModel.nextNodeLabel == 5, "nextNodeLabel should increment to 5")
    }
}
