# Phase 2A Completion Guide: Meal Planning Core

**Current Status**: 50% Complete (MealNode done, 3 more nodes needed)
**Branch**: GraphEditorShared main (committed: e317e4b)
**Last Updated**: 2026-02-09

## ✅ What's Already Done

### Files Created
1. **MealPlanningTypes.swift** - All enums (MealType, TaskType, TaskStatus, MeasurementUnit)
2. **MealNode.swift** - Complete implementation with NodeProtocol conformance
3. **MealNodeTests.swift** - 6 tests covering initialization, codable, AnyNode wrapping
4. **MealPlanningTypesTests.swift** - 7 tests for enums

### Type Extensions
- **HomeEconNodeType** - Added 6 cases: meal, recipe, ingredient, shoppingItem, task, mealPlan
- **EdgeType** - Added 7 cases: requires, contains, purchases, assigned, participates, precedes, costs

### Build Status
- ✅ All code compiles
- ✅ No regressions (127 tests still passing in main app)
- ⚠️ New test files not yet added to Xcode project (filesystem only)

---

## 🚧 What Needs to Be Completed

### 1. RecipeNode Implementation

**Purpose**: Stores recipe information with instructions and timing

**File**: `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/RecipeNode.swift`

```swift
import SwiftUI
import Foundation

@available(iOS 16.0, watchOS 9.0, *)
public struct RecipeNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Ingredient nodes
    public var childOrder: [NodeID]

    // Recipe-specific properties
    public let name: String
    public let instructions: String
    public let prepTime: Int        // minutes
    public let cookTime: Int        // minutes
    public let servings: Int
    public let difficulty: String   // "easy", "medium", "hard"

    public var displayRadius: CGFloat {
        radius * 1.4
    }

    public var fillColor: Color {
        .cyan
    }

    public var contents: [NodeContent] {
        get {
            [
                .string(name),
                .number(Double(prepTime + cookTime))  // total time
            ]
        }
        set {
            // Read-only
        }
    }

    // MARK: - Implementation
    // Follow same pattern as MealNode:
    // - Init with all properties
    // - with() methods for immutability
    // - collapse/bulkCollapse (can collapse to hide ingredients)
    // - Codable implementation
    // - Equatable based on id + name
}
```

**Test File**: `GraphEditorShared/Tests/GraphEditorSharedTests/HomeEconomics/RecipeNodeTests.swift`

Required tests:
- Initialization with all properties
- Fill color is cyan
- Contents include name and total time
- Codable round-trip
- AnyNode wrapping/unwrapping
- with() methods preserve immutability
- Collapse/expand behavior

---

### 2. IngredientNode Implementation

**Purpose**: Represents an ingredient with quantity and unit

**File**: `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/IngredientNode.swift`

```swift
import SwiftUI
import Foundation

@available(iOS 16.0, watchOS 9.0, *)
public struct IngredientNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Always empty
    public var childOrder: [NodeID]

    // Ingredient-specific properties
    public let name: String
    public let quantity: Decimal
    public let unit: MeasurementUnit

    public var displayRadius: CGFloat {
        radius * 0.9  // Smaller for ingredients
    }

    public var fillColor: Color {
        .green
    }

    public var contents: [NodeContent] {
        get {
            [
                .string(name),
                .number(Double(truncating: quantity as NSNumber)),
                .string(unit.abbreviation)
            ]
        }
        set {
            // Read-only
        }
    }

    // Helper: Display string like "4 eggs" or "2 cups flour"
    public var displayString: String {
        let qtyStr = quantity == 1 ? "" : "\(quantity) "
        let unitStr = unit.abbreviation.isEmpty ? "" : "\(unit.abbreviation) "
        return "\(qtyStr)\(unitStr)\(name)"
    }

    // MARK: - Implementation
    // Follow MealNode pattern
    // Note: isCollapsible = false (ingredients don't collapse)
    // Note: children always empty
}
```

**Test File**: `GraphEditorShared/Tests/GraphEditorSharedTests/HomeEconomics/IngredientNodeTests.swift`

Required tests:
- Initialization
- displayString formatting ("4 eggs", "2 cups flour")
- Contents include name, quantity, unit
- Codable with Decimal serialization
- Not collapsible
- AnyNode wrapping

---

### 3. TaskNode Implementation

**Purpose**: Tracks work tasks with status and time

**File**: `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/TaskNode.swift`

```swift
import SwiftUI
import Foundation

@available(iOS 16.0, watchOS 9.0, *)
public struct TaskNode: NodeProtocol {
    public let id: NodeID
    public let label: Int
    public var position: CGPoint
    public var velocity: CGPoint
    public var radius: CGFloat
    public var isExpanded: Bool
    public var isCollapsible: Bool
    public var children: [NodeID]  // Subtasks (optional)
    public var childOrder: [NodeID]

    // Task-specific properties
    public let taskType: TaskType
    public var status: TaskStatus        // Mutable - changes as work progresses
    public let estimatedTime: Int        // minutes (estimated)
    public var actualTime: Int?          // minutes (actual, nil until completed)
    public let assignedUserID: NodeID?

    public var displayRadius: CGFloat {
        radius * 1.1
    }

    public var fillColor: Color {
        switch status {
        case .pending: return .gray
        case .inProgress: return .yellow
        case .completed: return .green
        case .skipped: return .red
        }
    }

    public var contents: [NodeContent] {
        get {
            var result: [NodeContent] = [
                .string(taskType.rawValue),
                .string(status.rawValue)
            ]
            if let actual = actualTime {
                result.append(.number(Double(actual)))
            }
            return result
        }
        set {
            // Read-only
        }
    }

    // Helper: Update status and actual time
    public func completing(timeSpent: Int) -> Self {
        var updated = self
        updated.status = .completed
        updated.actualTime = timeSpent
        return updated
    }

    public func startingWork() -> Self {
        var updated = self
        updated.status = .inProgress
        return updated
    }

    // MARK: - Implementation
    // Follow MealNode pattern
    // Note: status and actualTime are mutable (use var)
    // Note: Codable needs to handle optional actualTime
}
```

**Test File**: `GraphEditorShared/Tests/GraphEditorSharedTests/HomeEconomics/TaskNodeTests.swift`

Required tests:
- Initialization
- Fill color changes by status
- completing() updates status and actualTime
- startingWork() changes status to inProgress
- Codable with optional actualTime
- AnyNode wrapping

---

### 4. GraphModel+MealPlanning Extensions

**Purpose**: Add helper methods for meal planning operations

**File**: `GraphEditorShared/Sources/GraphEditorShared/HomeEconomics/GraphModel+MealPlanning.swift`

```swift
import Foundation
import CoreGraphics
import SwiftUI

@available(iOS 16.0, watchOS 9.0, *)
extension GraphModel {

    // MARK: - Meal Operations

    /// Adds a meal node to the graph
    @MainActor
    public func addMeal(
        name: String,
        date: Date,
        mealType: MealType,
        servings: Int,
        recipeID: NodeID? = nil,
        at position: CGPoint
    ) async -> MealNode {
        let meal = MealNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            date: date,
            mealType: mealType,
            servings: servings,
            recipeID: recipeID
        )

        nodes.append(AnyNode(meal))
        nextNodeLabel += 1

        // Auto-create edge if recipe specified
        if let recID = recipeID {
            await addEdge(from: meal.id, target: recID, type: .requires)
        }

        return meal
    }

    /// Adds a recipe node
    @MainActor
    public func addRecipe(
        name: String,
        instructions: String,
        prepTime: Int,
        cookTime: Int,
        servings: Int,
        difficulty: String = "medium",
        at position: CGPoint
    ) async -> RecipeNode {
        let recipe = RecipeNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            instructions: instructions,
            prepTime: prepTime,
            cookTime: cookTime,
            servings: servings,
            difficulty: difficulty
        )

        nodes.append(AnyNode(recipe))
        nextNodeLabel += 1
        return recipe
    }

    /// Adds an ingredient to a recipe
    @MainActor
    public func addIngredient(
        toRecipe recipeID: NodeID,
        name: String,
        quantity: Decimal,
        unit: MeasurementUnit,
        at position: CGPoint
    ) async -> IngredientNode {
        let ingredient = IngredientNode(
            label: nextNodeLabel,
            position: position,
            name: name,
            quantity: quantity,
            unit: unit
        )

        nodes.append(AnyNode(ingredient))
        nextNodeLabel += 1

        // Auto-create contains edge
        await addEdge(from: recipeID, target: ingredient.id, type: .contains)

        return ingredient
    }

    /// Adds a task node
    @MainActor
    public func addTask(
        type: TaskType,
        estimatedTime: Int,
        assignedUserID: NodeID? = nil,
        at position: CGPoint
    ) async -> TaskNode {
        let task = TaskNode(
            label: nextNodeLabel,
            position: position,
            taskType: type,
            status: .pending,
            estimatedTime: estimatedTime,
            actualTime: nil,
            assignedUserID: assignedUserID
        )

        nodes.append(AnyNode(task))
        nextNodeLabel += 1

        // Auto-create assignment edge if user specified
        if let userID = assignedUserID {
            await addEdge(from: userID, target: task.id, type: .assigned)
        }

        return task
    }

    // MARK: - Query Helpers

    /// Returns all ingredients in a recipe
    @MainActor
    public func ingredients(in recipeID: NodeID) -> [IngredientNode] {
        edges
            .filter { $0.from == recipeID && $0.type == .contains }
            .compactMap { edge in
                nodes.first(where: { $0.id == edge.target })?.unwrapped as? IngredientNode
            }
    }

    /// Returns the recipe for a meal
    @MainActor
    public func recipe(for mealID: NodeID) -> RecipeNode? {
        edges
            .filter { $0.from == mealID && $0.type == .requires }
            .compactMap { edge in
                nodes.first(where: { $0.id == edge.target })?.unwrapped as? RecipeNode
            }
            .first
    }

    /// Returns all tasks assigned to a user
    @MainActor
    public func tasks(assignedTo userID: NodeID) -> [TaskNode] {
        edges
            .filter { $0.from == userID && $0.type == .assigned }
            .compactMap { edge in
                nodes.first(where: { $0.id == edge.target })?.unwrapped as? TaskNode
            }
    }

    /// Returns tasks for a specific meal (via hierarchy edges)
    @MainActor
    public func tasks(for mealID: NodeID) -> [TaskNode] {
        edges
            .filter { $0.from == mealID && $0.type == .hierarchy }
            .compactMap { edge in
                nodes.first(where: { $0.id == edge.target })?.unwrapped as? TaskNode
            }
    }

    /// Calculates total work time for a meal
    @MainActor
    public func totalWorkTime(for mealID: NodeID) -> Int {
        tasks(for: mealID)
            .compactMap { $0.actualTime ?? $0.estimatedTime }
            .reduce(0, +)
    }

    /// Generates shopping list from multiple meals
    @MainActor
    public func generateShoppingList(for mealIDs: [NodeID]) -> [String: (Decimal, MeasurementUnit)] {
        var aggregated: [String: (Decimal, MeasurementUnit)] = [:]

        for mealID in mealIDs {
            if let recipe = recipe(for: mealID) {
                for ingredient in ingredients(in: recipe.id) {
                    if let existing = aggregated[ingredient.name] {
                        // Add quantities (assuming same unit - TODO: unit conversion)
                        aggregated[ingredient.name] = (existing.0 + ingredient.quantity, ingredient.unit)
                    } else {
                        aggregated[ingredient.name] = (ingredient.quantity, ingredient.unit)
                    }
                }
            }
        }

        return aggregated
    }
}
```

**Test File**: `GraphEditorShared/Tests/GraphEditorSharedTests/HomeEconomics/GraphModelMealPlanningTests.swift`

Required tests:
- addMeal creates node
- addMeal with recipeID creates requires edge
- addRecipe creates node
- addIngredient creates node and contains edge
- addTask creates node
- addTask with userID creates assigned edge
- ingredients(in:) returns correct nodes
- recipe(for:) finds linked recipe
- tasks(assignedTo:) filters by user
- generateShoppingList aggregates ingredients

---

## 📋 Step-by-Step Completion Checklist

### Phase 1: RecipeNode
- [ ] Create RecipeNode.swift (following MealNode pattern)
- [ ] Create RecipeNodeTests.swift (6 tests minimum)
- [ ] Build and verify compilation
- [ ] Run tests (if added to Xcode project)

### Phase 2: IngredientNode
- [ ] Create IngredientNode.swift
- [ ] Create IngredientNodeTests.swift (6 tests minimum)
- [ ] Test displayString formatting
- [ ] Build and verify compilation

### Phase 3: TaskNode
- [ ] Create TaskNode.swift
- [ ] Create TaskNodeTests.swift (7 tests minimum)
- [ ] Test status transitions (pending → inProgress → completed)
- [ ] Test completing() helper method
- [ ] Build and verify compilation

### Phase 4: GraphModel Extensions
- [ ] Create GraphModel+MealPlanning.swift
- [ ] Create GraphModelMealPlanningTests.swift (10 tests minimum)
- [ ] Test all CRUD operations
- [ ] Test query helpers
- [ ] Test shopping list generation
- [ ] Build and verify compilation

### Phase 5: Integration
- [ ] Run full test suite (should be 127 + ~30 new = ~157 tests)
- [ ] Verify no regressions
- [ ] Commit to GraphEditorShared
- [ ] Update PHASE1_SUMMARY.md with Phase 2A completion

---

## 🧪 Testing Strategy

### Unit Test Requirements
Each node type needs:
1. Initialization test
2. Fill color test
3. Contents test
4. Codable round-trip test
5. AnyNode wrapping test
6. with() methods test
7. Specific behavior test (collapse, status change, etc.)

### Integration Test Requirements
GraphModel extensions need:
1. Add operations create nodes
2. Auto-edge creation works
3. Query helpers return correct results
4. Shopping list aggregation handles quantities
5. Task filtering by user works
6. Work time calculation accurate

### Performance Considerations
- Ingredient aggregation could be slow with many meals
- Consider caching shopping list results
- Test with 50+ ingredients across 10+ meals

---

## 🎯 Example Usage After Completion

```swift
let model = GraphModel(storage: storage, physicsEngine: engine)

// Create a recipe
let carbonara = await model.addRecipe(
    name: "Spaghetti Carbonara",
    instructions: "1. Boil pasta...",
    prepTime: 10,
    cookTime: 15,
    servings: 4,
    at: CGPoint(x: 0, y: 0)
)

// Add ingredients
await model.addIngredient(
    toRecipe: carbonara.id,
    name: "Spaghetti",
    quantity: 1,
    unit: .pound,
    at: CGPoint(x: 50, y: 50)
)

await model.addIngredient(
    toRecipe: carbonara.id,
    name: "Eggs",
    quantity: 4,
    unit: .whole,
    at: CGPoint(x: 100, y: 50)
)

// Schedule a meal
let dinner = await model.addMeal(
    name: "Monday Dinner",
    date: Date(),
    mealType: .dinner,
    servings: 4,
    recipeID: carbonara.id,
    at: CGPoint(x: 200, y: 100)
)

// Create tasks
let shopTask = await model.addTask(
    type: .shop,
    estimatedTime: 30,
    assignedUserID: aliceID,
    at: CGPoint(x: 250, y: 150)
)

let cookTask = await model.addTask(
    type: .cook,
    estimatedTime: 25,
    assignedUserID: bobID,
    at: CGPoint(x: 300, y: 150)
)

// Query the graph
let ingredients = model.ingredients(in: carbonara.id)
// Returns: [spaghetti, eggs]

let shopping = model.generateShoppingList(for: [dinner.id])
// Returns: ["Spaghetti": (1.0, .pound), "Eggs": (4.0, .whole)]

let aliceTasks = model.tasks(assignedTo: aliceID)
// Returns: [shopTask]
```

---

## 📝 Notes for Implementation

### Common Patterns
- All nodes follow same structure as MealNode
- Always use `Constants.App.nodeModelRadius` for default radius
- Velocity always reset to .zero on decode
- Use `var` for mutable state (status, actualTime)
- Use `let` for immutable domain data

### Color Palette
- MealNode: orange/yellow/purple/pink (by meal type)
- RecipeNode: cyan
- IngredientNode: green
- TaskNode: gray/yellow/green/red (by status)
- CategoryNode: custom per category
- TransactionNode: green (income) / red (expense)

### Edge Auto-Creation
Always create edges when relationships are specified:
- Meal + recipeID → requires edge
- Recipe + ingredient → contains edge
- Task + userID → assigned edge
- Category + transaction → hierarchy edge

### Decimal Handling
Use same pattern as TransactionNode:
```swift
// Encode
try container.encode(quantity.description, forKey: .quantity)

// Decode
quantity = Decimal(string: try container.decode(String.self, forKey: .quantity)) ?? 0
```

---

## 🚀 Next Steps After Phase 2A

Once all 4 node types and GraphModel extensions are complete:

### Phase 2B: Task Assignment & Tracking
- UserNode implementation
- Participation tracking (who did what)
- Work contribution calculations
- Time logging UI

### Phase 2C: Shopping List Generation
- ShoppingItemNode implementation
- Ingredient aggregation across meals
- Store location mapping
- Check-off workflow

### Phase 2D: Watch UI
- Weekly meal schedule view
- Task list with completion
- Shopping list interface
- Participation dashboard

### Phase 2E: Kafka Integration
- Event streaming for task updates
- Real-time sync across devices
- Audit trail for all changes

---

**Status**: Ready for implementation
**Estimated Time**: 3-4 hours for remaining nodes + tests
**Blockers**: None - all dependencies in place
