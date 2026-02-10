//
//  TaskNodeMenuView.swift
//  GraphEditorWatch
//
//  Menu view for TaskNode with status-specific actions
//

import SwiftUI
import WatchKit
import GraphEditorShared

@available(watchOS 10.0, *)
struct TaskNodeMenuView: View {
    let viewModel: GraphViewModel
    let onDismiss: () -> Void
    @Binding var selectedNodeID: NodeID?

    @State private var taskNode: TaskNode?

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let task = taskNode {
                    // Task Info Section
                    Text("Task").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 4) {
                        HStack {
                            Text("Type:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(task.taskType.rawValue.capitalized)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Text("Status:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(task.status.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(statusColor(task.status))
                        }

                        if let plannedStart = task.plannedStart, let plannedEnd = task.plannedEnd {
                            HStack {
                                Text("Planned:")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(timeString(plannedStart)) - \(timeString(plannedEnd))")
                                    .font(.caption2)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)

                    // Actions Section
                    Text("Actions").font(.subheadline.bold()).frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 6) {
                        // Status-specific actions
                        switch task.status {
                        case .pending:
                            actionButton("Start", icon: "play.fill", color: .yellow) {
                                updateStatus(to: .inProgress)
                            }
                            actionButton("Block", icon: "exclamationmark.triangle.fill", color: .orange) {
                                updateStatus(to: .blocked)
                            }
                            actionButton("Decline", icon: "xmark.circle.fill", color: .red) {
                                updateStatus(to: .declined)
                            }

                        case .inProgress:
                            actionButton("Complete", icon: "checkmark.circle.fill", color: .green) {
                                updateStatus(to: .completed)
                            }
                            actionButton("Block", icon: "exclamationmark.triangle.fill", color: .orange) {
                                updateStatus(to: .blocked)
                            }

                        case .blocked:
                            actionButton("Unblock (Start)", icon: "play.fill", color: .yellow) {
                                updateStatus(to: .inProgress)
                            }
                            actionButton("Decline", icon: "xmark.circle.fill", color: .red) {
                                updateStatus(to: .declined)
                            }

                        case .completed, .declined:
                            actionButton("Reset", icon: "arrow.counterclockwise", color: .blue) {
                                updateStatus(to: .pending)
                            }

                        case .skipped:
                            actionButton("Reset", icon: "arrow.counterclockwise", color: .blue) {
                                updateStatus(to: .pending)
                            }
                        }
                    }
                } else {
                    Text("Task not found")
                        .foregroundColor(.red)
                }
            }
            .padding(8)
        }
        .navigationTitle("Task Menu")
        .onAppear {
            loadTaskNode()
        }
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

    private func loadTaskNode() {
        guard let id = selectedNodeID else { return }
        taskNode = viewModel.model.nodes.first(where: { $0.id == id })?.unwrapped as? TaskNode
    }

    private func updateStatus(to newStatus: TaskStatus) {
        guard let id = selectedNodeID else { return }

        Task { @MainActor in
            viewModel.model.updateTaskStatus(id, to: newStatus)
            loadTaskNode()  // Refresh display
        }
    }
}
