//
//  MealNodeMenuView.swift
//  GraphEditorWatch
//
//  Menu view for MealNode with workflow start/stop and task overview
//

import SwiftUI
import WatchKit
import GraphEditorShared

@available(watchOS 10.0, *)
struct MealNodeMenuView: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    @Binding var selectedNodeID: NodeID?
    
    @State private var mealNode: MealNode?
    @State private var tasks: [TaskNode] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let meal = mealNode {
                    // Meal Info Section
                    Text("Meal Details").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 4) {
                        HStack {
                            Text("Name:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(meal.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Guests:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(meal.guests)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Dinner Time:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(timeString(meal.dinnerTime))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        if let protein = meal.protein {
                            HStack {
                                Text("Protein:")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(protein.rawValue.capitalized)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
                    
                    // Workflow Control Section
                    Text("Workflow").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 6) {
                        if hasWorkflowStarted {
                            // Show workflow progress
                            workflowProgressView
                            
                            // Quick action for current task
                            if let current = currentTask {
                                actionButton("Complete: \(current.taskType.rawValue.capitalized)", icon: "checkmark.circle.fill", color: .green) {
                                    completeCurrentTask()
                                }
                            } else if isWorkflowComplete {
                                Text("✓ Workflow Complete!")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            
                            // Stop workflow button
                            actionButton("Stop Workflow", icon: "stop.fill", color: .red) {
                                stopWorkflow()
                            }
                        } else {
                            // Start workflow button
                            actionButton("Start Workflow", icon: "play.fill", color: .green) {
                                startWorkflow()
                            }
                        }
                    }
                    
                    // Preferences Section
                    if let preferenceID = preferenceNodeID {
                        Text("Preferences").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
                        
                        actionButton("View Preferences", icon: "list.bullet.rectangle", color: .purple) {
                            selectedNodeID = preferenceID
                        }
                    }
                    
                    // Table Seating Section
                    Text("Table Seating").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let table = viewModel.model.table(for: meal.id) {
                        actionButton("Manage Table Seating", icon: "person.3.fill", color: .orange) {
                            selectedNodeID = table.id
                        }
                    } else {
                        actionButton("Create Table", icon: "plus.rectangle.fill", color: .orange) {
                            createTableForMeal()
                        }
                    }
                    
                    // Tasks Section
                    Text("Tasks (\(completedTaskCount)/\(tasks.count))").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(spacing: 4) {
                        ForEach(tasks, id: \.id) { task in
                            taskRow(task)
                        }
                    }
                } else {
                    Text("Meal not found")
                        .foregroundColor(.red)
                }
            }
            .padding(8)
        }
        .navigationTitle("Meal Menu")
        .onAppear {
            loadMealAndTasks()
        }
    }
    
    // MARK: - Computed Properties
    
    private var preferenceNodeID: NodeID? {
        guard let mealID = selectedNodeID else { return nil }
        return viewModel.model.preference(for: mealID)?.id
    }
    
    private var hasWorkflowStarted: Bool {
        guard let mealID = selectedNodeID else { return false }
        return viewModel.model.isWorkflowActive(for: mealID)
    }
    
    private var isWorkflowComplete: Bool {
        guard let mealID = selectedNodeID else { return false }
        return viewModel.model.isWorkflowComplete(for: mealID)
    }
    
    private var completedTaskCount: Int {
        tasks.filter { $0.status == .completed }.count
    }
    
    private var currentTask: TaskNode? {
        guard let mealID = selectedNodeID else { return nil }
        return viewModel.model.currentTask(for: mealID)
    }
    
    private var nextPendingTask: TaskNode? {
        guard let mealID = selectedNodeID else { return nil }
        return viewModel.model.nextTask(for: mealID)
    }
    
    // MARK: - Views
    
    private var workflowProgressView: some View {
        VStack(spacing: 6) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            // Current task info
            if let current = currentTask {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Current: \(current.taskType.rawValue.capitalized)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Spacer()
                    if let plannedEnd = current.plannedEnd {
                        Text("Due: \(timeString(plannedEnd))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(6)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(4)
            }
        }
    }
    
    private var progressPercentage: CGFloat {
        guard !tasks.isEmpty else { return 0 }
        return CGFloat(completedTaskCount) / CGFloat(tasks.count)
    }
    
    private func taskRow(_ task: TaskNode) -> some View {
        HStack(spacing: 6) {
            // Status icon
            Image(systemName: statusIcon(task.status))
                .font(.caption2)
                .foregroundColor(statusColor(task.status))
                .frame(width: 16)
            
            // Task name
            Text(task.taskType.rawValue.capitalized)
                .font(.caption2)
                .foregroundColor(task.status == .completed ? .secondary : .primary)
            
            Spacer()
            
            // Timing info
            if let plannedStart = task.plannedStart, let plannedEnd = task.plannedEnd {
                Text("\(timeString(plannedStart)) - \(timeString(plannedEnd))")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(4)
        .background(task.status == .inProgress ? Color.yellow.opacity(0.1) : Color.clear)
        .cornerRadius(4)
    }
    
    private func actionButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }
    
    // MARK: - Helper Functions
    
    private func statusIcon(_ status: TaskStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "xmark.circle"
        case .blocked: return "exclamationmark.triangle.fill"
        case .declined: return "xmark.circle.fill"
        }
    }
    
    private func statusColor(_ status: TaskStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .inProgress: return .yellow
        case .completed: return .green
        case .skipped: return .red
        case .blocked: return .orange
        case .declined: return .red.opacity(0.6)
        }
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func loadMealAndTasks() {
        guard let id = selectedNodeID else { return }
        
        // Load meal node
        mealNode = viewModel.model.nodes.first(where: { $0.id == id })?.unwrapped as? MealNode
        
        // Load tasks in order (they're connected as a chain via hierarchy edges)
        loadTasksInOrder(mealID: id)
    }
    
    private func loadTasksInOrder(mealID: NodeID) {
        // Use the new GraphModel workflow helper
        tasks = viewModel.model.orderedTasks(for: mealID)
    }
    
    private func startWorkflow() {
        guard let mealID = selectedNodeID else { return }
        
        Task { @MainActor in
            viewModel.model.startWorkflow(for: mealID)
            loadMealAndTasks()
        }
    }
    
    private func stopWorkflow() {
        guard let mealID = selectedNodeID else { return }
        
        Task { @MainActor in
            viewModel.model.stopWorkflow(for: mealID)
            loadMealAndTasks()
        }
    }
    
    private func completeCurrentTask() {
        guard let mealID = selectedNodeID else { return }
        
        Task { @MainActor in
            // Complete current task and auto-advance to next
            if let nextTask = viewModel.model.completeCurrentTask(for: mealID, autoAdvance: true) {
                // Haptic feedback for successful advance
                WKInterfaceDevice.current().play(.success)
                
                // Optional: Show brief message about next task
                print("✅ Task completed! Starting: \(nextTask.taskType.rawValue)")
            } else {
                // Workflow complete
                WKInterfaceDevice.current().play(.success)
                print("🎉 All tasks completed!")
            }
            
            loadMealAndTasks()
        }
    }
    
    private func createTableForMeal() {
        guard let meal = mealNode else { return }
        
        Task {
            // Create table near meal
            let tablePosition = CGPoint(
                x: meal.position.x + 150,
                y: meal.position.y
            )
            
            let table = await viewModel.model.addTable(
                name: "\(meal.name) Table",
                headSeats: 1,
                sideSeats: min(3, meal.guests / 2),
                at: tablePosition
            )
            
            // Link meal to table
            await viewModel.model.linkMealToTable(mealID: meal.id, tableID: table.id)
            
            // Navigate to table
            await MainActor.run {
                selectedNodeID = table.id
            }
        }
    }
}
