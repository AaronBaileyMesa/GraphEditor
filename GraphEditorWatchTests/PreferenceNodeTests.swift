//
//  PreferenceNodeTests.swift
//  GraphEditorWatchTests
//
//  Tests for PreferenceNode generation and usage
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
import GraphEditorShared

@MainActor @Suite("PreferenceNode Tests")
struct PreferenceNodeTests {
    
    // MARK: - Test Helpers
    
    @available(watchOS 10.0, *)
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let screenBounds = CGSize(width: 205, height: 251)
        let simulationBounds = CGSize(width: screenBounds.width * 4, height: screenBounds.height * 4)
        let physicsEngine = PhysicsEngine(simulationBounds: simulationBounds, layoutMode: .hierarchy)
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    // MARK: - Tests
    
    @available(watchOS 10.0, *)
    @Test("Generate preference from decision tree")
    func testGeneratePreferenceFromDecisionTree() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.beginBulkOperation()
        
        // Create a simple decision tree
        let decision1 = await viewModel.model.addDecision(
            question: "How many guests?",
            preferenceKey: "guestCount",
            inputType: .numeric,
            at: CGPoint(x: 100, y: 100)
        )
        
        let decision2 = await viewModel.model.addDecision(
            question: "Protein?",
            preferenceKey: "protein",
            inputType: .singleChoice,
            at: CGPoint(x: 200, y: 100)
        )
        
        // Add choices to decision2
        _ = await viewModel.model.addChoice(
            to: decision2.id,
            choiceText: "Beef",
            value: .string("beef"),
            at: CGPoint(x: 200, y: 80)
        )
        
        let chickenChoice = await viewModel.model.addChoice(
            to: decision2.id,
            choiceText: "Chicken",
            value: .string("chicken"),
            at: CGPoint(x: 200, y: 120)
        )
        
        // Link decisions
        await viewModel.model.linkDecisions(from: decision1.id, to: decision2.id)
        
        // Set values
        _ = await viewModel.model.setNumericValue(5, for: decision1.id)
        _ = await viewModel.model.selectChoice(chickenChoice!.id, in: decision2.id)
        
        // Create meal node
        let meal = await viewModel.model.addMeal(
            name: "Taco Night",
            date: Date(),
            mealType: .dinner,
            servings: 5,
            guests: 5,
            dinnerTime: Date(),
            protein: nil,
            at: CGPoint(x: 300, y: 100)
        )
        
        // Generate preference
        let preference = await viewModel.model.generatePreference(
            from: decision1.id,
            name: "Taco Night Preferences",
            guestCount: 5,
            dinnerTime: Date(),
            mealNodeID: meal.id,
            at: CGPoint(x: 250, y: 100)
        )
        
        await viewModel.model.endBulkOperation()
        
        // Verify preference was created
        #expect(preference.name == "Taco Night Preferences")
        #expect(preference.guestCount == 5)
        #expect(preference.mealNodeID == meal.id)
        
        // Verify preferences were collected
        #expect(preference.preferences["guestCount"] == .number(5))
        #expect(preference.preferences["protein"] == .string("chicken"))
        
        // Verify configures edge exists
        let configuresEdges = viewModel.model.edges.filter {
            $0.from == preference.id && $0.target == meal.id && $0.type == .configures
        }
        #expect(configuresEdges.count == 1)
        
        // Verify decidedBy edge exists
        let decidedByEdges = viewModel.model.edges.filter {
            $0.from == preference.id && $0.target == decision1.id && $0.type == .decidedBy
        }
        #expect(decidedByEdges.count == 1)
    }
    
    @available(watchOS 10.0, *)
    @Test("Preference node can be retrieved from meal")
    func testPreferenceRetrieval() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.beginBulkOperation()
        
        // Create meal
        let meal = await viewModel.model.addMeal(
            name: "Dinner",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            guests: 4,
            dinnerTime: Date(),
            protein: nil,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Create preference linked to meal
        let preference = await viewModel.model.createPreference(
            name: "Dinner Prefs",
            guestCount: 4,
            dinnerTime: Date(),
            preferences: ["protein": .string("fish")],
            mealNodeID: meal.id,
            at: CGPoint(x: 150, y: 100)
        )
        
        await viewModel.model.endBulkOperation()
        
        // Retrieve preference from meal
        let retrievedPref = viewModel.model.preference(for: meal.id)
        
        #expect(retrievedPref != nil)
        #expect(retrievedPref?.id == preference.id)
        #expect(retrievedPref?.name == "Dinner Prefs")
    }
    
    @available(watchOS 10.0, *)
    @Test("PreferenceNode summary displays correctly")
    func testPreferenceSummary() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.beginBulkOperation()
        
        let preferences: [String: PreferenceValue] = [
            "protein": .string("beef"),
            "spiceLevel": .string("mild"),
            "toppings": .stringArray(["cheese", "lettuce", "tomato"])
        ]
        
        let preference = await viewModel.model.createPreference(
            name: "Taco Preferences",
            guestCount: 6,
            dinnerTime: Date(),
            preferences: preferences,
            at: CGPoint(x: 100, y: 100)
        )
        
        await viewModel.model.endBulkOperation()
        
        // Verify summary contains key information
        let summary = preference.summary
        let summaryLowercase = summary.lowercased()
        
        #expect(summaryLowercase.contains("guests"))
        #expect(summaryLowercase.contains("6"))
        #expect(summaryLowercase.contains("beef"))
        #expect(summaryLowercase.contains("mild"))
    }
    
    @available(watchOS 10.0, *)
    @Test("Collect decision results with multi-choice")
    func testCollectMultiChoiceResults() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.beginBulkOperation()
        
        // Create multi-choice decision
        let decision = await viewModel.model.addDecision(
            question: "What toppings?",
            preferenceKey: "toppings",
            inputType: .multiChoice,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Add multiple choices
        let cheese = await viewModel.model.addChoice(
            to: decision.id,
            choiceText: "Cheese",
            value: .string("cheese"),
            at: CGPoint(x: 100, y: 80)
        )
        
        let lettuce = await viewModel.model.addChoice(
            to: decision.id,
            choiceText: "Lettuce",
            value: .string("lettuce"),
            at: CGPoint(x: 100, y: 100)
        )
        
        let tomato = await viewModel.model.addChoice(
            to: decision.id,
            choiceText: "Tomato",
            value: .string("tomato"),
            at: CGPoint(x: 100, y: 120)
        )
        
        // Select multiple choices
        _ = await viewModel.model.selectChoice(cheese!.id, in: decision.id)
        _ = await viewModel.model.selectChoice(lettuce!.id, in: decision.id)
        _ = await viewModel.model.selectChoice(tomato!.id, in: decision.id)
        
        await viewModel.model.endBulkOperation()
        
        // Collect results
        let results = viewModel.model.collectDecisionResults(startingFrom: decision.id)
        
        #expect(results["toppings"] == .stringArray(["cheese", "lettuce", "tomato"]))
    }
}
