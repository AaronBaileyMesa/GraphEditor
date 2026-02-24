//
//  UserGraphTests.swift
//  GraphEditorWatchTests
//
//  Tests for User Graph feature (Phases 1-4)

import XCTest
import GraphEditorShared
@testable import GraphEditorWatch

@available(iOS 16.0, watchOS 9.0, *)
@MainActor
final class UserGraphTests: XCTestCase {
    
    var storage: MockGraphStorage!
    var userGraphViewModel: UserGraphViewModel!
    
    override func setUp() async throws {
        storage = MockGraphStorage()
        userGraphViewModel = UserGraphViewModel(storage: storage)
    }
    
    override func tearDown() {
        storage = nil
        userGraphViewModel = nil
    }
    
    // MARK: - Phase 1: Foundation Tests
    
    func testGraphNodeCreation() throws {
        // Test GraphNode creation with all properties
        let graphNode = GraphNode(
            label: 1,
            position: CGPoint(x: 100, y: 200),
            graphName: "TacoNight1",
            displayName: "Taco Night 1",
            nodeCount: 5,
            lastModified: Date()
        )
        
        XCTAssertEqual(graphNode.label, 1)
        XCTAssertEqual(graphNode.position.x, 100)
        XCTAssertEqual(graphNode.position.y, 200)
        XCTAssertEqual(graphNode.graphName, "TacoNight1")
        XCTAssertEqual(graphNode.displayName, "Taco Night 1")
        XCTAssertEqual(graphNode.nodeCount, 5)
        XCTAssertNotNil(graphNode.lastModified)
    }
    
    func testGraphNodeCodable() throws {
        // Test GraphNode serialization/deserialization
        let original = GraphNode(
            label: 2,
            position: CGPoint(x: 150, y: 250),
            graphName: "TestGraph",
            displayName: "Test Graph",
            nodeCount: 10
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(GraphNode.self, from: data)
        
        XCTAssertEqual(decoded.label, original.label)
        XCTAssertEqual(decoded.position.x, original.position.x)
        XCTAssertEqual(decoded.position.y, original.position.y)
        XCTAssertEqual(decoded.graphName, original.graphName)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.nodeCount, original.nodeCount)
    }
    
    func testUserGraphStateCreation() throws {
        // Test UserGraphState initialization and properties
        var state = UserGraphState()
        
        XCTAssertTrue(state.graphPositions.isEmpty)
        XCTAssertTrue(state.userEdges.isEmpty)
        XCTAssertTrue(state.pinnedNodes.isEmpty)
        XCTAssertTrue(state.graphOrder.isEmpty)
        
        // Add graph position
        state.graphPositions["Graph1"] = CGPoint(x: 100, y: 100)
        XCTAssertEqual(state.graphPositions.count, 1)
        XCTAssertEqual(state.graphPositions["Graph1"]?.x, 100)
    }
    
    func testUserGraphStateCodable() throws {
        // Test UserGraphState serialization/deserialization
        var state = UserGraphState()
        state.graphPositions["Graph1"] = CGPoint(x: 100, y: 200)
        state.graphPositions["Graph2"] = CGPoint(x: 300, y: 400)
        
        let edge = UserGraphEdge(fromGraph: "Graph1", toGraph: "Graph2", label: "Related")
        state.userEdges.append(edge)
        
        let pin = PinnedNodeReference(
            sourceGraphName: "Graph1",
            sourceNodeID: UUID(),
            position: CGPoint(x: 50, y: 50),
            cachedLabel: "Person 1",
            cachedNodeType: "PersonNode"
        )
        state.pinnedNodes.append(pin)
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(state)
        let decoded = try decoder.decode(UserGraphState.self, from: data)
        
        XCTAssertEqual(decoded.graphPositions.count, 2)
        XCTAssertEqual(decoded.userEdges.count, 1)
        XCTAssertEqual(decoded.pinnedNodes.count, 1)
        XCTAssertEqual(decoded.userEdges.first?.label, "Related")
    }
    
    func testUserGraphStateStorage() async throws {
        // Test saving and loading UserGraphState
        var state = UserGraphState()
        state.graphPositions["TestGraph"] = CGPoint(x: 123, y: 456)
        
        try await storage.saveUserGraphState(state)
        
        let loaded = try await storage.loadUserGraphState()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.graphPositions["TestGraph"]?.x, 123)
        XCTAssertEqual(loaded?.graphPositions["TestGraph"]?.y, 456)
    }
    
    // MARK: - Phase 2: User Graph Canvas Tests
    
    func testUserGraphViewModelInitialization() async throws {
        // Test UserGraphViewModel initializes correctly
        XCTAssertNotNil(userGraphViewModel)
        XCTAssertTrue(userGraphViewModel.graphNodes.isEmpty)
        XCTAssertTrue(userGraphViewModel.pinnedNodes.isEmpty)
        XCTAssertTrue(userGraphViewModel.userEdges.isEmpty)
        XCTAssertEqual(userGraphViewModel.offset, .zero)
        XCTAssertEqual(userGraphViewModel.zoomScale, 1.0)
    }
    
    func testSyncFromStorageWithNoGraphs() async throws {
        // Test syncing when no graphs exist
        await userGraphViewModel.syncFromStorage()
        
        XCTAssertTrue(userGraphViewModel.graphNodes.isEmpty)
    }
    
    func testSyncFromStorageWithGraphs() async throws {
        // Create test graphs in storage
        try await storage.createNewGraph(name: "Graph1")
        try await storage.createNewGraph(name: "Graph2")
        
        await userGraphViewModel.syncFromStorage()
        
        XCTAssertEqual(userGraphViewModel.graphNodes.count, 2)
        XCTAssertTrue(userGraphViewModel.graphNodes.contains(where: { $0.graphName == "Graph1" }))
        XCTAssertTrue(userGraphViewModel.graphNodes.contains(where: { $0.graphName == "Graph2" }))
    }
    
    func testAddGraphNode() async throws {
        // Test adding a new graph node
        let initialCount = userGraphViewModel.graphNodes.count
        
        await userGraphViewModel.addGraphNode(for: "NewGraph")
        
        XCTAssertEqual(userGraphViewModel.graphNodes.count, initialCount + 1)
        XCTAssertTrue(userGraphViewModel.graphNodes.contains(where: { $0.graphName == "NewGraph" }))
    }
    
    func testRemoveGraphNode() async throws {
        // Test removing a graph node
        await userGraphViewModel.addGraphNode(for: "ToRemove")
        let countAfterAdd = userGraphViewModel.graphNodes.count
        
        await userGraphViewModel.removeGraphNode(for: "ToRemove")
        
        XCTAssertEqual(userGraphViewModel.graphNodes.count, countAfterAdd - 1)
        XCTAssertFalse(userGraphViewModel.graphNodes.contains(where: { $0.graphName == "ToRemove" }))
    }
    
    // MARK: - Phase 3: Interactions Tests
    
    func testUpdateGraphNodePosition() async throws {
        // Test updating a graph node's position
        await userGraphViewModel.addGraphNode(for: "TestGraph")
        
        let newPosition = CGPoint(x: 300, y: 400)
        await userGraphViewModel.updateGraphNodePosition("TestGraph", to: newPosition)
        
        // Verify position was updated
        let node = userGraphViewModel.graphNodes.first(where: { $0.graphName == "TestGraph" })
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.position.x, 300)
        XCTAssertEqual(node?.position.y, 400)
        
        // Verify position was saved to storage
        let state = try await storage.loadUserGraphState()
        XCTAssertEqual(state?.graphPositions["TestGraph"]?.x, 300)
        XCTAssertEqual(state?.graphPositions["TestGraph"]?.y, 400)
    }
    
    func testAddUserEdge() async throws {
        // Test adding a user edge between graphs
        await userGraphViewModel.addGraphNode(for: "Graph1")
        await userGraphViewModel.addGraphNode(for: "Graph2")
        
        await userGraphViewModel.addUserEdge(from: "Graph1", to: "Graph2", label: "Connected")
        
        XCTAssertEqual(userGraphViewModel.userEdges.count, 1)
        XCTAssertEqual(userGraphViewModel.userEdges.first?.fromGraph, "Graph1")
        XCTAssertEqual(userGraphViewModel.userEdges.first?.toGraph, "Graph2")
        XCTAssertEqual(userGraphViewModel.userEdges.first?.label, "Connected")
    }
    
    func testRemoveUserEdge() async throws {
        // Test removing a user edge
        await userGraphViewModel.addUserEdge(from: "A", to: "B", label: nil)
        let edgeID = userGraphViewModel.userEdges.first!.id
        
        await userGraphViewModel.removeUserEdge(edgeID)
        
        XCTAssertTrue(userGraphViewModel.userEdges.isEmpty)
    }
    
    func testRemoveGraphNodeCleansUpEdges() async throws {
        // Test that removing a graph node removes associated edges
        await userGraphViewModel.addGraphNode(for: "Graph1")
        await userGraphViewModel.addGraphNode(for: "Graph2")
        await userGraphViewModel.addUserEdge(from: "Graph1", to: "Graph2", label: nil)
        
        await userGraphViewModel.removeGraphNode(for: "Graph1")
        
        // Edge should be removed since Graph1 was deleted
        XCTAssertTrue(userGraphViewModel.userEdges.isEmpty)
    }
    
    // MARK: - Phase 4: Pinning Tests
    
    func testPinNode() async throws {
        // Test pinning a node to the user graph
        let nodeID = UUID()
        
        await userGraphViewModel.pinNode(
            from: "SourceGraph",
            nodeID: nodeID,
            label: "Test Person",
            nodeType: "PersonNode",
            at: CGPoint(x: 100, y: 100)
        )
        
        XCTAssertEqual(userGraphViewModel.pinnedNodes.count, 1)
        XCTAssertEqual(userGraphViewModel.pinnedNodes.first?.sourceGraphName, "SourceGraph")
        XCTAssertEqual(userGraphViewModel.pinnedNodes.first?.sourceNodeID, nodeID)
        XCTAssertEqual(userGraphViewModel.pinnedNodes.first?.cachedLabel, "Test Person")
        XCTAssertEqual(userGraphViewModel.pinnedNodes.first?.cachedNodeType, "PersonNode")
    }
    
    func testUnpinNode() async throws {
        // Test unpinning a node
        let nodeID = UUID()
        
        await userGraphViewModel.pinNode(
            from: "SourceGraph",
            nodeID: nodeID,
            label: "Test",
            nodeType: "PersonNode",
            at: CGPoint(x: 0, y: 0)
        )
        
        let pinID = userGraphViewModel.pinnedNodes.first!.id
        
        await userGraphViewModel.unpinNode(pinID)
        
        XCTAssertTrue(userGraphViewModel.pinnedNodes.isEmpty)
    }
    
    func testRemoveGraphNodeCleansUpPins() async throws {
        // Test that removing a graph node removes associated pins
        let nodeID = UUID()
        
        await userGraphViewModel.pinNode(
            from: "GraphToRemove",
            nodeID: nodeID,
            label: "Person",
            nodeType: "PersonNode",
            at: CGPoint(x: 0, y: 0)
        )
        
        await userGraphViewModel.removeGraphNode(for: "GraphToRemove")
        
        // Pin should be removed since source graph was deleted
        XCTAssertTrue(userGraphViewModel.pinnedNodes.isEmpty)
    }
    
    func testPinStatePersistence() async throws {
        // Test that pinned nodes persist to storage
        let nodeID = UUID()
        
        await userGraphViewModel.pinNode(
            from: "TestGraph",
            nodeID: nodeID,
            label: "Pinned Node",
            nodeType: "MealNode",
            at: CGPoint(x: 50, y: 50)
        )
        
        // Verify it was saved to storage
        let state = try await storage.loadUserGraphState()
        XCTAssertEqual(state?.pinnedNodes.count, 1)
        XCTAssertEqual(state?.pinnedNodes.first?.cachedLabel, "Pinned Node")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteUserGraphWorkflow() async throws {
        // Test a complete workflow: create graphs, position them, add edges, pin nodes
        
        // 1. Create graphs
        try await storage.createNewGraph(name: "TacoNight1")
        try await storage.createNewGraph(name: "TacoNight2")
        
        // 2. Sync to user graph
        await userGraphViewModel.syncFromStorage()
        XCTAssertEqual(userGraphViewModel.graphNodes.count, 2)
        
        // 3. Update positions
        await userGraphViewModel.updateGraphNodePosition("TacoNight1", to: CGPoint(x: 100, y: 100))
        await userGraphViewModel.updateGraphNodePosition("TacoNight2", to: CGPoint(x: 300, y: 100))
        
        // 4. Create edge
        await userGraphViewModel.addUserEdge(from: "TacoNight1", to: "TacoNight2", label: "Same People")
        XCTAssertEqual(userGraphViewModel.userEdges.count, 1)
        
        // 5. Pin a node
        let nodeID = UUID()
        await userGraphViewModel.pinNode(
            from: "TacoNight1",
            nodeID: nodeID,
            label: "Alice",
            nodeType: "PersonNode",
            at: CGPoint(x: 400, y: 100)
        )
        XCTAssertEqual(userGraphViewModel.pinnedNodes.count, 1)
        
        // 6. Verify everything persisted
        let state = try await storage.loadUserGraphState()
        XCTAssertEqual(state?.graphPositions.count, 2)
        XCTAssertEqual(state?.userEdges.count, 1)
        XCTAssertEqual(state?.pinnedNodes.count, 1)
    }
    
    func testAutoLayoutPositioning() async throws {
        // Test that new graphs get auto-layout positions
        await userGraphViewModel.addGraphNode(for: "Graph1")
        await userGraphViewModel.addGraphNode(for: "Graph2")
        await userGraphViewModel.addGraphNode(for: "Graph3")
        
        // All nodes should have positions
        for node in userGraphViewModel.graphNodes {
            XCTAssertNotEqual(node.position, .zero)
        }
        
        // Positions should be different (radial layout)
        let positions = userGraphViewModel.graphNodes.map { $0.position }
        let uniquePositions = Set(positions.map { "\($0.x),\($0.y)" })
        XCTAssertEqual(positions.count, uniquePositions.count, "All positions should be unique")
    }
    
    func testStateRecoveryAfterReset() async throws {
        // Test that state can be recovered after view model reset
        
        // Setup initial state
        await userGraphViewModel.addGraphNode(for: "Graph1")
        await userGraphViewModel.updateGraphNodePosition("Graph1", to: CGPoint(x: 123, y: 456))
        await userGraphViewModel.addUserEdge(from: "Graph1", to: "Graph2", label: "Test")
        
        let nodeID = UUID()
        await userGraphViewModel.pinNode(
            from: "Graph1",
            nodeID: nodeID,
            label: "Node1",
            nodeType: "PersonNode",
            at: CGPoint(x: 100, y: 100)
        )
        
        // Create new view model instance (simulates app restart)
        let newViewModel = UserGraphViewModel(storage: storage)
        await newViewModel.syncFromStorage()
        
        // Verify state was recovered
        XCTAssertEqual(newViewModel.graphNodes.count, 1)
        XCTAssertEqual(newViewModel.userEdges.count, 1)
        XCTAssertEqual(newViewModel.pinnedNodes.count, 1)
        
        let recoveredNode = newViewModel.graphNodes.first { $0.graphName == "Graph1" }
        XCTAssertEqual(recoveredNode?.position.x, 123)
        XCTAssertEqual(recoveredNode?.position.y, 456)
    }
}
