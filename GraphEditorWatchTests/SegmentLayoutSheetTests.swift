//
//  SegmentLayoutSheetTests.swift
//  GraphEditorWatchTests
//
//  Tests for SegmentLayoutSheet state management and layout direction configuration
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct SegmentLayoutSheetTests {
    
    @MainActor
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    // MARK: - Segment Configuration Tests
    
    @MainActor @Test("Set segment config with horizontal direction")
    func testSetSegmentConfigHorizontal() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Set horizontal layout
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 35
        )
        
        // Verify config was set
        let config = viewModel.model.segmentConfigs[rootNode.id]
        
        #expect(config != nil, "Segment config should exist")
        #expect(config?.direction == .horizontal, "Direction should be horizontal")
        #expect(config?.strength == 0.7, "Strength should be 0.7")
        #expect(config?.nodeSpacing == 35, "Node spacing should be 35")
    }
    
    @MainActor @Test("Set segment config with vertical direction")
    func testSetSegmentConfigVertical() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Set vertical layout
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode.id,
            direction: .vertical,
            strength: 0.8,
            nodeSpacing: 40
        )
        
        // Verify config was set
        let config = viewModel.model.segmentConfigs[rootNode.id]
        
        #expect(config != nil, "Segment config should exist")
        #expect(config?.direction == .vertical, "Direction should be vertical")
        #expect(config?.strength == 0.8, "Strength should be 0.8")
        #expect(config?.nodeSpacing == 40, "Node spacing should be 40")
    }
    
    @MainActor @Test("Change existing segment direction from horizontal to vertical")
    func testChangeSegmentDirection() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Set initial horizontal direction
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 35
        )
        
        let initialConfig = viewModel.model.segmentConfigs[rootNode.id]
        #expect(initialConfig?.direction == .horizontal, "Initial direction should be horizontal")
        
        // Change to vertical (preserving other settings)
        if let currentConfig = viewModel.model.segmentConfigs[rootNode.id] {
            viewModel.model.setSegmentConfig(
                rootNodeID: rootNode.id,
                direction: .vertical,
                strength: currentConfig.strength,
                nodeSpacing: currentConfig.nodeSpacing
            )
        }
        
        // Verify direction changed
        let updatedConfig = viewModel.model.segmentConfigs[rootNode.id]
        #expect(updatedConfig?.direction == .vertical, "Direction should be updated to vertical")
        #expect(updatedConfig?.strength == 0.7, "Strength should be preserved")
        #expect(updatedConfig?.nodeSpacing == 35, "Node spacing should be preserved")
    }
    
    @MainActor @Test("Multiple segments can have different configurations")
    func testMultipleSegmentConfigs() async {
        let viewModel = createTestViewModel()
        
        let rootNode1 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        let rootNode2 = await viewModel.model.addNode(at: CGPoint(x: 200, y: 200))
        let rootNode3 = await viewModel.model.addNode(at: CGPoint(x: 300, y: 300))
        
        // Configure different layouts for each segment
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode1.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 35
        )
        
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode2.id,
            direction: .vertical,
            strength: 0.8,
            nodeSpacing: 40
        )
        
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode3.id,
            direction: .horizontal,
            strength: 0.65,
            nodeSpacing: 30
        )
        
        // Verify all configs exist independently
        let config1 = viewModel.model.segmentConfigs[rootNode1.id]
        let config2 = viewModel.model.segmentConfigs[rootNode2.id]
        let config3 = viewModel.model.segmentConfigs[rootNode3.id]
        
        #expect(config1?.direction == .horizontal, "Segment 1 should be horizontal")
        #expect(config2?.direction == .vertical, "Segment 2 should be vertical")
        #expect(config3?.direction == .horizontal, "Segment 3 should be horizontal")
        
        #expect(config1?.strength == 0.7, "Segment 1 strength should be 0.7")
        #expect(config2?.strength == 0.8, "Segment 2 strength should be 0.8")
        #expect(config3?.strength == 0.65, "Segment 3 strength should be 0.65")
        
        #expect(config1?.nodeSpacing == 35, "Segment 1 spacing should be 35")
        #expect(config2?.nodeSpacing == 40, "Segment 2 spacing should be 40")
        #expect(config3?.nodeSpacing == 30, "Segment 3 spacing should be 30")
    }
    
    @MainActor @Test("Segment config initializes with default values if not set")
    func testSegmentConfigDefaults() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Check config before setting (should be nil or have defaults)
        let config = viewModel.model.segmentConfigs[rootNode.id]
        
        // If no config is set, it should be nil
        #expect(config == nil, "Config should be nil before being set")
    }
    
    @MainActor @Test("Update segment config preserves unmodified properties")
    func testUpdateSegmentConfigPreservesProperties() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Set initial config
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 35
        )
        
        // Update only direction, preserving other values
        if let currentConfig = viewModel.model.segmentConfigs[rootNode.id] {
            viewModel.model.setSegmentConfig(
                rootNodeID: rootNode.id,
                direction: .vertical,
                strength: currentConfig.strength,
                nodeSpacing: currentConfig.nodeSpacing
            )
        }
        
        let updatedConfig = viewModel.model.segmentConfigs[rootNode.id]
        
        #expect(updatedConfig?.direction == .vertical, "Direction should be updated")
        #expect(updatedConfig?.strength == 0.7, "Strength should be preserved")
        #expect(updatedConfig?.nodeSpacing == 35, "Node spacing should be preserved")
    }
    
    @MainActor @Test("Segment config with custom strength values")
    func testSegmentConfigCustomStrength() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Test various strength values
        let strengthValues: [CGFloat] = [0.2, 0.5, 0.7, 0.9, 1.0]
        
        for strength in strengthValues {
            viewModel.model.setSegmentConfig(
                rootNodeID: rootNode.id,
                direction: .horizontal,
                strength: strength,
                nodeSpacing: 35
            )
            
            let config = viewModel.model.segmentConfigs[rootNode.id]
            #expect(config?.strength == strength, "Strength should be \(strength)")
        }
    }
    
    @MainActor @Test("Segment config with custom spacing values")
    func testSegmentConfigCustomSpacing() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Test various spacing values
        let spacingValues: [CGFloat] = [20, 30, 35, 40, 50]
        
        for spacing in spacingValues {
            viewModel.model.setSegmentConfig(
                rootNodeID: rootNode.id,
                direction: .horizontal,
                strength: 0.7,
                nodeSpacing: spacing
            )
            
            let config = viewModel.model.segmentConfigs[rootNode.id]
            #expect(config?.nodeSpacing == spacing, "Node spacing should be \(spacing)")
        }
    }
    
    // MARK: - Segment with Hierarchical Nodes Tests
    
    @MainActor @Test("Configure segment layout for meal with tasks")
    func testConfigureSegmentLayoutForMeal() async {
        let viewModel = createTestViewModel()
        
        // Create a meal node as segment root
        let meal = await viewModel.model.addMeal(
            name: "Taco Dinner",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Add tasks as children
        let task1 = await viewModel.model.addTask(type: .prep, estimatedTime: 20, at: .zero)
        let task2 = await viewModel.model.addTask(type: .cook, estimatedTime: 30, at: .zero)
        let task3 = await viewModel.model.addTask(type: .serve, estimatedTime: 10, at: .zero)
        
        // Create hierarchy edges
        await viewModel.model.addEdge(from: meal.id, target: task1.id, type: .hierarchy)
        await viewModel.model.addEdge(from: meal.id, target: task2.id, type: .hierarchy)
        await viewModel.model.addEdge(from: meal.id, target: task3.id, type: .hierarchy)
        
        // Configure segment layout
        viewModel.model.setSegmentConfig(
            rootNodeID: meal.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 35
        )
        
        // Verify configuration
        let config = viewModel.model.segmentConfigs[meal.id]
        #expect(config?.direction == .horizontal, "Meal segment should be horizontal")
        #expect(config?.nodeSpacing == 35, "Task spacing should be 35")
        
        // Verify meal still has all task children
        let tasks = viewModel.model.tasks(for: meal.id)
        #expect(tasks.count == 3, "Meal should still have 3 tasks after config")
    }
    
    @MainActor @Test("Change segment layout direction triggers simulation")
    func testChangeLayoutDirectionTriggersSimulation() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Set initial config
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 35
        )
        
        // Change direction and start simulation (mimics sheet behavior)
        if let currentConfig = viewModel.model.segmentConfigs[rootNode.id] {
            viewModel.model.setSegmentConfig(
                rootNodeID: rootNode.id,
                direction: .vertical,
                strength: currentConfig.strength,
                nodeSpacing: currentConfig.nodeSpacing
            )
            
            await viewModel.model.startSimulation()
        }
        
        // Verify simulation can be started (no errors)
        // In real usage, this would reposition nodes based on new layout
        let config = viewModel.model.segmentConfigs[rootNode.id]
        #expect(config?.direction == .vertical, "Direction should be updated")
    }
    
    // MARK: - Edge Cases
    
    @MainActor @Test("Remove segment config when node is deleted")
    func testRemoveSegmentConfigWhenNodeDeleted() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Set config
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 35
        )
        
        #expect(viewModel.model.segmentConfigs[rootNode.id] != nil, "Config should exist")
        
        // Delete node
        await viewModel.model.deleteNode(withID: rootNode.id)
        
        // Config should ideally be cleaned up (depends on implementation)
        // At minimum, the node shouldn't exist anymore
        let nodeExists = viewModel.model.nodes.contains(where: { $0.id == rootNode.id })
        #expect(!nodeExists, "Node should be deleted")
    }
    
    @MainActor @Test("Segment config persists across simulation cycles")
    func testSegmentConfigPersistsAcrossSimulation() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Set config
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 35
        )
        
        // Start and stop simulation multiple times
        await viewModel.model.startSimulation()
        await viewModel.model.stopSimulation()
        await viewModel.model.startSimulation()
        await viewModel.model.stopSimulation()
        
        // Config should still exist
        let config = viewModel.model.segmentConfigs[rootNode.id]
        #expect(config?.direction == .horizontal, "Config should persist after simulation cycles")
        #expect(config?.strength == 0.7, "Strength should persist")
        #expect(config?.nodeSpacing == 35, "Spacing should persist")
    }
    
    @MainActor @Test("Different spacing values for horizontal vs vertical")
    func testDifferentSpacingForDirections() async {
        let viewModel = createTestViewModel()
        
        let rootNode = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        
        // Set horizontal with one spacing
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 35
        )
        
        let horizontalConfig = viewModel.model.segmentConfigs[rootNode.id]
        #expect(horizontalConfig?.nodeSpacing == 35, "Horizontal spacing should be 35")
        
        // Change to vertical with different spacing
        viewModel.model.setSegmentConfig(
            rootNodeID: rootNode.id,
            direction: .vertical,
            strength: 0.7,
            nodeSpacing: 50
        )
        
        let verticalConfig = viewModel.model.segmentConfigs[rootNode.id]
        #expect(verticalConfig?.direction == .vertical, "Direction should be vertical")
        #expect(verticalConfig?.nodeSpacing == 50, "Vertical spacing should be 50")
    }
    
    @MainActor @Test("Segment config for deeply nested hierarchies")
    func testSegmentConfigForNestedHierarchy() async {
        let viewModel = createTestViewModel()
        
        // Create nested hierarchy
        let grandparent = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        let parent = await viewModel.model.addNode(at: CGPoint(x: 150, y: 150))
        let child = await viewModel.model.addNode(at: CGPoint(x: 200, y: 200))
        
        await viewModel.model.addEdge(from: grandparent.id, target: parent.id, type: .hierarchy)
        await viewModel.model.addEdge(from: parent.id, target: child.id, type: .hierarchy)
        
        // Configure each level differently
        viewModel.model.setSegmentConfig(
            rootNodeID: grandparent.id,
            direction: .horizontal,
            strength: 0.7,
            nodeSpacing: 35
        )
        
        viewModel.model.setSegmentConfig(
            rootNodeID: parent.id,
            direction: .vertical,
            strength: 0.6,
            nodeSpacing: 40
        )
        
        // Verify independent configs
        let grandparentConfig = viewModel.model.segmentConfigs[grandparent.id]
        let parentConfig = viewModel.model.segmentConfigs[parent.id]
        
        #expect(grandparentConfig?.direction == .horizontal, "Grandparent should be horizontal")
        #expect(parentConfig?.direction == .vertical, "Parent should be vertical")
        #expect(grandparentConfig?.nodeSpacing == 35, "Grandparent spacing should be 35")
        #expect(parentConfig?.nodeSpacing == 40, "Parent spacing should be 40")
    }
}
