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
        
        // Updated: Use saveGraphState with GraphState
        let state = GraphState(
            nodes: model.nodes.map { $0.unwrapped },
            edges: model.edges,
            hierarchyEdgeColor: CodableColor(.blue),
            associationEdgeColor: CodableColor(.white)
        )
        try await model.storage.saveGraphState(state, for: "default")
        
        // Clear model to simulate reload
        model.nodes = []
        model.edges = []
        
        // Updated: Use loadGraph(name:)
         await model.loadGraph(name: "default")
        
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
        let node1 = AnyNode(Node(label: 1, position: .zero))
        let node2 = AnyNode(Node(label: 2, position: .zero))
        model.nodes = [node1, node2]
        
        // Save current (default)
        let defaultState = GraphState(
            nodes: model.nodes.map { $0.unwrapped },
            edges: [],
            hierarchyEdgeColor: CodableColor(.blue),
            associationEdgeColor: CodableColor(.white)
        )
        try await model.storage.saveGraphState(defaultState, for: "default")
        
        // Create and switch to new graph
        try await model.createNewGraph(name: "testGraph")
        model.nodes = [AnyNode(Node(label: 3, position: .zero))]
        let testState = GraphState(
            nodes: model.nodes.map { $0.unwrapped },
            edges: [],
            hierarchyEdgeColor: CodableColor(.blue),
            associationEdgeColor: CodableColor(.white)
        )
        try await model.storage.saveGraphState(testState, for: "testGraph")
        
        // Load back default
         await model.loadGraph(name: "default")
        #expect(model.nodes.count == 2, "Switched back to default graph")
        
        // List graphs
        let names = try await model.listGraphNames()
        #expect(names.contains("default") && names.contains("testGraph"), "Multiple graphs listed")
        
        // Delete test graph
        try await model.deleteGraph(name: "testGraph")
        let updatedNames = try await model.listGraphNames()
        #expect(!updatedNames.contains("testGraph"), "Graph deleted")
    }
    
    @MainActor @Test func testBuildAdjacencyList() {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let node1ID = UUID()
        let node2ID = UUID()
        let node3ID = UUID()
        model.nodes = [
            AnyNode(Node(id: node1ID, label: 1, position: CGPoint.zero)),
            AnyNode(Node(id: node2ID, label: 2, position: CGPoint.zero)),
            AnyNode(Node(id: node3ID, label: 3, position: CGPoint.zero))
        ]
        model.edges = [
            GraphEdge(from: node1ID, target: node2ID, type: EdgeType.hierarchy),
            GraphEdge(from: node1ID, target: node3ID, type: EdgeType.association),
            GraphEdge(from: node2ID, target: node3ID, type: EdgeType.hierarchy)
        ]
        
        let allAdj = model.buildAdjacencyList()
        #expect(allAdj[node1ID]?.count == 2, "All edges from node1")
        #expect(allAdj[node2ID]?.count == 1, "All edges from node2")
        
        let hierarchyAdj = model.buildAdjacencyList(for: EdgeType.hierarchy)
        #expect(hierarchyAdj[node1ID]?.count == 1, "Only hierarchy from node1")
        #expect(hierarchyAdj[node1ID]?[0] == node2ID, "Correct target")
    }
    
    @Test func testDistanceEdgeCases() {
        let samePoint = CGPoint(x: 5, y: 5)
        #expect(distance(samePoint, samePoint) == 0, "Distance to self is 0")
        
        let negativePoints = CGPoint(x: -3, y: -4)
        let origin = CGPoint.zero
        #expect(distance(negativePoints, origin) == 5, "Distance with negatives is positive")
    }
    
    @MainActor @Test func testWouldCreateCycle() {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let node1ID = UUID()
        let node2ID = UUID()
        let node3ID = UUID()
        model.nodes = [
            AnyNode(Node(id: node1ID, label: 1, position: CGPoint.zero)),
            AnyNode(Node(id: node2ID, label: 2, position: CGPoint.zero)),
            AnyNode(Node(id: node3ID, label: 3, position: CGPoint.zero))
        ]
        model.edges = [
            GraphEdge(from: node1ID, target: node2ID, type: EdgeType.hierarchy),
            GraphEdge(from: node2ID, target: node3ID, type: EdgeType.hierarchy)
        ]
        
        #expect(model.wouldCreateCycle(withNewEdgeFrom: node3ID, target: node1ID, type: EdgeType.hierarchy) == true, "Should detect cycle")
        #expect(model.wouldCreateCycle(withNewEdgeFrom: node1ID, target: node3ID, type: EdgeType.hierarchy) == false, "No cycle")
        #expect(model.wouldCreateCycle(withNewEdgeFrom: node1ID, target: node2ID, type: EdgeType.association) == false, "Non-hierarchy ignores cycle check")
    }
    
    @MainActor @Test func testAddAndDeleteEdge() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let node1ID = UUID()
        let node2ID = UUID()
        model.nodes = [
            AnyNode(Node(id: node1ID, label: 1, position: CGPoint.zero)),
            AnyNode(Node(id: node2ID, label: 2, position: CGPoint.zero))
        ]
        
        await model.addEdge(from: node1ID, target: node2ID, type: EdgeType.hierarchy)
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
        
        await model.addNode(at: CGPoint.zero)
        #expect(model.nodes.count == 1, "Node added")
        #expect(model.nodes[0].unwrapped.label == 1, "Label set correctly")
        #expect(model.nextNodeLabel == 2, "Label incremented")
        
        await model.addToggleNode(at: CGPoint.zero)
        #expect(model.nodes.count == 2, "ToggleNode added")
        #expect(model.nodes[1].unwrapped.label == 2, "Label set correctly")
        #expect(model.nextNodeLabel == 3, "Label incremented")
    }
    
    @MainActor @Test func testAddChildAndDeleteNode() async {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        let parentID = UUID()
        model.nodes = [AnyNode(Node(id: parentID, label: 1, position: CGPoint.zero))]
        model.nextNodeLabel = 2
        
        await model.addPlainChild(to: parentID)
        #expect(model.nodes.count == 2, "Child added")
        #expect(model.edges.count == 1, "Hierarchy edge added")
        #expect(model.edges[0].type == EdgeType.hierarchy, "Correct edge type")
        #expect(model.nextNodeLabel == 3, "Label incremented")
        
        let childID = model.nodes[1].id
        await model.deleteNode(withID: childID)
        #expect(model.nodes.count == 1, "Child deleted")
        #expect(model.edges.isEmpty, "Edge removed")
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
        // Optionally, check logs if you have a way to capture them
    }
}
