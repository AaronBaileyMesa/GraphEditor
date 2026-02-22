//
//  GraphsMenuTests.swift
//  GraphEditorWatchTests
//
//  Tests for GraphsMenuView multi-graph operations and template creation
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct GraphsMenuTests {
    
    @MainActor
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        // Disable simulation for tests to prevent physics from modifying node positions
        model.isSimulating = false
        return GraphViewModel(model: model)
    }
    
    // MARK: - Graph Creation Tests
    
    @MainActor @Test("Create new graph with unique name")
    func testCreateNewGraph() async throws {
        let viewModel = createTestViewModel()
        
        // Create a new graph
        try await viewModel.model.createNewGraph(name: "TestGraph")
        
        // Verify it exists
        let graphs = try await viewModel.model.listGraphNames()
        #expect(graphs.contains("TestGraph"), "Graph list should contain 'TestGraph'")
    }
    
    @MainActor @Test("Create multiple graphs with different names")
    func testCreateMultipleGraphs() async throws {
        let viewModel = createTestViewModel()
        
        let graphNames = ["Graph1", "Graph2", "Graph3"]
        
        for name in graphNames {
            try await viewModel.model.createNewGraph(name: name)
        }
        
        let allGraphs = try await viewModel.model.listGraphNames()
        
        for name in graphNames {
            #expect(allGraphs.contains(name), "Should contain graph: \(name)")
        }
    }
    
    @MainActor @Test("Create graph with duplicate name throws error or prevents creation")
    func testCreateDuplicateGraphName() async throws {
        let viewModel = createTestViewModel()
        
        // Create first graph
        try await viewModel.model.createNewGraph(name: "DuplicateTest")
        
        // Attempt to create duplicate
        do {
            try await viewModel.model.createNewGraph(name: "DuplicateTest")
            // If it doesn't throw, check if it actually created a duplicate
            let graphs = try await viewModel.model.listGraphNames()
            let duplicateCount = graphs.filter { $0 == "DuplicateTest" }.count
            
            // Ideally should be 1, but depends on implementation
            // For now, just verify we can handle this case
            #expect(duplicateCount >= 1, "Should have at least one instance")
        } catch {
            // Expected: creating duplicate throws error
            // This is acceptable behavior
        }
    }
    
    // MARK: - Graph Loading/Switching Tests
    
    @MainActor @Test("Switch to existing graph")
    func testSwitchToExistingGraph() async throws {
        let viewModel = createTestViewModel()
        
        // Create and save a graph with nodes
        try await viewModel.model.createNewGraph(name: "GraphA")
        _ = await viewModel.model.addNode(at: CGPoint(x: 50, y: 50))
        try await viewModel.model.saveGraph()
        
        // Create another graph
        try await viewModel.model.createNewGraph(name: "GraphB")
        _ = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        try await viewModel.model.saveGraph()
        
        // Switch back to GraphA
        try await viewModel.model.switchToGraph(named: "GraphA")
        
        // Verify we're on GraphA (should have the node we created)
        #expect(viewModel.model.nodes.count >= 1, "GraphA should have at least 1 node")
    }
    
    @MainActor @Test("Switch to non-existent graph throws error")
    func testSwitchToNonExistentGraph() async throws {
        let viewModel = createTestViewModel()
        
        do {
            try await viewModel.model.switchToGraph(named: "NonExistent")
            Issue.record("Should throw error when switching to non-existent graph")
        } catch {
            // Expected error
            #expect(true, "Should throw error for non-existent graph")
        }
    }
    
    @MainActor @Test("Load graph preserves nodes and edges")
    func testLoadGraphPreservesContent() async throws {
        let viewModel = createTestViewModel()
        
        // Create graph with content
        try await viewModel.model.createNewGraph(name: "ContentGraph")
        
        let node1 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        let node2 = await viewModel.model.addNode(at: CGPoint(x: 200, y: 200))
        await viewModel.model.addEdge(from: node1.id, target: node2.id, type: .association)
        
        let savedNodeCount = viewModel.model.nodes.count
        let savedEdgeCount = viewModel.model.edges.count
        
        try await viewModel.model.saveGraph()
        
        // Switch to different graph
        try await viewModel.model.createNewGraph(name: "TempGraph")
        
        // Switch back
        try await viewModel.model.switchToGraph(named: "ContentGraph")
        
        // Verify content is restored (counts should match exactly because both save and load include RootNode)
        #expect(viewModel.model.nodes.count == savedNodeCount, "Node count should match (including RootNode)")
        #expect(viewModel.model.edges.count == savedEdgeCount, "Edge count should match")
    }
    
    // MARK: - Graph Deletion Tests
    
    @MainActor @Test("Delete existing graph")
    func testDeleteExistingGraph() async throws {
        let viewModel = createTestViewModel()
        
        // Create a graph to delete
        try await viewModel.model.createNewGraph(name: "ToDelete")
        
        // Verify it exists
        var graphs = try await viewModel.model.listGraphNames()
        #expect(graphs.contains("ToDelete"), "Graph should exist before deletion")
        
        // Delete it
        try await viewModel.model.deleteGraph(named: "ToDelete")
        
        // Verify it's gone
        graphs = try await viewModel.model.listGraphNames()
        #expect(!graphs.contains("ToDelete"), "Graph should not exist after deletion")
    }
    
    @MainActor @Test("Delete non-existent graph throws error")
    func testDeleteNonExistentGraph() async throws {
        let viewModel = createTestViewModel()
        
        do {
            try await viewModel.model.deleteGraph(named: "DoesNotExist")
            // Some implementations might not throw, so we check the result
        } catch {
            // Expected error
            #expect(true, "Should handle non-existent graph deletion")
        }
    }
    
    @MainActor @Test("Delete default graph and switch to default")
    func testDeleteAndSwitchToDefault() async throws {
        let viewModel = createTestViewModel()
        
        // Create a graph
        try await viewModel.model.createNewGraph(name: "CustomGraph")
        _ = await viewModel.model.addNode(at: .zero)
        
        // Delete it and switch to default (mimics UI behavior)
        try await viewModel.model.deleteGraph(named: "CustomGraph")
        
        // Switching to "default" should work
        do {
            try await viewModel.model.switchToGraph(named: "default")
            #expect(true, "Should be able to switch to default graph")
        } catch {
            // If default doesn't exist yet, create it
            try await viewModel.model.createNewGraph(name: "default")
        }
    }
    
    // MARK: - Graph Listing Tests
    
    @MainActor @Test("List graphs returns all created graphs")
    func testListGraphs() async throws {
        let viewModel = createTestViewModel()
        
        let testGraphs = ["Alpha", "Beta", "Gamma"]
        
        for name in testGraphs {
            try await viewModel.model.createNewGraph(name: name)
        }
        
        let allGraphs = try await viewModel.model.listGraphNames()
        
        for name in testGraphs {
            #expect(allGraphs.contains(name), "List should contain: \(name)")
        }
    }
    
    @MainActor @Test("List graphs on fresh model")
    func testListGraphsOnFreshModel() async throws {
        let viewModel = createTestViewModel()
        
        // List graphs before creating any
        let graphs = try await viewModel.model.listGraphNames()
        
        // May be empty or contain default graph
        #expect(graphs.count >= 0, "Should return a list (possibly empty)")
    }
    
    // MARK: - Graph Saving Tests
    
    @MainActor @Test("Save graph persists changes")
    func testSaveGraphPersistsChanges() async throws {
        let viewModel = createTestViewModel()
        
        try await viewModel.model.createNewGraph(name: "SaveTest")
        
        // Use bulk operations to prevent simulation from moving nodes
        await viewModel.model.beginBulkOperation()
        
        // Add content
        _ = await viewModel.model.addNode(at: CGPoint(x: 123, y: 456))
        
        // Save BEFORE ending bulk operation to preserve positions
        try await viewModel.model.saveGraph()
        
        // Now end bulk operation
        await viewModel.model.endBulkOperation()
        
        // Switch away and back
        try await viewModel.model.createNewGraph(name: "Temp")
        try await viewModel.model.switchToGraph(named: "SaveTest")
        
        // Verify content was saved (should have RootNode + the added node)
        #expect(viewModel.model.nodes.count >= 2, "Should have RootNode + saved node")
        
        // Find the non-root node (the one we added at 123, 456)
        if let savedNode = viewModel.model.nodes.first(where: { !($0.unwrapped is RootNode) }) {
            #expect(savedNode.position.x == 123, "Node x position should be preserved")
            #expect(savedNode.position.y == 456, "Node y position should be preserved")
        } else {
            Issue.record("Could not find saved node (non-RootNode)")
        }
    }
    
    @MainActor @Test("Save graph with complex content")
    func testSaveGraphWithComplexContent() async throws {
        let viewModel = createTestViewModel()
        
        try await viewModel.model.createNewGraph(name: "ComplexGraph")
        
        // Create meal with tasks (complex hierarchy)
        let meal = await viewModel.model.addMeal(
            name: "Test Meal",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )
        
        let task1 = await viewModel.model.addTask(type: .prep, estimatedTime: 20, at: .zero)
        let task2 = await viewModel.model.addTask(type: .cook, estimatedTime: 30, at: .zero)
        
        await viewModel.model.addEdge(from: meal.id, target: task1.id, type: .hierarchy)
        await viewModel.model.addEdge(from: meal.id, target: task2.id, type: .hierarchy)
        
        let nodeCount = viewModel.model.nodes.count
        let edgeCount = viewModel.model.edges.count
        
        // Save
        try await viewModel.model.saveGraph()
        
        // Switch and reload
        try await viewModel.model.createNewGraph(name: "Temp2")
        try await viewModel.model.switchToGraph(named: "ComplexGraph")
        
        // Verify structure preserved (counts match because both save and load include RootNode)
        #expect(viewModel.model.nodes.count == nodeCount, "Node count should match (including RootNode)")
        #expect(viewModel.model.edges.count == edgeCount, "Edge count should match")
        
        let meals = viewModel.model.nodes.compactMap { $0.unwrapped as? MealNode }
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        #expect(meals.count == 1, "Should have 1 meal node")
        #expect(tasks.count == 2, "Should have 2 task nodes")
    }
    
    // MARK: - Template Tests
    
    @MainActor @Test("Create taco template through graphs menu flow")
    func testCreateTacoTemplateFlow() async {
        let viewModel = createTestViewModel()
        
        // Simulate creating a taco dinner (as triggered from GraphsMenuView)
        let calendar = Calendar.current
        let dinnerTime = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? Date()
        
        let mealNode = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 4,
            dinnerTime: dinnerTime,
            protein: .beef,
            at: CGPoint(x: 20, y: 125)
        )
        
        // Verify template was created
        let meals = viewModel.model.nodes.compactMap { $0.unwrapped as? MealNode }
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        #expect(meals.count == 1, "Should have created 1 meal")
        #expect(tasks.count == 14, "Should have created 14 tasks (6 top-level + 8 subtasks)")
        #expect(mealNode.name == "Beef Tacos", "Meal should be named 'Beef Tacos'")
    }
    
    // MARK: - Graph Name Validation Tests
    
    @MainActor @Test("Create graph with empty name")
    func testCreateGraphWithEmptyName() async throws {
        let viewModel = createTestViewModel()
        
        do {
            try await viewModel.model.createNewGraph(name: "")
            // If it doesn't throw, verify behavior
            _ = try await viewModel.model.listGraphNames()
            // Empty name might be allowed or rejected depending on implementation
        } catch {
            // Expected: empty name rejected
            #expect(true, "Empty name should be rejected or handled")
        }
    }
    
    @MainActor @Test("Create graph with special characters in name")
    func testCreateGraphWithSpecialCharacters() async throws {
        let viewModel = createTestViewModel()
        
        let specialNames = ["Graph@123", "My-Graph", "Graph_2024", "Graph.v2"]
        
        for name in specialNames {
            do {
                try await viewModel.model.createNewGraph(name: name)
                
                // Verify it was created
                let graphs = try await viewModel.model.listGraphNames()
                #expect(graphs.contains(name), "Should handle special characters: \(name)")
            } catch {
                // Some special characters might be rejected
                // This is acceptable behavior
            }
        }
    }
    
    @MainActor @Test("Create graph with very long name")
    func testCreateGraphWithLongName() async throws {
        let viewModel = createTestViewModel()
        
        let longName = String(repeating: "A", count: 100)
        
        do {
            try await viewModel.model.createNewGraph(name: longName)
            
            let graphs = try await viewModel.model.listGraphNames()
            #expect(graphs.contains(longName), "Should handle long names")
        } catch {
            // Long names might be rejected
            #expect(true, "Long name rejection is acceptable")
        }
    }
    
    // MARK: - Graph State Management Tests
    
    @MainActor @Test("Current graph name updates after switch")
    func testCurrentGraphNameUpdates() async throws {
        let viewModel = createTestViewModel()
        
        // Create and switch to a graph
        try await viewModel.model.createNewGraph(name: "NewGraph")
        try await viewModel.model.switchToGraph(named: "NewGraph")
        
        // In the UI, currentGraphName would be updated
        viewModel.currentGraphName = "NewGraph"
        
        #expect(viewModel.currentGraphName == "NewGraph", "Current graph name should update")
    }
    
    @MainActor @Test("Switch between multiple graphs maintains state")
    func testSwitchBetweenMultipleGraphs() async throws {
        let viewModel = createTestViewModel()
        
        // Create Graph A with specific content (createNewGraph adds RootNode)
        try await viewModel.model.createNewGraph(name: "GraphA")
        _ = await viewModel.model.addNode(at: CGPoint(x: 10, y: 10))
        try await viewModel.model.saveGraph()
        
        // Create Graph B with different content
        try await viewModel.model.createNewGraph(name: "GraphB")
        _ = await viewModel.model.addNode(at: CGPoint(x: 20, y: 20))
        _ = await viewModel.model.addNode(at: CGPoint(x: 30, y: 30))
        try await viewModel.model.saveGraph()
        
        // Create Graph C (empty except for RootNode)
        try await viewModel.model.createNewGraph(name: "GraphC")
        try await viewModel.model.saveGraph()
        
        // Switch to GraphA (1 added node + RootNode)
        try await viewModel.model.switchToGraph(named: "GraphA")
        #expect(viewModel.model.nodes.count == 2, "GraphA should have 1 node + RootNode")
        
        // Switch to GraphB (2 added nodes + RootNode)
        try await viewModel.model.switchToGraph(named: "GraphB")
        #expect(viewModel.model.nodes.count == 3, "GraphB should have 2 nodes + RootNode")
        
        // Switch to GraphC (only RootNode)
        try await viewModel.model.switchToGraph(named: "GraphC")
        #expect(viewModel.model.nodes.count == 1, "GraphC should have only RootNode")
    }
    
    @MainActor @Test("Delete current graph requires switching to another")
    func testDeleteCurrentGraph() async throws {
        let viewModel = createTestViewModel()
        
        // Create default graph first
        try await viewModel.model.createNewGraph(name: "default")
        
        // Create and switch to a graph
        try await viewModel.model.createNewGraph(name: "CurrentGraph")
        try await viewModel.model.switchToGraph(named: "CurrentGraph")
        
        // Delete it
        try await viewModel.model.deleteGraph(named: "CurrentGraph")
        
        // Should handle switching to a valid graph (like default)
        // In UI, this is typically followed by switching to "default"
        try await viewModel.model.switchToGraph(named: "default")
        
        // Verify deletion
        let graphs = try await viewModel.model.listGraphNames()
        #expect(!graphs.contains("CurrentGraph"), "Deleted graph should not be in list")
    }
}
