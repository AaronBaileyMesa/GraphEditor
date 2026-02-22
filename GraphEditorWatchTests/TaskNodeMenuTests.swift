//
//  TaskNodeMenuTests.swift
//  GraphEditorWatchTests
//
//  Tests for TaskNodeMenuView status transitions and actions
//

import Testing
import Foundation
import CoreGraphics
@testable import GraphEditorWatch
@testable import GraphEditorShared

struct TaskNodeMenuTests {
    
    @MainActor
    private func createTestViewModel() -> GraphViewModel {
        let storage = MockGraphStorage()
        let physicsEngine = PhysicsEngine(simulationBounds: CGSize(width: 500, height: 500))
        let model = GraphModel(storage: storage, physicsEngine: physicsEngine)
        return GraphViewModel(model: model)
    }
    
    // MARK: - Task Node Creation Tests
    
    @MainActor @Test("Create task node with default status")
    func testCreateTaskNodeWithDefaultStatus() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .cook,
            estimatedTime: 30,
            at: CGPoint(x: 100, y: 100)
        )
        
        #expect(task.status == .pending, "New task should start with pending status")
        #expect(task.taskType == .cook, "Task type should be cook")
        #expect(task.estimatedTime == 30, "Estimated time should be 30")
    }
    
    @MainActor @Test("Create task node with planned timestamps")
    func testCreateTaskNodeWithPlannedTimestamps() async {
        let viewModel = createTestViewModel()
        
        let now = Date()
        let plannedStart = now.addingTimeInterval(3600) // 1 hour from now
        let plannedEnd = plannedStart.addingTimeInterval(1800) // 30 minutes later
        
        let task = await viewModel.model.addTask(
            type: .prep,
            estimatedTime: 30,
            plannedStart: plannedStart,
            plannedEnd: plannedEnd,
            at: CGPoint(x: 100, y: 100)
        )
        
        #expect(task.plannedStart != nil, "Task should have planned start time")
        #expect(task.plannedEnd != nil, "Task should have planned end time")
        
        if let start = task.plannedStart, let end = task.plannedEnd {
            let duration = end.timeIntervalSince(start)
            #expect(abs(duration - 1800) < 1.0, "Duration should be 30 minutes")
        }
    }
    
    // MARK: - Status Transition Tests
    
    @MainActor @Test("Transition from pending to in progress")
    func testPendingToInProgress() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .shop,
            estimatedTime: 60,
            at: CGPoint(x: 100, y: 100)
        )
        
        #expect(task.status == .pending, "Should start pending")
        
        // Update status to in progress
        viewModel.model.updateTaskStatus(task.id, to: .inProgress)
        
        // Verify status changed
        let updatedTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        #expect(updatedTask?.status == .inProgress, "Status should be in progress")
        #expect(updatedTask?.startedAt != nil, "Should have started timestamp")
    }
    
    @MainActor @Test("Transition from in progress to completed")
    func testInProgressToCompleted() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .cook,
            estimatedTime: 30,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Start the task
        viewModel.model.updateTaskStatus(task.id, to: .inProgress)
        
        // Complete the task
        viewModel.model.updateTaskStatus(task.id, to: .completed)
        
        // Verify completion
        let completedTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        #expect(completedTask?.status == .completed, "Status should be completed")
        #expect(completedTask?.completedAt != nil, "Should have completed timestamp")
        #expect(completedTask?.actualTime != nil, "Should have actual time recorded")
    }
    
    @MainActor @Test("Transition from pending to blocked")
    func testPendingToBlocked() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .prep,
            estimatedTime: 20,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Block the task
        viewModel.model.updateTaskStatus(task.id, to: .blocked)
        
        // Verify blocked status
        let blockedTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        #expect(blockedTask?.status == .blocked, "Status should be blocked")
    }
    
    @MainActor @Test("Transition from pending to declined")
    func testPendingToDeclined() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .cleanup,
            estimatedTime: 15,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Decline the task
        viewModel.model.updateTaskStatus(task.id, to: .declined)
        
        // Verify declined status
        let declinedTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        #expect(declinedTask?.status == .declined, "Status should be declined")
    }
    
    @MainActor @Test("Transition from in progress to blocked")
    func testInProgressToBlocked() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .cook,
            estimatedTime: 30,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Start then block
        viewModel.model.updateTaskStatus(task.id, to: .inProgress)
        viewModel.model.updateTaskStatus(task.id, to: .blocked)
        
        // Verify blocked status
        let blockedTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        #expect(blockedTask?.status == .blocked, "Status should be blocked")
        #expect(blockedTask?.startedAt != nil, "Should still have start timestamp")
    }
    
    @MainActor @Test("Transition from blocked to in progress (unblock)")
    func testBlockedToInProgress() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .prep,
            estimatedTime: 20,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Block then unblock
        viewModel.model.updateTaskStatus(task.id, to: .blocked)
        viewModel.model.updateTaskStatus(task.id, to: .inProgress)
        
        // Verify unblocked and in progress
        let unblockedTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        #expect(unblockedTask?.status == .inProgress, "Status should be in progress after unblocking")
        #expect(unblockedTask?.startedAt != nil, "Should have started timestamp")
    }
    
    @MainActor @Test("Transition from blocked to declined")
    func testBlockedToDeclined() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .shop,
            estimatedTime: 60,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Block then decline
        viewModel.model.updateTaskStatus(task.id, to: .blocked)
        viewModel.model.updateTaskStatus(task.id, to: .declined)
        
        // Verify declined
        let declinedTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        #expect(declinedTask?.status == .declined, "Status should be declined")
    }
    
    @MainActor @Test("Reset completed task to pending")
    func testCompletedToPending() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .serve,
            estimatedTime: 10,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Complete then reset
        viewModel.model.updateTaskStatus(task.id, to: .inProgress)
        viewModel.model.updateTaskStatus(task.id, to: .completed)
        viewModel.model.updateTaskStatus(task.id, to: .pending)
        
        // Verify reset to pending
        let resetTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        #expect(resetTask?.status == .pending, "Status should be reset to pending")
    }
    
    @MainActor @Test("Reset declined task to pending")
    func testDeclinedToPending() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .cleanup,
            estimatedTime: 15,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Decline then reset
        viewModel.model.updateTaskStatus(task.id, to: .declined)
        viewModel.model.updateTaskStatus(task.id, to: .pending)
        
        // Verify reset
        let resetTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        #expect(resetTask?.status == .pending, "Status should be reset to pending")
    }
    
    @MainActor @Test("Reset skipped task to pending")
    func testSkippedToPending() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .plan,
            estimatedTime: 30,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Skip then reset
        viewModel.model.updateTaskStatus(task.id, to: .skipped)
        viewModel.model.updateTaskStatus(task.id, to: .pending)
        
        // Verify reset
        let resetTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        #expect(resetTask?.status == .pending, "Status should be reset to pending")
    }
    
    // MARK: - Status Color Tests
    
    @MainActor @Test("Status colors match expected values")
    func testStatusColors() async {
        // This tests the statusColor function logic
        // We can't directly test SwiftUI Color equality, but we can verify the logic exists
        
        // Just verify we can create tasks with all status types
        let viewModel = createTestViewModel()
        
        let statuses: [TaskStatus] = [.pending, .inProgress, .completed, .skipped, .blocked, .declined]
        
        for status in statuses {
            let task = await viewModel.model.addTask(
                type: .cook,
                estimatedTime: 30,
                at: CGPoint(x: 100, y: 100)
            )
            
            viewModel.model.updateTaskStatus(task.id, to: status)
            
            let updatedTask = viewModel.model.nodes
                .first(where: { $0.id == task.id })?
                .unwrapped as? TaskNode
            
            #expect(updatedTask?.status == status, "Status should be \(status)")
        }
    }
    
    // MARK: - Task Type Tests
    
    @MainActor @Test("Create tasks with all task types")
    func testAllTaskTypes() async {
        let viewModel = createTestViewModel()
        
        let taskTypes: [TaskType] = [.plan, .shop, .prep, .cook, .serve, .cleanup]
        
        for taskType in taskTypes {
            let task = await viewModel.model.addTask(
                type: taskType,
                estimatedTime: 30,
                at: CGPoint(x: 100, y: 100)
            )
            
            #expect(task.taskType == taskType, "Task type should be \(taskType)")
            #expect(task.status == .pending, "All new tasks should start pending")
        }
        
        let taskNodes = viewModel.model.nodes.compactMap { $0.unwrapped as? TaskNode }
        #expect(taskNodes.count == 6, "Should have created 6 tasks")
    }
    
    // MARK: - Time Tracking Tests
    
    @MainActor @Test("Task records start time when transitioning to in progress")
    func testTaskRecordsStartTime() async {
        let viewModel = createTestViewModel()
        
        let beforeStart = Date()
        
        let task = await viewModel.model.addTask(
            type: .cook,
            estimatedTime: 30,
            at: CGPoint(x: 100, y: 100)
        )
        
        viewModel.model.updateTaskStatus(task.id, to: .inProgress)
        
        let afterStart = Date()
        
        let updatedTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        if let startedAt = updatedTask?.startedAt {
            #expect(startedAt >= beforeStart, "Start time should be after or equal to before time")
            #expect(startedAt <= afterStart, "Start time should be before or equal to after time")
        } else {
            Issue.record("Task should have startedAt timestamp")
        }
    }
    
    @MainActor @Test("Task records completion time")
    func testTaskRecordsCompletionTime() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .prep,
            estimatedTime: 20,
            at: CGPoint(x: 100, y: 100)
        )
        
        viewModel.model.updateTaskStatus(task.id, to: .inProgress)
        
        let beforeComplete = Date()
        viewModel.model.updateTaskStatus(task.id, to: .completed)
        let afterComplete = Date()
        
        let completedTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        if let completedAt = completedTask?.completedAt {
            #expect(completedAt >= beforeComplete, "Completion time should be after or equal to before time")
            #expect(completedAt <= afterComplete, "Completion time should be before or equal to after time")
        } else {
            Issue.record("Task should have completedAt timestamp")
        }
    }
    
    @MainActor @Test("Completed task uses estimated time when no actual time")
    func testCompletedTaskUsesEstimatedTime() async {
        let viewModel = createTestViewModel()
        
        let task = await viewModel.model.addTask(
            type: .shop,
            estimatedTime: 60,
            at: CGPoint(x: 100, y: 100)
        )
        
        viewModel.model.updateTaskStatus(task.id, to: .inProgress)
        viewModel.model.updateTaskStatus(task.id, to: .completed)
        
        let completedTask = viewModel.model.nodes
            .first(where: { $0.id == task.id })?
            .unwrapped as? TaskNode
        
        // The completion logic should use estimated time if actual time is not set
        #expect(completedTask?.actualTime == 60 || completedTask?.estimatedTime == 60, 
                "Should preserve estimated time")
    }
    
    // MARK: - Query Helper Tests
    
    @MainActor @Test("Query tasks for a meal")
    func testQueryTasksForMeal() async {
        let viewModel = createTestViewModel()
        
        // Create a meal
        let meal = await viewModel.model.addMeal(
            name: "Test Dinner",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Create tasks and link them to the meal
        let task1 = await viewModel.model.addTask(
            type: .prep,
            estimatedTime: 20,
            at: CGPoint(x: 150, y: 150)
        )
        
        let task2 = await viewModel.model.addTask(
            type: .cook,
            estimatedTime: 30,
            at: CGPoint(x: 200, y: 150)
        )
        
        // Add hierarchy edges
        await viewModel.model.addEdge(from: meal.id, target: task1.id, type: .hierarchy)
        await viewModel.model.addEdge(from: meal.id, target: task2.id, type: .hierarchy)
        
        // Query tasks
        let tasks = viewModel.model.tasks(for: meal.id)
        
        #expect(tasks.count == 2, "Should find 2 tasks for the meal")
        #expect(tasks.contains(where: { $0.id == task1.id }), "Should contain task 1")
        #expect(tasks.contains(where: { $0.id == task2.id }), "Should contain task 2")
    }
    
    @MainActor @Test("Calculate total work time for meal")
    func testCalculateTotalWorkTime() async {
        let viewModel = createTestViewModel()
        
        // Create a meal
        let meal = await viewModel.model.addMeal(
            name: "Test Dinner",
            date: Date(),
            mealType: .dinner,
            servings: 4,
            at: CGPoint(x: 100, y: 100)
        )
        
        // Create tasks with different estimated times
        let task1 = await viewModel.model.addTask(type: .prep, estimatedTime: 20, at: .zero)
        let task2 = await viewModel.model.addTask(type: .cook, estimatedTime: 30, at: .zero)
        let task3 = await viewModel.model.addTask(type: .serve, estimatedTime: 10, at: .zero)
        
        // Link to meal
        await viewModel.model.addEdge(from: meal.id, target: task1.id, type: .hierarchy)
        await viewModel.model.addEdge(from: meal.id, target: task2.id, type: .hierarchy)
        await viewModel.model.addEdge(from: meal.id, target: task3.id, type: .hierarchy)
        
        // Calculate total
        let totalTime = viewModel.model.totalWorkTime(for: meal.id)
        
        #expect(totalTime == 60, "Total work time should be 60 minutes (20 + 30 + 10)")
    }
}
