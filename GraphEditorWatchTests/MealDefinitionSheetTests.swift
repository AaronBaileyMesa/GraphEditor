//
//  MealDefinitionSheetTests.swift
//  GraphEditorWatchTests
//
//  Tests for MealDefinitionSheet form state management and taco template creation
//

import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct MealDefinitionSheetTests {
    
    @MainActor
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    // MARK: - Initial State Tests
    
    @MainActor @Test("MealDefinitionSheet initializes with default values")
    func testInitialState() async {
        let viewModel = createTestViewModel()
        var dismissed = false
        
        _ = MealDefinitionSheet(
            viewModel: viewModel,
            onDismiss: { dismissed = true }
        )
        
        // Verify initial state through rendering (we can't access @State directly,
        // but we can verify the view model is set correctly)
        #expect(viewModel.model.nodes.isEmpty, "Should start with no nodes")
        #expect(!dismissed, "Should not be dismissed initially")
    }
    
    // MARK: - Taco Plan Creation Tests
    
    @MainActor @Test("Creating taco plan adds meal node to graph")
    func testCreateTacoPlanAddsMealNode() async {
        let viewModel = createTestViewModel()
        
        // Simulate creating a taco plan by calling the template builder directly
        // (since we can't trigger button presses in unit tests)
        let calendar = Calendar.current
        let dinnerTime = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? Date()
        let mealPosition = CGPoint(x: 20, y: 125)
        
        _ = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 4,
            dinnerTime: dinnerTime,
            protein: .beef,
            at: mealPosition
        )
        
        // Verify meal node was created and graph has nodes
        #expect(viewModel.model.nodes.count > 0, "Graph should have nodes")
        
        // Find the meal node
        let mealNodes = viewModel.model.nodes.compactMap { $0.unwrapped as? MealNode }
        #expect(mealNodes.count == 1, "Should have exactly one meal node")
        
        if let meal = mealNodes.first {
            #expect(meal.name == "Beef Tacos", "Meal name should be 'Beef Tacos'")
            #expect(meal.servings == 4, "Servings should match guest count")
            #expect(meal.mealType == .dinner, "Meal type should be dinner")
            #expect(meal.guests == 4, "Guests should be 4")
            #expect(meal.protein == .beef, "Protein should be beef")
            // Position may be adjusted by layout algorithm
            let tolerance: CGFloat = 5.0
            #expect(abs(meal.position.x - mealPosition.x) < tolerance, "Position X should be close to expected")
            #expect(abs(meal.position.y - mealPosition.y) < tolerance, "Position Y should be close to expected")
        }
    }
    
    @MainActor @Test("Creating taco plan with chicken protein")
    func testCreateTacoPlanWithChicken() async {
        let viewModel = createTestViewModel()
        let calendar = Calendar.current
        let dinnerTime = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
        
        _ = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 6,
            dinnerTime: dinnerTime,
            protein: .chicken,
            at: CGPoint(x: 20, y: 125)
        )
        
        // Verify chicken protein selection
        let mealNodes = viewModel.model.nodes.compactMap { $0.unwrapped as? MealNode }
        #expect(mealNodes.count == 1, "Should have exactly one meal node")
        
        if let meal = mealNodes.first {
            #expect(meal.protein == .chicken, "Protein should be chicken")
            #expect(meal.servings == 6, "Servings should match guest count")
        }
    }
    
    @MainActor @Test("Creating taco plan adds task nodes")
    func testCreateTacoPlanAddsTaskNodes() async {
        let viewModel = createTestViewModel()
        let dinnerTime = Date()
        
        _ = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 4,
            dinnerTime: dinnerTime,
            protein: .beef,
            at: CGPoint(x: 20, y: 125)
        )
        
        // Verify task nodes were created
        let taskNodes = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        #expect(taskNodes.count == 5, "Should have 5 task nodes (plan, shop, prep, cook, serve)")
        
        // Verify all task types are present
        let taskTypes = Set(taskNodes.map { $0.taskType })
        #expect(taskTypes.contains(.plan), "Should have plan task")
        #expect(taskTypes.contains(.shop), "Should have shop task")
        #expect(taskTypes.contains(.prep), "Should have prep task")
        #expect(taskTypes.contains(.cook), "Should have cook task")
        #expect(taskTypes.contains(.serve), "Should have serve task")
        
        // Verify all tasks start as pending
        let allPending = taskNodes.allSatisfy { $0.status == .pending }
        #expect(allPending, "All tasks should start with pending status")
    }
    
    @MainActor @Test("Creating taco plan adds hierarchy edges")
    func testCreateTacoPlanAddsHierarchyEdges() async {
        let viewModel = createTestViewModel()
        let dinnerTime = Date()
        
        let mealNode = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 4,
            dinnerTime: dinnerTime,
            protein: .beef,
            at: CGPoint(x: 20, y: 125)
        )
        
        // Verify hierarchy edges create a linear chain
        // Meal -> Task1 -> Task2 -> Task3 -> Task4 -> Task5
        let hierarchyEdges = viewModel.model.edges.filter { $0.type == .hierarchy }
        #expect(hierarchyEdges.count == 5, "Should have 5 hierarchy edges forming a chain")
        
        // First hierarchy edge should come from the meal node
        let mealEdges = hierarchyEdges.filter { $0.from == mealNode.id }
        #expect(mealEdges.count == 1, "Meal should have 1 outgoing hierarchy edge")
    }
    
    @MainActor @Test("Creating taco plan with different guest counts")
    func testCreateTacoPlanWithDifferentGuestCounts() async {
        let viewModel = createTestViewModel()
        let dinnerTime = Date()
        
        // Test with 2 guests
        _ = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 2,
            dinnerTime: dinnerTime,
            protein: .beef,
            at: CGPoint(x: 20, y: 125)
        )
        
        let mealNodes2 = viewModel.model.nodes.compactMap { $0.unwrapped as? MealNode }
        if let meal = mealNodes2.first {
            #expect(meal.guests == 2, "Should have 2 guests")
            #expect(meal.servings == 2, "Servings should match guests")
        }
        
        // Clear and test with 8 guests
        viewModel.model.nodes.removeAll()
        viewModel.model.edges.removeAll()
        
        _ = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 8,
            dinnerTime: dinnerTime,
            protein: .chicken,
            at: CGPoint(x: 20, y: 125)
        )
        
        let mealNodes8 = viewModel.model.nodes.compactMap { $0.unwrapped as? MealNode }
        if let meal = mealNodes8.first {
            #expect(meal.guests == 8, "Should have 8 guests")
            #expect(meal.servings == 8, "Servings should match guests")
        }
    }
    
    @MainActor @Test("Creating taco plan sets correct dinner time")
    func testCreateTacoPlanSetsCorrectDinnerTime() async {
        let viewModel = createTestViewModel()
        
        let calendar = Calendar.current
        let specificTime = calendar.date(bySettingHour: 17, minute: 45, second: 0, of: Date()) ?? Date()
        
        _ = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 4,
            dinnerTime: specificTime,
            protein: .beef,
            at: CGPoint(x: 20, y: 125)
        )
        
        let mealNodes = viewModel.model.nodes.compactMap { $0.unwrapped as? MealNode }
        if let meal = mealNodes.first {
            // dinnerTime is non-optional in MealNode (always set)
            let timeDiff = abs(meal.dinnerTime.timeIntervalSince(specificTime))
            #expect(timeDiff < 1.0, "Dinner time should match specified time")
        }
    }
    
    @MainActor @Test("Creating multiple taco plans in same graph")
    func testCreateMultipleTacoPlans() async {
        let viewModel = createTestViewModel()
        let dinnerTime1 = Date()
        let dinnerTime2 = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        // Create first taco dinner
        _ = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 4,
            dinnerTime: dinnerTime1,
            protein: .beef,
            at: CGPoint(x: 20, y: 125)
        )
        
        let nodesAfterFirst = viewModel.model.nodes.count
        _ = viewModel.model.edges.count
        
        // Create second taco dinner
        _ = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 6,
            dinnerTime: dinnerTime2,
            protein: .chicken,
            at: CGPoint(x: 200, y: 125)
        )
        
        // Verify both dinners exist
        let mealNodes = viewModel.model.nodes.compactMap { $0.unwrapped as? MealNode }
        #expect(mealNodes.count == 2, "Should have two meal nodes")
        
        let taskNodes = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        #expect(taskNodes.count == 10, "Should have 10 task nodes (5 per meal)")
        
        // Verify nodes and edges doubled
        #expect(viewModel.model.nodes.count >= nodesAfterFirst * 2, "Should have roughly double the nodes")
    }
    
    // MARK: - Edge Cases
    
    @MainActor @Test("Creating taco plan at different positions")
    func testCreateTacoPlanAtDifferentPositions() async {
        let viewModel = createTestViewModel()
        let dinnerTime = Date()
        
        let positions = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 200),
            CGPoint(x: -50, y: 300)
        ]
        
        for position in positions {
            viewModel.model.nodes.removeAll()
            viewModel.model.edges.removeAll()
            
            _ = await TacoTemplateBuilder.buildGraph(
                in: viewModel.model,
                guests: 4,
                dinnerTime: dinnerTime,
                protein: .beef,
                at: position
            )
            
            let mealNodes = viewModel.model.nodes.compactMap { $0.unwrapped as? MealNode }
            if let meal = mealNodes.first {
                // TacoTemplateBuilder calculates anchorX based on layout algorithm
                // Y position may be adjusted slightly by physics simulation
                let tolerance: CGFloat = 70.0
                #expect(abs(meal.position.y - position.y) < tolerance, "Meal position Y should be close to: \(position.y)")
            }
        }
    }
    
    @MainActor @Test("Template builder preserves existing graph nodes")
    func testTemplateBuilderPreservesExistingNodes() async {
        let viewModel = createTestViewModel()
        
        // Add some existing nodes
        let existingNode1 = await viewModel.model.addNode(at: CGPoint(x: 50, y: 50))
        let existingNode2 = await viewModel.model.addNode(at: CGPoint(x: 100, y: 100))
        let existingCount = viewModel.model.nodes.count
        
        // Create taco dinner
        _ = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 4,
            dinnerTime: Date(),
            protein: .beef,
            at: CGPoint(x: 20, y: 125)
        )
        
        // Verify existing nodes are still there
        #expect(viewModel.model.nodes.count > existingCount, "Should have added new nodes")
        
        let hasExisting1 = viewModel.model.nodes.contains { $0.id == existingNode1.id }
        let hasExisting2 = viewModel.model.nodes.contains { $0.id == existingNode2.id }
        
        #expect(hasExisting1, "Should preserve existing node 1")
        #expect(hasExisting2, "Should preserve existing node 2")
    }
}
