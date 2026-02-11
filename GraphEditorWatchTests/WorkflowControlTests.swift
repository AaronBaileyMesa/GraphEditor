//
//  WorkflowControlTests.swift
//  GraphEditorWatchTests
//
//  Tests for workflow-specific control node generation

import Testing
import CoreGraphics
import GraphEditorShared
@testable import GraphEditorWatch

@Suite("Workflow Control Node Tests")
struct WorkflowControlTests {
    
    // MARK: - Test Fixtures
    
    @MainActor
    func createTestViewModel() -> GraphViewModel {
        let bounds = CGSize(width: 400, height: 400)
        let physicsEngine = PhysicsEngine(simulationBounds: bounds)
        let storage = MockGraphStorage()
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    // MARK: - MealNode Control Tests
    
    @Test("MealNode shows construction controls when workflow is inactive")
    @MainActor
    func testMealNodeConstructionControls() async throws {
        let viewModel = createTestViewModel()
        
        // Add a MealNode
        let meal = await viewModel.model.addMeal(
            name: "Dinner",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Generate controls (workflow not started)
        await viewModel.generateControls(for: meal.id)
        
        let controlKinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        
        // Should show construction controls
        #expect(controlKinds.contains(.startWorkflow), "Should show startWorkflow control")
        #expect(controlKinds.contains(.addShopTask), "Should show addShopTask control")
        #expect(controlKinds.contains(.addPrepTask), "Should show addPrepTask control")
        #expect(controlKinds.contains(.addCookTask), "Should show addCookTask control")
        #expect(controlKinds.contains(.addRecipe), "Should show addRecipe control")
        #expect(controlKinds.contains(.edit), "Should show edit control")
        #expect(controlKinds.contains(.delete), "Should show delete control")
        
        // Should NOT show execution controls
        #expect(!controlKinds.contains(.stopWorkflow), "Should not show stopWorkflow")
        #expect(!controlKinds.contains(.completeTask), "Should not show completeTask")
    }
    
    @Test("MealNode shows execution controls when workflow is active")
    @MainActor
    func testMealNodeExecutionControls() async throws {
        let viewModel = createTestViewModel()
        
        // Add a MealNode with tasks
        let meal = await viewModel.model.addMeal(
            name: "Dinner",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Add a task to the meal
        await viewModel.model.addTaskToMeal(mealID: meal.id, taskType: .shop)
        
        // Start workflow
        viewModel.model.startWorkflow(for: meal.id)
        
        // Generate controls (workflow active)
        await viewModel.generateControls(for: meal.id)
        
        let controlKinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        
        // Should show execution controls
        #expect(controlKinds.contains(.stopWorkflow), "Should show stopWorkflow control")
        #expect(controlKinds.contains(.completeTask), "Should show completeTask control")
        #expect(controlKinds.contains(.edit), "Should show edit control")
        #expect(controlKinds.contains(.delete), "Should show delete control")
        
        // Should NOT show construction controls
        #expect(!controlKinds.contains(.startWorkflow), "Should not show startWorkflow")
        #expect(!controlKinds.contains(.addShopTask), "Should not show addShopTask")
        #expect(!controlKinds.contains(.addPrepTask), "Should not show addPrepTask")
    }
    
    // MARK: - TaskNode Control Tests
    
    @Test("TaskNode shows pending status controls")
    @MainActor
    func testTaskNodePendingControls() async throws {
        let viewModel = createTestViewModel()
        
        // Add a TaskNode with pending status
        let task = await viewModel.model.addTask(
            type: .shop,
            estimatedTime: 30,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Generate controls
        await viewModel.generateControls(for: task.id)
        
        let controlKinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        
        // Should show pending status controls
        #expect(controlKinds.contains(.startTask), "Should show startTask control")
        #expect(controlKinds.contains(.blockTask), "Should show blockTask control")
        #expect(controlKinds.contains(.declineTask), "Should show declineTask control")
        #expect(controlKinds.contains(.edit), "Should show edit control")
        #expect(controlKinds.contains(.delete), "Should show delete control")
        
        // Should NOT show other status controls
        #expect(!controlKinds.contains(.completeTask), "Should not show completeTask")
        #expect(!controlKinds.contains(.unblockTask), "Should not show unblockTask")
        #expect(!controlKinds.contains(.resetTask), "Should not show resetTask")
    }
    
    @Test("TaskNode shows in-progress status controls")
    @MainActor
    func testTaskNodeInProgressControls() async throws {
        let viewModel = createTestViewModel()
        
        // Add a TaskNode and set to in-progress
        let task = await viewModel.model.addTask(
            type: .prep,
            estimatedTime: 20,
            at: CGPoint(x: 100, y: 100)
        )
        viewModel.model.updateTaskStatus(task.id, to: .inProgress)
        
        // Generate controls
        await viewModel.generateControls(for: task.id)
        
        let controlKinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        
        // Should show in-progress status controls
        #expect(controlKinds.contains(.completeTask), "Should show completeTask control")
        #expect(controlKinds.contains(.blockTask), "Should show blockTask control")
        #expect(controlKinds.contains(.edit), "Should show edit control")
        
        // Should NOT show other status controls
        #expect(!controlKinds.contains(.startTask), "Should not show startTask")
        #expect(!controlKinds.contains(.declineTask), "Should not show declineTask")
        #expect(!controlKinds.contains(.delete), "Should not show delete (task in progress)")
    }
    
    @Test("TaskNode shows blocked status controls")
    @MainActor
    func testTaskNodeBlockedControls() async throws {
        let viewModel = createTestViewModel()
        
        // Add a TaskNode and set to blocked
        let task = await viewModel.model.addTask(
            type: .cook,
            estimatedTime: 45,
            at: CGPoint(x: 100, y: 100)
        )
        viewModel.model.updateTaskStatus(task.id, to: .blocked)
        
        // Generate controls
        await viewModel.generateControls(for: task.id)
        
        let controlKinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        
        // Should show blocked status controls
        #expect(controlKinds.contains(.unblockTask), "Should show unblockTask control")
        #expect(controlKinds.contains(.declineTask), "Should show declineTask control")
        #expect(controlKinds.contains(.edit), "Should show edit control")
        #expect(controlKinds.contains(.delete), "Should show delete control")
        
        // Should NOT show other status controls
        #expect(!controlKinds.contains(.startTask), "Should not show startTask")
        #expect(!controlKinds.contains(.completeTask), "Should not show completeTask")
    }
    
    @Test("TaskNode shows completed status controls")
    @MainActor
    func testTaskNodeCompletedControls() async throws {
        let viewModel = createTestViewModel()
        
        // Add a TaskNode and set to completed
        let task = await viewModel.model.addTask(
            type: .serve,
            estimatedTime: 10,
            at: CGPoint(x: 100, y: 100)
        )
        viewModel.model.updateTaskStatus(task.id, to: .completed)
        
        // Generate controls
        await viewModel.generateControls(for: task.id)
        
        let controlKinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        
        // Should show completed status controls
        #expect(controlKinds.contains(.resetTask), "Should show resetTask control")
        #expect(controlKinds.contains(.edit), "Should show edit control")
        #expect(controlKinds.contains(.delete), "Should show delete control")
        
        // Should NOT show other status controls
        #expect(!controlKinds.contains(.startTask), "Should not show startTask")
        #expect(!controlKinds.contains(.completeTask), "Should not show completeTask")
        #expect(!controlKinds.contains(.blockTask), "Should not show blockTask")
    }
    
    // MARK: - RecipeNode Control Tests
    
    @Test("RecipeNode shows scale and generic controls")
    @MainActor
    func testRecipeNodeControls() async throws {
        let viewModel = createTestViewModel()
        
        // Add a RecipeNode
        let recipe = await viewModel.model.addRecipe(
            name: "Tacos",
            instructions: "Cook meat, prepare toppings, serve",
            prepTime: 10,
            cookTime: 20,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Generate controls
        await viewModel.generateControls(for: recipe.id)
        
        let controlKinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        
        // Should show recipe-specific controls
        #expect(controlKinds.contains(.scaleRecipe), "Should show scaleRecipe control")
        #expect(controlKinds.contains(.edit), "Should show edit control")
        #expect(controlKinds.contains(.addChild), "Should show addChild control for ingredients")
        #expect(controlKinds.contains(.delete), "Should show delete control")
    }
    
    // MARK: - Control Action Tests
    
    @Test("Start workflow action marks first task as in-progress")
    @MainActor
    func testStartWorkflowAction() async throws {
        let viewModel = createTestViewModel()
        
        // Set viewport size for centering
        viewModel.viewSize = CGSize(width: 205, height: 251)
        
        // Create meal with task
        let meal = await viewModel.model.addMeal(
            name: "Lunch",
            date: Date(),
            mealType: .lunch,
            servings: 2,
            at: CGPoint(x: 100, y: 100)
        )
        await viewModel.model.addTaskToMeal(mealID: meal.id, taskType: .shop)
        
        // Get the startWorkflow action
        let action = ControlKind.startWorkflow.defaultAction()
        
        let initialOffset = viewModel.offset
        
        // Execute action
        await action(viewModel, meal.id)
        
        // Verify workflow started
        #expect(viewModel.model.isWorkflowActive(for: meal.id), "Workflow should be active")
        
        // Verify first task is in-progress
        let currentTask = viewModel.model.currentTask(for: meal.id)
        #expect(currentTask?.status == .inProgress, "First task should be in-progress")
        
        // Verify first task is auto-selected
        #expect(viewModel.selectedNodeID == currentTask?.id, "First task should be auto-selected")
        
        // Verify viewport was adjusted to center the first task
        #expect(viewModel.offset != initialOffset, "Offset should change to center first task")
    }
    
    @Test("Complete task action advances to next task")
    @MainActor
    func testCompleteTaskAction() async throws {
        let viewModel = createTestViewModel()
        
        // Create meal with two tasks
        let meal = await viewModel.model.addMeal(
            name: "Dinner",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )
        await viewModel.model.addTaskToMeal(mealID: meal.id, taskType: .shop)
        await viewModel.model.addTaskToMeal(mealID: meal.id, taskType: .prep)
        
        // Start workflow
        viewModel.model.startWorkflow(for: meal.id)
        
        // Get first task
        let firstTask = viewModel.model.currentTask(for: meal.id)
        #expect(firstTask?.taskType == .shop, "First task should be shop")
        
        // Execute complete task action with the TASK id (not meal id)
        // This simulates tapping the completeTask control on the task node
        let action = ControlKind.completeTask.defaultAction()
        await action(viewModel, firstTask!.id)
        
        // Verify first task completed and second task started
        let secondTask = viewModel.model.currentTask(for: meal.id)
        #expect(secondTask?.taskType == .prep, "Second task should now be in-progress")
        #expect(secondTask?.status == .inProgress, "Second task should be in-progress")
    }
    
    @Test("Start task action updates task status")
    @MainActor
    func testStartTaskAction() async throws {
        let viewModel = createTestViewModel()
        
        // Create a pending task
        let task = await viewModel.model.addTask(
            type: .cook,
            estimatedTime: 30,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Execute start task action
        let action = ControlKind.startTask.defaultAction()
        await action(viewModel, task.id)
        
        // Verify task is now in-progress
        if let updatedTask = viewModel.model.nodes.first(where: { $0.id == task.id })?.unwrapped as? TaskNode {
            #expect(updatedTask.status == .inProgress, "Task should be in-progress after start action")
            #expect(updatedTask.startedAt != nil, "Task should have startedAt timestamp")
        } else {
            Issue.record("Failed to find updated task")
        }
    }
    
    @Test("Block task action updates task status")
    @MainActor
    func testBlockTaskAction() async throws {
        let viewModel = createTestViewModel()
        
        // Create a pending task
        let task = await viewModel.model.addTask(
            type: .shop,
            estimatedTime: 20,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Execute block task action
        let action = ControlKind.blockTask.defaultAction()
        await action(viewModel, task.id)
        
        // Verify task is now blocked
        if let updatedTask = viewModel.model.nodes.first(where: { $0.id == task.id })?.unwrapped as? TaskNode {
            #expect(updatedTask.status == .blocked, "Task should be blocked after block action")
        } else {
            Issue.record("Failed to find updated task")
        }
    }
    
    @Test("Add shop task action creates task and links to meal")
    @MainActor
    func testAddShopTaskAction() async throws {
        let viewModel = createTestViewModel()
        
        // Create meal
        let meal = await viewModel.model.addMeal(
            name: "Breakfast",
            date: Date(),
            mealType: .breakfast,
            servings: 2,
            at: CGPoint(x: 100, y: 100)
        )
        
        let initialTaskCount = viewModel.model.tasks(for: meal.id).count
        
        // Execute add shop task action
        let action = ControlKind.addShopTask.defaultAction()
        await action(viewModel, meal.id)
        
        // Verify task was created
        let tasks = viewModel.model.tasks(for: meal.id)
        #expect(tasks.count == initialTaskCount + 1, "Should have added one task")
        
        // Verify it's a shop task
        let shopTasks = tasks.filter { $0.taskType == .shop }
        #expect(shopTasks.count == 1, "Should have created a shop task")
    }
    
    // MARK: - Integration Tests
    
    @Test("Workflow controls update when workflow state changes")
    @MainActor
    func testWorkflowControlsUpdateWithState() async throws {
        let viewModel = createTestViewModel()
        
        // Create meal with task
        let meal = await viewModel.model.addMeal(
            name: "Snack",
            date: Date(),
            mealType: .snack,
            servings: 1,
            at: CGPoint(x: 100, y: 100)
        )
        await viewModel.model.addTaskToMeal(mealID: meal.id, taskType: .prep)
        
        // Generate controls - should show construction controls
        await viewModel.generateControls(for: meal.id)
        var controlKinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        #expect(controlKinds.contains(.startWorkflow), "Should initially show startWorkflow")
        
        // Start workflow
        viewModel.model.startWorkflow(for: meal.id)
        
        // Regenerate controls - should show execution controls
        await viewModel.generateControls(for: meal.id)
        controlKinds = Set(viewModel.model.ephemeralControlNodes.map { $0.kind })
        #expect(controlKinds.contains(.stopWorkflow), "Should show stopWorkflow after starting")
        #expect(controlKinds.contains(.completeTask), "Should show completeTask after starting")
        #expect(!controlKinds.contains(.startWorkflow), "Should not show startWorkflow anymore")
    }
    
    // MARK: - Helper Function Tests
    
    @Test("findMealForTask returns correct meal node")
    @MainActor
    func testFindMealForTask() async throws {
        let viewModel = createTestViewModel()
        
        // Create meal with task
        let meal = await viewModel.model.addMeal(
            name: "Breakfast",
            date: Date(),
            mealType: .breakfast,
            servings: 2,
            at: CGPoint(x: 100, y: 100)
        )
        await viewModel.model.addTaskToMeal(mealID: meal.id, taskType: .shop)
        
        // Get the task
        let task = viewModel.model.orderedTasks(for: meal.id).first
        #expect(task != nil, "Task should exist")
        
        // Test findMealForTask
        let foundMealID = viewModel.model.findMealForTask(task!.id)
        #expect(foundMealID == meal.id, "Should find the correct meal node")
    }
    
    @Test("Auto-center node adjusts viewport offset correctly")
    @MainActor
    func testAutoCenterNode() async throws {
        let viewModel = createTestViewModel()
        
        // Set viewport size
        viewModel.viewSize = CGSize(width: 205, height: 251)
        
        // Add a node at a specific position
        let node = await viewModel.model.addNode(at: CGPoint(x: 200, y: 150))
        
        // Center the node
        viewModel.centerNode(node.id, viewSize: viewModel.viewSize)
        
        // Calculate expected offset
        // The node should be centered on screen
        // Formula: offset = -(nodePos - centroid) * zoom
        let centroid = viewModel.effectiveCentroid
        let relativePos = CGPoint(x: 200 - centroid.x, y: 150 - centroid.y)
        let scaledPos = CGPoint(x: relativePos.x * viewModel.zoomScale, y: relativePos.y * viewModel.zoomScale)
        let expectedOffset = CGSize(width: -scaledPos.x, height: -scaledPos.y)
        
        // Verify offset is correct (with small tolerance for floating point)
        let tolerance: CGFloat = 0.1
        #expect(abs(viewModel.offset.width - expectedOffset.width) < tolerance, 
                "Offset width should match expected value")
        #expect(abs(viewModel.offset.height - expectedOffset.height) < tolerance,
                "Offset height should match expected value")
    }
    
    @Test("Complete task control with task ID completes workflow correctly")
    @MainActor
    func testCompleteTaskControlWithTaskID() async throws {
        let viewModel = createTestViewModel()
        
        // Set viewport size for centering
        viewModel.viewSize = CGSize(width: 205, height: 251)
        
        // Create meal with three tasks
        let meal = await viewModel.model.addMeal(
            name: "Dinner",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )
        await viewModel.model.addTaskToMeal(mealID: meal.id, taskType: .shop)
        await viewModel.model.addTaskToMeal(mealID: meal.id, taskType: .prep)
        await viewModel.model.addTaskToMeal(mealID: meal.id, taskType: .cook)
        
        // Start workflow
        viewModel.model.startWorkflow(for: meal.id)
        
        // Get the first task (shop)
        let shopTask = viewModel.model.currentTask(for: meal.id)
        #expect(shopTask?.taskType == .shop, "First task should be shop")
        
        let initialOffset = viewModel.offset
        
        // Execute complete task action using the TASK ID (this is what happens when user taps control)
        let completeAction = ControlKind.completeTask.defaultAction()
        await completeAction(viewModel, shopTask!.id)
        
        // Verify it advanced to prep task
        let prepTask = viewModel.model.currentTask(for: meal.id)
        #expect(prepTask?.taskType == .prep, "Should advance to prep task")
        #expect(prepTask?.status == .inProgress, "Prep task should be in-progress")
        
        // Verify auto-selection of next task
        #expect(viewModel.selectedNodeID == prepTask?.id, "Should auto-select the next task")
        
        // Verify viewport was adjusted (offset changed to center the new node)
        #expect(viewModel.offset != initialOffset, "Offset should change to center next task")
        
        // Complete prep task using task ID
        await completeAction(viewModel, prepTask!.id)
        
        // Verify it advanced to cook task
        let cookTask = viewModel.model.currentTask(for: meal.id)
        #expect(cookTask?.taskType == .cook, "Should advance to cook task")
        #expect(cookTask?.status == .inProgress, "Cook task should be in-progress")
        
        // Verify auto-selection of next task
        #expect(viewModel.selectedNodeID == cookTask?.id, "Should auto-select the cook task")
        
        // Complete final task
        await completeAction(viewModel, cookTask!.id)
        
        // Verify workflow is complete
        #expect(viewModel.model.isWorkflowComplete(for: meal.id), "Workflow should be complete")
        #expect(viewModel.model.currentTask(for: meal.id) == nil, "No current task after completion")
        
        // Verify auto-selection of meal node after workflow completion
        #expect(viewModel.selectedNodeID == meal.id, "Should auto-select meal node when workflow complete")
    }
}
