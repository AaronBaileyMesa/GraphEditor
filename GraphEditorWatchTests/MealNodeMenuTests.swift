//
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
        return GraphViewModel(model: model)
    }
    
    @MainActor
    private func createTacoDinner(in viewModel: GraphViewModel) async -> MealNode {
        let calendar = Calendar.current
        let dinnerTime = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? Date()
        
        return await TacoTemplateBuilder.buildGraph(
            in: viewModel.model,
            guests: 4,
            dinnerTime: dinnerTime,
            protein: .beef,
            at: CGPoint(x: 20, y: 125)
        )
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
        
        // Get tasks via hierarchy edges (same logic as MealNodeMenuView)
        var orderedTasks: [TaskNode] = []
        var visited: Set<NodeID> = [meal.id]
        var currentID: NodeID? = meal.id
        
        while let nodeID = currentID {
            if let edge = viewModel.model.edges.first(where: {
                $0.from == nodeID && $0.type == .hierarchy && !visited.contains($0.target)
            }) {
                visited.insert(edge.target)
                if let taskNode = viewModel.model.nodes.first(where: { $0.id == edge.target })?.unwrapped as? TaskNode {
                    orderedTasks.append(taskNode)
                    currentID = edge.target
                } else {
                    currentID = nil
                }
            } else {
                currentID = nil
            }
        }
        
        // Verify tasks are in correct order
        #expect(orderedTasks.count == 5, "Should have 5 tasks")
        #expect(orderedTasks[0].taskType == .plan, "First task should be plan")
        #expect(orderedTasks[1].taskType == .shop, "Second task should be shop")
        #expect(orderedTasks[2].taskType == .prep, "Third task should be prep")
        #expect(orderedTasks[3].taskType == .cook, "Fourth task should be cook")
        #expect(orderedTasks[4].taskType == .serve, "Fifth task should be serve")
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
        guard let firstTask = tasks.first(where: { $0.taskType == .plan }) else {
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
        
        // Complete 3 out of 5 tasks
        for i in 0..<3 {
            viewModel.model.updateTaskStatus(tasks[i].id, to: .completed)
        }
        
        let completedCount = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
            .filter { $0.status == .completed }.count
        
        #expect(completedCount == 3, "Should have 3 completed tasks")
        
        let progress = Double(completedCount) / Double(tasks.count)
        #expect(progress == 0.6, "Progress should be 60% (3/5)")
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
        _ = await createTacoDinner(in: viewModel)
        
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        // Complete first two tasks
        viewModel.model.updateTaskStatus(tasks[0].id, to: .completed)
        viewModel.model.updateTaskStatus(tasks[1].id, to: .completed)
        
        // Find next pending task
        let updatedTasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        let nextTask = updatedTasks.first { $0.status == .pending }
        
        #expect(nextTask?.taskType == .prep, "Next pending task should be prep")
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
        #expect(completedCount == 5, "Should have 5 completed tasks")
    }
    
    @MainActor @Test("Workflow handles mixed task states")
    func testMixedTaskStates() async {
        let viewModel = createTestViewModel()
        _ = await createTacoDinner(in: viewModel)
        
        let tasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        // Set mixed states
        viewModel.model.updateTaskStatus(tasks[0].id, to: .completed)
        viewModel.model.updateTaskStatus(tasks[1].id, to: .inProgress)
        viewModel.model.updateTaskStatus(tasks[2].id, to: .blocked)
        viewModel.model.updateTaskStatus(tasks[3].id, to: .pending)
        viewModel.model.updateTaskStatus(tasks[4].id, to: .declined)
        
        let updatedTasks = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        
        #expect(updatedTasks[0].status == .completed, "First task should be completed")
        #expect(updatedTasks[1].status == .inProgress, "Second task should be in progress")
        #expect(updatedTasks[2].status == .blocked, "Third task should be blocked")
        #expect(updatedTasks[3].status == .pending, "Fourth task should be pending")
        #expect(updatedTasks[4].status == .declined, "Fifth task should be declined")
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
        #expect(current1?.taskType == .plan, "First task should be plan")
        
        // Complete current task with auto-advance
        let nextTask = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        
        // Verify plan task is completed
        let tasks = viewModel.model.orderedTasks(for: meal.id)
        #expect(tasks[0].status == .completed, "Plan task should be completed")
        
        // Verify shop task is now in progress
        #expect(nextTask?.taskType == .shop, "Next task should be shop")
        #expect(tasks[1].status == .inProgress, "Shop task should be in progress")
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
        
        // Verify plan task is completed but shop is still pending
        let tasks = viewModel.model.orderedTasks(for: meal.id)
        #expect(tasks[0].status == .completed, "Plan task should be completed")
        #expect(tasks[1].status == .pending, "Shop task should still be pending")
    }
    
    @MainActor @Test("Auto-advance through entire workflow")
    func testAutoAdvanceFullWorkflow() async {
        let viewModel = createTestViewModel()
        let meal = await createTacoDinner(in: viewModel)
        
        // Start workflow
        viewModel.model.startWorkflow(for: meal.id)
        
        // Complete all tasks with auto-advance
        for i in 0..<5 {
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
        
        // Complete first task - 20% (1/5)
        _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        progress = viewModel.model.workflowProgress(for: meal.id)
        #expect(progress == 0.2, "Progress should be 20% after first task")
        
        // Complete second task - 40% (2/5)
        _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        progress = viewModel.model.workflowProgress(for: meal.id)
        #expect(progress == 0.4, "Progress should be 40% after second task")
        
        // Complete remaining tasks
        _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        
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
        for _ in 0..<5 {
            _ = viewModel.model.completeCurrentTask(for: meal.id, autoAdvance: true)
        }
        
        #expect(viewModel.model.isWorkflowActive(for: meal.id), "Workflow should still be active (has completed tasks)")
        #expect(viewModel.model.isWorkflowComplete(for: meal.id), "Workflow should be complete")
    }
}
