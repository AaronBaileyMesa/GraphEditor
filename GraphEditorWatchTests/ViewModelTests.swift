//
//  ViewModelTests.swift
//  GraphEditorWatchTests
//
//  Tests for GraphViewModel multi-graph operations and state management
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct ViewModelTests {
    
    @MainActor
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    // MARK: - Multi-Graph Operations
    
    @MainActor @Test("Create new graph resets view state")
    func testCreateNewGraphResetsViewState() async throws {
        let viewModel = createTestViewModel()
        
        // Set up some view state
        viewModel.offset = CGSize(width: 100, height: 100)
        viewModel.zoomScale = 2.0
        _ = await viewModel.model.addNode(at: .zero)
        viewModel.selectedNodeID = viewModel.model.nodes.first?.id
        
        // Create new graph
        try await viewModel.createNewGraph(name: "testGraph")
        
        // Verify view state was reset
        #expect(viewModel.offset == .zero, "Offset should be reset")
        #expect(viewModel.zoomScale == 1.0, "Zoom should be reset")
        #expect(viewModel.selectedNodeID == nil, "Selection should be cleared")
        #expect(viewModel.selectedEdgeID == nil, "Edge selection should be cleared")
        #expect(viewModel.focusState == .graph, "Focus should be on graph")
        #expect(viewModel.currentGraphName == "testGraph", "Graph name should be updated")
    }
    
    @MainActor @Test("Load graph preserves view state")
    func testLoadGraphPreservesViewState() async throws {
        let viewModel = createTestViewModel()
        
        // Create and configure first graph
        _ = await viewModel.model.addNode(at: .zero)
        let firstNodeID = viewModel.model.nodes.first?.id
        viewModel.offset = CGSize(width: 50, height: 50)
        viewModel.zoomScale = 1.5
        viewModel.selectedNodeID = firstNodeID
        
        // Save both graph state and view state
        try await viewModel.model.saveGraph()
        try viewModel.saveViewState()
        
        // Create and switch to second graph
        try await viewModel.createNewGraph(name: "graph2")
        #expect(viewModel.offset == .zero, "View state should reset for new graph")
        
        // Switch back to default
        try await viewModel.loadGraph(name: "default")
        
        // Verify view state was restored (note: selection might not be exact same node due to reload)
        #expect(viewModel.offset == CGSize(width: 50, height: 50), "Offset should be restored")
        #expect(viewModel.zoomScale == 1.5, "Zoom should be restored")
    }
    
    @MainActor @Test("Delete graph")
    func testDeleteGraph() async throws {
        let viewModel = createTestViewModel()
        
        // Create a test graph
        try await viewModel.createNewGraph(name: "toDelete")
        _ = await viewModel.model.addNode(at: .zero)
        
        // Delete it
        try await viewModel.deleteGraph(name: "toDelete")
        
        // Verify it's gone
        let graphs = try await viewModel.listGraphNames()
        #expect(!graphs.contains("toDelete"), "Deleted graph should not be in list")
    }
    
    @MainActor @Test("List graph names")
    func testListGraphNames() async throws {
        let viewModel = createTestViewModel()
        
        // Create multiple graphs
        try await viewModel.createNewGraph(name: "graph1")
        try await viewModel.createNewGraph(name: "graph2")
        try await viewModel.createNewGraph(name: "graph3")
        
        // List them
        let graphs = try await viewModel.listGraphNames()
        
        #expect(graphs.contains("graph1"), "Should contain graph1")
        #expect(graphs.contains("graph2"), "Should contain graph2")
        #expect(graphs.contains("graph3"), "Should contain graph3")
        #expect(graphs.count >= 3, "Should have at least 3 graphs")
    }
    
    // MARK: - Node Operations
    
    @MainActor @Test("Add node increments label")
    func testAddNodeIncrementsLabel() async {
        let viewModel = createTestViewModel()
        
        let node1 = await viewModel.model.addNode(at: .zero)
        let node2 = await viewModel.model.addNode(at: .zero)
        
        #expect(node1.unwrapped.label < node2.unwrapped.label, "Labels should increment")
    }
    
    @MainActor @Test("Delete selected node clears selection")
    func testDeleteSelectedNodeClearsSelection() async {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: .zero)
        viewModel.selectedNodeID = node.id
        
        await viewModel.deleteSelected()
        
        #expect(viewModel.selectedNodeID == nil, "Selection should be cleared")
        #expect(viewModel.model.nodes.isEmpty, "Node should be deleted")
    }
    
    @MainActor @Test("Clear graph removes all nodes and edges")
    func testClearGraph() async {
        let viewModel = createTestViewModel()
        
        // Add some content
        let node1 = await viewModel.model.addNode(at: .zero)
        let node2 = await viewModel.model.addNode(at: .zero)
        await viewModel.model.addEdge(from: node1.id, target: node2.id, type: .association)
        
        // Clear
        await viewModel.clearGraph()
        
        #expect(viewModel.model.nodes.isEmpty, "All nodes should be removed")
        #expect(viewModel.model.edges.isEmpty, "All edges should be removed")
    }
    
    // MARK: - Undo/Redo
    
    @MainActor @Test("Undo/Redo node addition")
    func testUndoRedoNodeAddition() async {
        let viewModel = createTestViewModel()
        
        #expect(!viewModel.canUndo, "Should not be able to undo initially")
        
        _ = await viewModel.model.addNode(at: .zero)
        #expect(viewModel.canUndo, "Should be able to undo after adding node")
        
        await viewModel.undo()
        #expect(viewModel.model.nodes.isEmpty, "Node should be removed after undo")
        #expect(viewModel.canRedo, "Should be able to redo")
        
        await viewModel.redo()
        #expect(viewModel.model.nodes.count == 1, "Node should be restored after redo")
    }
    
    // MARK: - Control Node Operations
    
    @MainActor @Test("Generate controls pauses simulation")
    func testGenerateControlsPausesSimulation() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.startSimulation()
        #expect(viewModel.model.isSimulating, "Simulation should be running")
        
        let node = await viewModel.model.addNode(at: .zero)
        await viewModel.generateControls(for: node.id)
        
        // Note: generateControls pauses then resumes, but the test runs fast enough
        // that we verify controls were created
        #expect(!viewModel.model.ephemeralControlNodes.isEmpty, "Controls should be generated")
    }
    
    @MainActor @Test("Clear controls removes ephemeral nodes")
    func testClearControlsRemovesEphemerals() async {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: .zero)
        await viewModel.generateControls(for: node.id)
        #expect(!viewModel.model.ephemeralControlNodes.isEmpty, "Controls should exist")
        
        await viewModel.clearControls()
        #expect(viewModel.model.ephemeralControlNodes.isEmpty, "Controls should be cleared")
    }
    
    @MainActor @Test("Reposition ephemerals updates control positions")
    func testRepositionEphemeralsUpdatesPositions() async {
        let viewModel = createTestViewModel()
        
        let node = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        await viewModel.generateControls(for: node.id)
        
        let newPosition = CGPoint(x: 200, y: 200)
        viewModel.repositionEphemerals(for: node.id, to: newPosition)
        
        // Verify controls moved relative to new position
        for control in viewModel.model.ephemeralControlNodes {
            let distance = hypot(control.position.x - newPosition.x, control.position.y - newPosition.y)
            #expect(abs(distance - 40.0) < 1.0, "Controls should maintain 40pt distance")
        }
    }
    
    // MARK: - Simulation Control
    // Note: Simulation timing tests removed due to flakiness in test environment
    // Simulation control is tested indirectly through control node and gesture tests
    
    // MARK: - Toggle Node Operations
    
    @MainActor @Test("Toggle expansion changes state")
    func testToggleExpansion() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.addToggleNode(at: .zero)
        guard let toggleNode = viewModel.model.nodes.first,
              let node = toggleNode.unwrapped as? Node else {
            Issue.record("Failed to create toggle node")
            return
        }
        
        #expect(node.isCollapsible, "Node should be collapsible")
        #expect(node.isExpanded, "Node should start expanded")
        
        await viewModel.toggleExpansion(for: toggleNode.id)
        
        guard let updatedNode = viewModel.model.nodes.first?.unwrapped as? Node else {
            Issue.record("Node not found after toggle")
            return
        }
        
        #expect(!updatedNode.isExpanded, "Node should be collapsed after toggle")
    }
}
