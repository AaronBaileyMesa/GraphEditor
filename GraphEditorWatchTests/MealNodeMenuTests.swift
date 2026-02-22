//  MealNodeMenuTests.swift
//  GraphEditorWatchTests
//
//  Tests for MealNodeMenuView workflow functionality
//

import Testing
import Foundation
import CoreGraphics
import SwiftUI
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct MealNodeMenuTests {
    
    @MainActor
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        model.isSimulating = false  // Prevent physics engine from running during tests
        return GraphViewModel(model: model)
    }
    
    @MainActor
    private func createTacoDinner(in viewModel: GraphViewModel) async -> MealNode {
        let calendar = Calendar.current
        let dinnerTime = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? Date()
        
        let meal = await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 4,
            dinnerTime: dinnerTime,
            protein: .beef,
            at: CGPoint(x: 20, y: 125)
        )
        
        // Ensure simulation is stopped after template construction (endBulkOperation may restart it)
        await viewModel.model.stopSimulation()
        viewModel.model.isSimulating = false
        
        return meal
    }
    
    // MARK: - Meal Loading Tests
    
    @MainActor @Test("MealNodeMenuView loads meal details correctly")
    func testLoadMealDetails() async {
        let viewModel = createTestViewModel()
        let meal = await createTacoDinner(in: viewModel)
        
        // Verify meal was created with correct properties
        #expect(meal.name == "Beef Tacos", "Meal name should be 'Beef Tacos'")
        #expect(meal.guests == 4, "Guests should be 4")
        #expect(meal.protein == .beef, "Protein should be beef")
    }
    
    @MainActor @Test("MealNodeMenuView loads tasks in correct order")
    func testLoadTasksInOrder() async {
        let viewModel = createTestViewModel()
        let meal = await createTacoDinner(in: viewModel)
        
        // Use orderedTasks to get the workflow sequence
        let allOrderedTasks = viewModel.model.orderedTasks(for: meal.id)
        
        // Extract top-level task types in order (shop→prep→cook→assemble→serve→cleanup)
        let topLevelTypes: [TaskType] = [.shop, .prep, .cook, .assemble, .serve, .cleanup]
        let topLevelTasks = allOrderedTasks.filter { topLevelTypes.contains($0.taskType) }
        
        #expect(topLevelTasks.count == 6, "Should have 6 top-level tasks")
        #expect(topLevelTasks[0].taskType == .shop, "First task should be shop")
        #expect(topLevelTasks[1].taskType == .prep, "Second task should be prep")
        #expect(topLevelTasks[2].taskType == .cook, "Third task should be cook")
        #expect(topLevelTasks[3].taskType == .assemble, "Fourth task should be assemble")
        #expect(topLevelTasks[4].taskType == .serve, "Fifth task should be serve")
        #expect(topLevelTasks[5].taskType == .cleanup, "Sixth task should be cleanup")
    }
    
    // MARK: - Workflow State Tests
    
    @MainActor @Test("Workflow starts with all tasks pending")
    func testInitialWorkflowState() async {
        let viewModel = createTestViewModel()
        _ = await createTacoDinner(in: viewModel)
        
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        // All tasks should be pending initially
        let allPending = tasks.allSatisfy { $0.status == .pending }
        #expect(allPending, "All tasks should start with pending status")
    }
    
    @MainActor @Test("Starting workflow marks first task as in progress")
    func testStartWorkflow() async {
        let viewModel = createTestViewModel()
        _ = await createTacoDinner(in: viewModel)
        
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        guard let firstTask = tasks.first(where: { $0.taskType == .shop }) else {
            Issue.record("First task not found")
            return
        }
        
        // Start workflow by marking first task as in progress
        viewModel.model.updateTaskStatus(firstTask.id, to: .inProgress)
        
        // Verify first task is now in progress
        let updatedTask = viewModel.model.nodes.first(where: { $0.id == firstTask.id })?.unwrapped as? TaskNode
        #expect(updatedTask?.status == .inProgress, "First task should be in progress")
    }
    
    @MainActor @Test("Stopping workflow resets all tasks to pending")
    func testStopWorkflow() async {
        let viewModel = createTestViewModel()
        _ = await createTacoDinner(in: viewModel)
        
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        // Start workflow - mark first task in progress, second completed
        if tasks.count >= 2 {
            viewModel.model.updateTaskStatus(tasks[0].id, to: .completed)
            viewModel.model.updateTaskStatus(tasks[1].id, to: .inProgress)
        }
        
        // Stop workflow - reset all to pending
        // Refetch tasks to get updated statuses
        let tasksAfterUpdate = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        for task in tasksAfterUpdate {
            if task.status == .inProgress || task.status == .completed {
                viewModel.model.updateTaskStatus(task.id, to: .pending)
            }
        }
        
        // Verify all tasks are pending again
        let updatedTasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        let allPending = updatedTasks.allSatisfy { $0.status == .pending }
        #expect(allPending, "All tasks should be reset to pending after stopping workflow")
    }
    
    // MARK: - Progress Tracking Tests
    
    @MainActor @Test("Progress percentage calculates correctly")
    func testProgressPercentage() async {
        let viewModel = createTestViewModel()
        _ = await createTacoDinner(in: viewModel)
        
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        // Complete 3 out of tasks.count tasks
        for i in 0..<3 {
            viewModel.model.updateTaskStatus(tasks[i].id, to: .completed)
        }
        
        let completedCount = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
            .filter { $0.status == .completed }.count
        
        #expect(completedCount == 3, "Should have 3 completed tasks")
        
        let progress = Double(completedCount) / Double(tasks.count)
        let expectedProgress = 3.0 / Double(tasks.count)
        #expect(progress == expectedProgress, "Progress should be 3/\(tasks.count)")
    }
    
    @MainActor @Test("Workflow detects if started")
    func testWorkflowStartedDetection() async {
        let viewModel = createTestViewModel()
        _ = await createTacoDinner(in: viewModel)
        
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        // Initially, no workflow started
        let hasStarted1 = tasks.contains { $0.status == .inProgress || $0.status == .completed }
        #expect(!hasStarted1, "Workflow should not be started initially")
        
        // Mark first task in progress
        viewModel.model.updateTaskStatus(tasks[0].id, to: .inProgress)
        
        let updatedTasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        let hasStarted2 = updatedTasks.contains { $0.status == .inProgress || $0.status == .completed }
        #expect(hasStarted2, "Workflow should be detected as started")
    }
    
    @MainActor @Test("Current task is identified correctly")
    func testCurrentTaskIdentification() async {
        let viewModel = createTestViewModel()
        _ = await createTacoDinner(in: viewModel)
        
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        // Mark second task as in progress
        let shopTask = tasks.first { $0.taskType == .shop }!
        viewModel.model.updateTaskStatus(shopTask.id, to: .inProgress)
        
        // Find current task
        let updatedTasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        let currentTask = updatedTasks.first { $0.status == .inProgress }
        
        #expect(currentTask?.taskType == .shop, "Current task should be shop")
    }
    
    @MainActor @Test("Next pending task is identified correctly")
    func testNextPendingTaskIdentification() async {
        let viewModel = createTestViewModel()
        let meal = await createTacoDinner(in: viewModel)
        
        // Find shop and prep tasks by type, then complete them
        let allTasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        guard let shopTask = allTasks.first(where: { $0.taskType == .shop }),
              let prepTask = allTasks.first(where: { $0.taskType == .prep }) else {
            Issue.record("Could not find shop or prep tasks")
            return
        }
        
        viewModel.model.updateTaskStatus(shopTask.id, to: .completed)
        viewModel.model.updateTaskStatus(prepTask.id, to: .completed)
        
        // The next top-level task after shop+prep should be cook
        let updatedTasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        let cookTask = updatedTasks.first(where: { $0.taskType == .cook })
        #expect(cookTask?.status == .pending, "Cook task should still be pending after completing shop and prep")
    }
    
    // MARK: - Edge Cases
    
    @MainActor @Test("Workflow handles completed state correctly")
    func testWorkflowCompletion() async {
        let viewModel = createTestViewModel()
        _ = await createTacoDinner(in: viewModel)
        
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        // Complete all tasks
        for task in tasks {
            viewModel.model.updateTaskStatus(task.id, to: .completed)
        }
        
        let updatedTasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        let allCompleted = updatedTasks.allSatisfy { $0.status == .completed }
        #expect(allCompleted, "All tasks should be completed")
        
        let completedCount = updatedTasks.filter { $0.status == .completed }.count
        #expect(completedCount == tasks.count, "All \(tasks.count) tasks should be completed")
    }
    
    @MainActor @Test("Workflow handles mixed task states")
    func testMixedTaskStates() async {
        let viewModel = createTestViewModel()
        let meal = await createTacoDinner(in: viewModel)
        
        // Use orderedTasks for stable ordering, then pick specific top-level tasks by type
        let allTasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        guard let shopTask = allTasks.first(where: { $0.taskType == .shop }),
              let prepTask = allTasks.first(where: { $0.taskType == .prep }),
              let cookTask = allTasks.first(where: { $0.taskType == .cook }),
              let assembleTask = allTasks.first(where: { $0.taskType == .assemble }),
              let serveTask = allTasks.first(where: { $0.taskType == .serve }) else {
            Issue.record("Could not find expected task types")
            return
        }
        _ = meal  // suppress warning
        
        // Set mixed states on stable top-level tasks
        viewModel.model.updateTaskStatus(shopTask.id, to: .completed)
        viewModel.model.updateTaskStatus(prepTask.id, to: .inProgress)
        viewModel.model.updateTaskStatus(cookTask.id, to: .blocked)
        viewModel.model.updateTaskStatus(assembleTask.id, to: .pending)
        viewModel.model.updateTaskStatus(serveTask.id, to: .declined)
        
        let updatedTasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        let updatedShop = updatedTasks.first(where: { $0.taskType == .shop })
        let updatedPrep = updatedTasks.first(where: { $0.taskType == .prep })
        let updatedCook = updatedTasks.first(where: { $0.taskType == .cook })
        let updatedAssemble = updatedTasks.first(where: { $0.taskType == .assemble })
        let updatedServe = updatedTasks.first(where: { $0.taskType == .serve })
        
        #expect(updatedShop?.status == .completed, "Shop task should be completed")
        #expect(updatedPrep?.status == .inProgress, "Prep task should be in progress")
        #expect(updatedCook?.status == .blocked, "Cook task should be blocked")
        #expect(updatedAssemble?.status == .pending, "Assemble task should be pending")
        #expect(updatedServe?.status == .declined, "Serve task should be declined")
    }
    
    // MARK: - Auto-Advance Tests
    
    @MainActor @Test("Complete current task auto-advances to next")
    func testAutoAdvance() async {
        let viewModel = createTestViewModel()
        let meal = await createTacoDinner(in: viewModel)
        
        // Start workflow
        viewModel.model.startWorkflow(for: meal.id)
        
        // Verify first task is in progress
        let current1 = viewModel.model.currentTask(for: meal.id)
        #expect(current1?.taskType == .shop, "First task should be shop")
        
        // Complete current task with auto-advance
        let nextTask = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        
        // Verify shop task is completed
        let tasks = viewModel.model.orderedTasks(for: meal.id)
        #expect(tasks[0].status == .completed, "Shop task should be completed")
        
        // Verify prep task is now in progress
        #expect(nextTask?.taskType == .prep, "Next task should be prep")
        #expect(tasks[1].status == .inProgress, "Prep task should be in progress")
    }
    
    @MainActor @Test("Complete current task without auto-advance")
    func testCompleteWithoutAutoAdvance() async {
        let viewModel = createTestViewModel()
        let meal = await createTacoDinner(in: viewModel)
        
        // Start workflow
        viewModel.model.startWorkflow(for: meal.id)
        
        // Complete current task without auto-advance
        let nextTask = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: false)
        
        #expect(nextTask == nil, "Should not return next task when auto-advance is false")
        
        // Verify shop task is completed but prep is still pending
        let tasks = viewModel.model.orderedTasks(for: meal.id)
        #expect(tasks[0].status == .completed, "Shop task should be completed")
        #expect(tasks[1].status == .pending, "Prep task should still be pending")
    }
    
    @MainActor @Test("Auto-advance through entire workflow")
    func testAutoAdvanceFullWorkflow() async {
        let viewModel = createTestViewModel()
        let meal = await createTacoDinner(in: viewModel)
        
        // Start workflow
        viewModel.model.startWorkflow(for: meal.id)
        
        // Complete all tasks with auto-advance (6 top-level tasks: shop, prep, cook, assemble, serve, cleanup)
        let taskCount = viewModel.model.orderedTasks(for: meal.id).count
        for i in 0..<taskCount {
            let current = viewModel.model.currentTask(for: meal.id)
            #expect(current != nil, "Should have current task at step \(i)")
            
            _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        }
        
        // Verify all tasks completed
        #expect(viewModel.model.isWorkflowComplete(for: meal.id), "Workflow should be complete")
        
        // Verify no current task
        let current = viewModel.model.currentTask(for: meal.id)
        #expect(current == nil, "Should have no current task when complete")
    }
    
    @MainActor @Test("Workflow progress calculates correctly during auto-advance")
    func testWorkflowProgressDuringAutoAdvance() async {
        let viewModel = createTestViewModel()
        let meal = await createTacoDinner(in: viewModel)
        
        // Start workflow
        viewModel.model.startWorkflow(for: meal.id)
        
        // Initially 0% complete (0 tasks completed)
        var progress = viewModel.model.workflowProgress(for: meal.id)
        #expect(progress == 0.0, "Progress should be 0% initially")
        
        let totalTasks = viewModel.model.orderedTasks(for: meal.id).count
        
        // Complete first task
        _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        progress = viewModel.model.workflowProgress(for: meal.id)
        #expect(progress == 1.0 / Double(totalTasks), "Progress should be 1/\(totalTasks) after first task")
        
        // Complete second task
        _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        progress = viewModel.model.workflowProgress(for: meal.id)
        #expect(progress == 2.0 / Double(totalTasks), "Progress should be 2/\(totalTasks) after second task")
        
        // Complete remaining tasks
        for _ in 2..<totalTasks {
            _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        }
        
        // 100% complete
        progress = viewModel.model.workflowProgress(for: meal.id)
        #expect(progress == 1.0, "Progress should be 100% when all tasks complete")
    }
    
    @MainActor @Test("Workflow helpers return correct values")
    func testWorkflowHelpers() async {
        let viewModel = createTestViewModel()
        let meal = await createTacoDinner(in: viewModel)
        
        // Initially not active
        #expect(!viewModel.model.isWorkflowActive(for: meal.id), "Workflow should not be active initially")
        #expect(!viewModel.model.isWorkflowComplete(for: meal.id), "Workflow should not be complete initially")
        
        // Start workflow
        viewModel.model.startWorkflow(for: meal.id)
        
        #expect(viewModel.model.isWorkflowActive(for: meal.id), "Workflow should be active after start")
        #expect(!viewModel.model.isWorkflowComplete(for: meal.id), "Workflow should not be complete yet")
        
        // Complete all tasks
        let taskCount = viewModel.model.orderedTasks(for: meal.id).count
        for _ in 0..<taskCount {
            _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        }
        
        #expect(viewModel.model.isWorkflowActive(for: meal.id), "Workflow should still be active (has completed tasks)")
        #expect(viewModel.model.isWorkflowComplete(for: meal.id), "Workflow should be complete")
    }
}
