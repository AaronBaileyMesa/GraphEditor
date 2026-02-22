//
//  PrepTimelineDetailView.swift
//  GraphEditorWatch
//
//  Crown-scrollable prep timeline showing tasks with timing.
//

import SwiftUI
import GraphEditorShared

struct PrepTimelineDetailView: View {
    let planID: NodeID
    @ObservedObject var viewModel: GraphViewModel

    var tasks: [TaskNode] { viewModel.model.orderedTasks(for: planID) }
    var isWorkflowActive: Bool { viewModel.model.isWorkflowActive(for: planID) }

    var body: some View {
        Group {
            if tasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No tasks found.\nCreate a plan using the Taco Night Wizard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            TimelineTaskRow(
                                task: task,
                                isLast: index == tasks.count - 1,
                                onStart: {
                                    viewModel.model.updateTaskStatus(task.id, to: .inProgress)
                                },
                                onComplete: {
                                    _ = viewModel.model.completeCurrentTask(for: planID, autoAdvance: true)
                                }
                            )
                        }
                    }
                    .padding()
                }
                .refreshable {
                    // Refreshes task list from model
                }
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isWorkflowActive {
                    Button("Stop") { viewModel.model.stopWorkflow(for: planID) }
                        .foregroundStyle(.red)
                } else {
                    Button("Start") { viewModel.model.startWorkflow(for: planID) }
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

// MARK: - Timeline Task Row

struct TimelineTaskRow: View {
    let task: TaskNode
    let isLast: Bool
    let onStart: () -> Void
    let onComplete: () -> Void

    var statusColor: Color {
        switch task.status {
        case .inProgress: return .yellow
        case .completed: return .green
        case .skipped, .declined: return .red
        case .blocked: return .orange
        default: return .secondary
        }
    }

    var statusIcon: String {
        switch task.status {
        case .inProgress: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "xmark.circle.fill"
        case .blocked: return "exclamationmark.triangle.fill"
        default: return "circle"
        }
    }

    var timeLabel: String {
        if let start = task.plannedStart {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: start)
        }
        return "\(task.estimatedTime)m"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Timeline indicator
            VStack(spacing: 0) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.title3)

                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 24)

            // Task details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(task.taskType.displayName)
                        .font(.subheadline)
                        .fontWeight(task.status == .inProgress ? .bold : .regular)
                    Spacer()
                    Text(timeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if task.status == .inProgress {
                    HStack(spacing: 6) {
                        Button("Complete", action: onComplete)
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .font(.caption)
                    }
                } else if task.status == .pending {
                    Button("Start", action: onStart)
                        .buttonStyle(.bordered)
                        .font(.caption)
                }
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }
}

// MARK: - TaskType Display Name

extension TaskType {
    var displayName: String {
        switch self {
        case .plan: return "Plan Meal"
        case .shop: return "Shop"
        case .prep: return "Prep"
        case .cook: return "Cook"
        case .assemble: return "Assemble"
        case .serve: return "Serve"
        case .cleanup: return "Clean Up"
        case .prepMeat: return "Prep Meat"
        case .prepVegetables: return "Chop Vegetables"
        case .prepSauces: return "Prepare Sauces"
        case .prepToppings: return "Prepare Toppings"
        case .prepShells: return "Warm Shells"
        case .assemblySetup: return "Setup Station"
        case .assemblyBuild: return "Build Tacos"
        case .assemblyPlate: return "Plate & Garnish"
        }
    }
}
