//
//  RecipeCloningTests.swift
//  GraphEditorWatchTests
//
//  Tests for recipe cloning and scaling functionality
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
import GraphEditorShared

@MainActor @Suite("Recipe Cloning Tests")
struct RecipeCloningTests {
    
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
    @Test("Clone recipe creates new recipe node")
    func testCloneRecipeCreatesNode() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.beginBulkOperation()
        
        // Create base recipe
        let baseRecipe = await viewModel.model.addRecipe(
            name: "Tacos",
            instructions: "Cook tacos",
            prepTime: 15,
            cookTime: 20,
            servings: 2,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Clone for 5 guests
        let clonedRecipe = await viewModel.model.cloneRecipe(
            from: baseRecipe.id,
            scaledFor: 5,
            at: CGPoint(x: 200, y: 100)
        )
        
        await viewModel.model.endBulkOperation()
        
        // Verify cloned recipe was created
        #expect(clonedRecipe != nil)
        #expect(clonedRecipe?.name == "Tacos for 5")
        #expect(clonedRecipe?.servings == 5)
        #expect(clonedRecipe?.instructions == "Cook tacos")
        #expect(clonedRecipe?.prepTime == 15)
        #expect(clonedRecipe?.cookTime == 20)
    }
    
    @available(watchOS 10.0, *)
    @Test("Clone recipe scales ingredient quantities")
    func testCloneRecipeScalesIngredients() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.beginBulkOperation()
        
        // Create base recipe with ingredients
        let baseRecipe = await viewModel.model.addRecipe(
            name: "Tacos",
            instructions: "Cook tacos",
            prepTime: 15,
            cookTime: 20,
            servings: 2,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Add ingredients (for 2 servings)
        _ = await viewModel.model.addIngredient(
            toRecipe: baseRecipe.id,
            name: "ground beef",
            quantity: 1.0, // 1 lb for 2 people
            unit: .pound,
            at: CGPoint(x: 100, y: 80)
        )
        
        _ = await viewModel.model.addIngredient(
            toRecipe: baseRecipe.id,
            name: "tortillas",
            quantity: 4, // 4 tortillas for 2 people
            unit: .whole,
            at: CGPoint(x: 100, y: 120)
        )
        
        // Clone for 5 guests
        let clonedRecipe = await viewModel.model.cloneRecipe(
            from: baseRecipe.id,
            scaledFor: 5,
            at: CGPoint(x: 200, y: 100)
        )
        
        await viewModel.model.endBulkOperation()
        
        // Get cloned ingredients
        guard let cloned = clonedRecipe else {
            #expect(Bool(false), "Cloned recipe should not be nil")
            return
        }
        
        let clonedIngredients = viewModel.model.ingredients(in: cloned.id)
        
        // Verify we have same number of ingredients
        #expect(clonedIngredients.count == 2)
        
        // Verify scaling (5 servings / 2 servings = 2.5x)
        let beef = clonedIngredients.first(where: { $0.name == "ground beef" })
        let tortillas = clonedIngredients.first(where: { $0.name == "tortillas" })
        
        #expect(beef?.quantity == 2.5) // 1.0 * 2.5
        #expect(beef?.unit == .pound)
        
        #expect(tortillas?.quantity == 10) // 4 * 2.5
        #expect(tortillas?.unit == .whole)
    }
    
    @available(watchOS 10.0, *)
    @Test("Clone recipe creates clonedFrom edge")
    func testCloneRecipeCreatesEdge() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.beginBulkOperation()
        
        // Create base recipe
        let baseRecipe = await viewModel.model.addRecipe(
            name: "Tacos",
            instructions: "Cook tacos",
            prepTime: 15,
            cookTime: 20,
            servings: 2,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Clone recipe
        let clonedRecipe = await viewModel.model.cloneRecipe(
            from: baseRecipe.id,
            scaledFor: 5,
            at: CGPoint(x: 200, y: 100)
        )
        
        await viewModel.model.endBulkOperation()
        
        guard let cloned = clonedRecipe else {
            #expect(Bool(false), "Cloned recipe should not be nil")
            return
        }
        
        // Verify clonedFrom edge exists
        let clonedFromEdges = viewModel.model.edges.filter {
            $0.from == cloned.id && $0.target == baseRecipe.id && $0.type == .clonedFrom
        }
        
        #expect(clonedFromEdges.count == 1)
    }
    
    @available(watchOS 10.0, *)
    @Test("Update preference with cloned recipe ID")
    func testUpdatePreferenceWithClonedRecipe() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.beginBulkOperation()
        
        // Create preference
        let preference = await viewModel.model.createPreference(
            name: "Taco Prefs",
            guestCount: 5,
            dinnerTime: Date(),
            preferences: ["protein": .string("beef")],
            at: CGPoint(x: 100, y: 100)
        )
        
        // Create base recipe
        let baseRecipe = await viewModel.model.addRecipe(
            name: "Tacos",
            instructions: "Cook tacos",
            prepTime: 15,
            cookTime: 20,
            servings: 2,
            at: CGPoint(x: 200, y: 100)
        )
        
        // Clone recipe
        let clonedRecipe = await viewModel.model.cloneRecipe(
            from: baseRecipe.id,
            scaledFor: 5,
            at: CGPoint(x: 300, y: 100)
        )
        
        guard let cloned = clonedRecipe else {
            #expect(Bool(false), "Cloned recipe should not be nil")
            return
        }
        
        // Update preference with cloned recipe ID
        let success = viewModel.model.updatePreferenceWithClonedRecipe(
            preferenceID: preference.id,
            clonedRecipeID: cloned.id
        )
        
        await viewModel.model.endBulkOperation()
        
        #expect(success == true)
        
        // Verify preference was updated
        let updatedPref = viewModel.model.nodes
            .first(where: { $0.id == preference.id })?
            .unwrapped as? PreferenceNode
        
        #expect(updatedPref?.clonedRecipeID == cloned.id)
    }
    
    @available(watchOS 10.0, *)
    @Test("End-to-end: Decision tree to cloned recipe")
    func testEndToEndDecisionTreeToClonedRecipe() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.beginBulkOperation()
        
        // Create base recipe with ingredients
        let baseRecipe = await viewModel.model.addRecipe(
            name: "Tacos",
            instructions: "Cook delicious tacos",
            prepTime: 15,
            cookTime: 20,
            servings: 2,
            at: CGPoint(x: 100, y: 100)
        )
        
        _ = await viewModel.model.addIngredient(
            toRecipe: baseRecipe.id,
            name: "ground beef",
            quantity: 1.0,
            unit: .pound,
            at: CGPoint(x: 100, y: 80)
        )
        
        // Create meal node
        let meal = await viewModel.model.addMeal(
            name: "Taco Night",
            date: Date(),
            mealType: .dinner,
            servings: 5,
            guests: 5,
            dinnerTime: Date(),
            protein: nil,
            at: CGPoint(x: 200, y: 100)
        )
        
        // Create decision tree
        let decision = await viewModel.model.addDecision(
            question: "How many guests?",
            preferenceKey: "guestCount",
            inputType: .numeric,
            at: CGPoint(x: 300, y: 100)
        )
        
        _ = await viewModel.model.setNumericValue(5, for: decision.id)
        
        // Generate preference from decision tree
        let preference = await viewModel.model.generatePreference(
            from: decision.id,
            name: "Taco Preferences",
            guestCount: 5,
            dinnerTime: Date(),
            mealNodeID: meal.id,
            baseRecipeID: baseRecipe.id,
            at: CGPoint(x: 400, y: 100)
        )
        
        // Clone recipe based on preference
        let clonedRecipe = await viewModel.model.cloneRecipe(
            from: baseRecipe.id,
            scaledFor: preference.guestCount,
            at: CGPoint(x: 500, y: 100)
        )
        
        guard let cloned = clonedRecipe else {
            #expect(Bool(false), "Cloned recipe should not be nil")
            return
        }
        
        // Update preference with cloned recipe
        _ = viewModel.model.updatePreferenceWithClonedRecipe(
            preferenceID: preference.id,
            clonedRecipeID: cloned.id
        )
        
        // Link cloned recipe to meal
        await viewModel.model.addEdge(from: meal.id, target: cloned.id, type: .requires)
        
        await viewModel.model.endBulkOperation()
        
        // Verify the complete flow
        #expect(cloned.name == "Tacos for 5")
        #expect(cloned.servings == 5)
        
        // Verify ingredients are scaled
        let clonedIngredients = viewModel.model.ingredients(in: cloned.id)
        #expect(clonedIngredients.count == 1)
        #expect(clonedIngredients.first?.quantity == 2.5) // 1.0 * 2.5
        
        // Verify preference has cloned recipe ID
        let updatedPref = viewModel.model.nodes
            .first(where: { $0.id == preference.id })?
            .unwrapped as? PreferenceNode
        #expect(updatedPref?.clonedRecipeID == cloned.id)
        
        // Verify meal is linked to cloned recipe
        let mealRecipe = viewModel.model.recipe(for: meal.id)
        #expect(mealRecipe?.id == cloned.id)
    }
    
    @available(watchOS 10.0, *)
    @Test("Clone recipe with decimal scaling")
    func testCloneRecipeDecimalScaling() async {
        let viewModel = createTestViewModel()
        
        await viewModel.model.beginBulkOperation()
        
        // Create base recipe for 4 servings
        let baseRecipe = await viewModel.model.addRecipe(
            name: "Pizza",
            instructions: "Make pizza",
            prepTime: 30,
            cookTime: 15,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Add ingredient
        _ = await viewModel.model.addIngredient(
            toRecipe: baseRecipe.id,
            name: "flour",
            quantity: 2.0, // 2 cups for 4 servings
            unit: .cup,
            at: CGPoint(x: 100, y: 80)
        )
        
        // Clone for 3 servings (3/4 = 0.75x)
        let clonedRecipe = await viewModel.model.cloneRecipe(
            from: baseRecipe.id,
            scaledFor: 3,
            at: CGPoint(x: 200, y: 100)
        )
        
        await viewModel.model.endBulkOperation()
        
        guard let cloned = clonedRecipe else {
            #expect(Bool(false), "Cloned recipe should not be nil")
            return
        }
        
        // Verify scaling
        let clonedIngredients = viewModel.model.ingredients(in: cloned.id)
        let flour = clonedIngredients.first(where: { $0.name == "flour" })
        
        #expect(flour?.quantity == 1.5) // 2.0 * 0.75
    }
}
